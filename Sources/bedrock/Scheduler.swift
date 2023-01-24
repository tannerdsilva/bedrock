import QuickLMDB
import Logging
import Foundation

// This extension allows Swift-native Task structures to be passed directly into LMDB
extension Task:MDB_convertible {
	public init?(_ value: MDB_val) {
		guard MemoryLayout<Self>.stride == value.mv_size else {
			return nil
		}
		self = value.mv_data.bindMemory(to:Self.self, capacity:1).pointee
	}
	
	public func asMDB_val<R>(_ valFunc: (inout MDB_val) throws -> R) rethrows -> R {
		return try withUnsafePointer(to:self, { unsafePointer in
			var newVal = MDB_val(mv_size:MemoryLayout<Self>.stride, mv_data:UnsafeMutableRawPointer(mutating:unsafePointer))
			return try valFunc(&newVal)
		})
	}
}

public class Scheduler {
	public static var logger = makeDefaultLogger(label:"lmdb-scheduler")
	enum Databases:String {
		case scheduleTasks = "schedule_task_db"		// [String:Task]
		case scheduleIntervals = "schedule_interval_db"	// [String:TimeInterval]
		case scheduleLastFireDate = "schedule_lastfire_db"	// [String:Date]
	}
	
	let env:Environment
	
	let schedule_task:Database
	let schedule_timeInterval:Database
	let schedule_lastFire:Database

	init(env:Environment, tx someTrans:Transaction) throws {
		self.env = env
		self.schedule_task = try env.openDatabase(named:Databases.scheduleTasks.rawValue, flags:[.create], tx:someTrans)
		self.schedule_timeInterval = try env.openDatabase(named:Databases.scheduleIntervals.rawValue, flags:[.create], tx:someTrans)
		self.schedule_lastFire = try env.openDatabase(named:Databases.scheduleLastFireDate.rawValue, flags:[.create], tx:someTrans)
		try self.schedule_task.deleteAllEntries(tx:someTrans)
	}
	
	// MARK: Scheduling
	// launching scheduled tasks
	func launchSchedule(name:String, interval:TimeInterval, _ task:@escaping @Sendable () async -> Void) throws {
		try env.transact(readOnly:false) { installTaskTrans in
			let myPID = getpid()
			guard try self.schedule_task.containsEntry(key:name, tx:installTaskTrans) == false else {
				throw LMDBError.keyExists
			}
			
            // assign the interval for this schedule
            try self.schedule_timeInterval.setEntry(value:interval, forKey:name, tx:installTaskTrans)
            
            // determine the next fire date for the schedule
            let nextFire:Date
            do {
                let lastDate = try self.schedule_lastFire.getEntry(type:Date.self, forKey:name, tx:installTaskTrans)!
                nextFire = lastDate.addingTimeInterval(interval)
            } catch LMDBError.notFound {
                nextFire = Date()
            }

			let newTask = Task<(), Swift.Error>.detached { [mdbEnv = env, intervalDB = self.schedule_timeInterval, lastFire = self.schedule_lastFire, referenceDate = nextFire, initInterval = interval, schedName = name] in
                var nextTarget = referenceDate
                var runningInterval = initInterval
                while Task.isCancelled == false {
                    let delayTime = nextTarget.timeIntervalSinceNow
                    if (delayTime > 0) {
                        try await Task.sleep(nanoseconds:1000000000 * UInt64(ceil(delayTime)))
                    } else if (abs(delayTime) > runningInterval) {
                        nextTarget = Date()
                    }
                    Self.logger.trace("running task", metadata:["name":"\(name)"])
                    await task()
                    (nextTarget, runningInterval) = try mdbEnv.transact(readOnly:false) { someTrans -> (Date, TimeInterval) in
                        try lastFire.setEntry(value:nextTarget, forKey:schedName, tx:someTrans)
                        let checkInterval = try intervalDB.getEntry(type:TimeInterval.self, forKey:schedName, tx:someTrans)!
                        return (nextTarget.addingTimeInterval(checkInterval), checkInterval)
                    }
                    Self.logger.trace("task complete", metadata:["name":"\(name)", "next_fire":"\(nextTarget)"])
                }
            }
            
            try self.schedule_task.setEntry(value:newTask, forKey:name, tx:installTaskTrans)
		}
		try env.sync()
	}
	
	// canceling scheduled task
	func cancelSchedule(_ name:String) throws {
		try env.transact(readOnly:false) { someTrans in
			let loadTask = try self.schedule_task.getEntry(type:Task<(), Swift.Error>.self, forKey:name, tx:someTrans)!
			loadTask.cancel()
			try self.schedule_task.deleteEntry(key:name, tx:someTrans)
		}
	}
	
	deinit {
		try! self.env.transact(readOnly:false) { someTrans in
			try self.schedule_task.deleteAllEntries(tx:someTrans)
		}
		Self.logger.trace("instance deinitialized")
	}
}
