import RAW
import QuickLMDB
import Logging
import struct Foundation.URL
import ServiceLifecycle
import bedrock

#if os(Linux)
import Glibc
#elseif os(macOS)
import Darwin
#endif

@RAW_staticbuff(bytes:4)
@RAW_staticbuff_fixedwidthinteger_type<pid_t>(bigEndian:true)
@MDB_comparable()
fileprivate struct EncodedPID:Equatable, Sendable {
	fileprivate static func currentPID() -> EncodedPID {
		return EncodedPID(RAW_native:getpid())
	}
}

@RAW_staticbuff(bytes:8)
@RAW_staticbuff_binaryfloatingpoint_type<Double>()
@MDB_comparable()
fileprivate struct EncodedDuration:Sendable {}

@RAW_convertible_string_type<RAW_byte>(UTF8.self)
@MDB_comparable()
fileprivate struct EncodedString:ExpressibleByStringLiteral, CustomDebugStringConvertible, Sendable {
	fileprivate var debugDescription:String {
		return String(self)
	}
}

@RAW_staticbuff(bytes:8)
@RAW_staticbuff_binaryfloatingpoint_type<Double>()
@MDB_comparable()
fileprivate struct EncodedDate:CustomDebugStringConvertible, Sendable {
    fileprivate var debugDescription: String {
		return "\(Date(self).timeIntervalSinceUnixDate())"
	}
	fileprivate init(_ date:Date) {
		self = EncodedDate(RAW_native:date.timeIntervalSinceUnixDate())
	}
	fileprivate func timeIntervalSince(_ date:Date) -> Double {
		return Date(self).timeIntervalSince(date)
	}
	fileprivate func addingTimeInterval(_ interval:Double) -> EncodedDate {
		return EncodedDate(Date(self).addingTimeInterval(interval))
	}
	fileprivate func timeIntervalSinceUnixDate() -> Double {
		return Date(self).timeIntervalSinceUnixDate()
	}
}

fileprivate extension Date {
	init(_ encoded:EncodedDate) {
		self.init(unixInterval:encoded.RAW_native())
	}
}

extension Foundation.URL {
	fileprivate func getFileSize() -> off_t {
		var statObj = stat()
		guard stat(self.path, &statObj) == 0 else {
			return 0
		}
		return statObj.st_size
	}
}

public struct Scheduler:Sendable {
	/// thrown when a recurring task that was scheduled as the current PID unexpectedly gets assigned to a different PID.
	/// - note: this should never occur but this error still exists in place of throwing a fatalError.
	public struct UnexpectedTaskRescheduleError:Swift.Error {}

	fileprivate enum Databases:String {
		case scheduleTasks = "schedule_task_db"
		case scheduleIntervals = "schedule_interval_db"
		case scheduleLastFireDate = "schedule_last_fire_date_db"
	}

	private let log:Logger?

	public let env:Environment

	fileprivate let schedule_pid:Database.Strict<EncodedString, EncodedPID>
	fileprivate let schedule_timeInterval:Database.Strict<EncodedString, EncodedDuration>
	fileprivate let schedule_lastFireDate:Database.Strict<EncodedString, EncodedDate>

	public init(base:URL, log:Logger?) throws {
		let dbFileName = "task-scheduler.mdb"
		let targetURL = base.appendingPathComponent(dbFileName, isDirectory:false)
		let envSize = size_t(targetURL.getFileSize()) + size_t(1.28e6)
		let makeEnv = try Environment(path:targetURL.path, flags:[.noSubDir, .noReadAhead], mapSize:envSize, maxReaders:32, maxDBs:3, mode:[.ownerReadWriteExecute, .groupRead, .groupExecute])
		let someTrans = try Transaction(env:makeEnv, readOnly:false)
		self.schedule_pid = try Database.Strict<EncodedString, EncodedPID>(env:makeEnv, name:Databases.scheduleTasks.rawValue, flags:[.create], tx:someTrans)
		self.schedule_timeInterval = try Database.Strict<EncodedString, EncodedDuration>(env:makeEnv, name:Databases.scheduleIntervals.rawValue, flags:[.create], tx:someTrans)
		self.schedule_lastFireDate = try Database.Strict<EncodedString, EncodedDate>(env:makeEnv, name:Databases.scheduleLastFireDate.rawValue, flags:[.create], tx:someTrans)
		try someTrans.commit()
		self.env = makeEnv
		self.log = log
		log?.notice("instance init", metadata:["path":"'\(targetURL.path)'"])
	}

	public func runSchedule(name unencodedName:String, interval:Double, _ task:@Sendable @escaping () async throws -> Void) async throws {
		let name = EncodedString(unencodedName)

		// setup the task
		let encodedName = name
		let encodedInterval = EncodedDuration(RAW_native:interval)
		let myPID = EncodedPID.currentPID()

		var mutateLogger = log
		mutateLogger?[metadataKey:"name"] = "\(name)"
		mutateLogger?[metadataKey:"interval"] = "\(interval)s"
		mutateLogger?[metadataKey:"pid"] = "\(myPID.RAW_native())"
		mutateLogger?.notice("task loop launched")
		defer {
			mutateLogger?.notice("task loop ended")
		}

		// open the initial write transaction to document ourselves as the runner of the task. also capture the next target date
		var nextTargetDate:Date
		do {
			let newTransaction = try Transaction(env:env, readOnly:false)

			mutateLogger?.trace("task successfully opened introductory transaction")
			do {
				try schedule_pid.setEntry(key:encodedName, value:myPID, flags:[.noOverwrite], tx:newTransaction)
			} catch LMDBError.keyExists {
				let existingPID = try schedule_pid.loadEntry(key:encodedName, tx:newTransaction).RAW_native()
				guard kill(existingPID, 0) != 0 else {
					mutateLogger?.warning("task is already running on PID '\(existingPID)'")
					throw LMDBError.keyExists
				}
				try schedule_pid.setEntry(key:encodedName, value:myPID, flags:[], tx:newTransaction)
			}
			mutateLogger?.debug("PID successfully documented as the runner of the task")
			try schedule_timeInterval.setEntry(key:encodedName, value:encodedInterval, flags:[], tx:newTransaction)
			do {
				let lastFireDate = try schedule_lastFireDate.loadEntry(key:encodedName, tx:newTransaction)
				nextTargetDate = Date(lastFireDate).addingTimeInterval(interval)
				mutateLogger?.trace("task was last fired at \(lastFireDate.timeIntervalSinceUnixDate()) (unix time), next target date is \(nextTargetDate.timeIntervalSinceUnixDate()) (unix time)")
			} catch LMDBError.notFound {
				mutateLogger?.trace("task has no last fire date, setting to fire the task now")
				nextTargetDate = Date()
			}
			
			try newTransaction.commit()
		} catch let error {
			mutateLogger?.error("task failed to initialize due to thrown error.", metadata:["error":"\(error)"])
			throw error
		}

		// ensure that the task is removed from the database when it is done running
		defer {
			do {
				let someTrans = try Transaction(env:env, readOnly:false)
				mutateLogger?.debug("task is removing itself from the database")
				try schedule_pid.deleteEntry(key:encodedName, tx:someTrans)
				try schedule_timeInterval.deleteEntry(key:encodedName, tx:someTrans)
				try someTrans.commit()
				mutateLogger?.trace("successfully removed task from the database")
			} catch let error {
				#if DEBUG
				mutateLogger?.critical("task failed to remove itself from the database due to thrown error", metadata:["error":"\(error)"])
				fatalError("unable to remove task from database: \(error)")
				#else
				mutateLogger?.error("task failed to remove itself from the database due to thrown error", metadata:["error":"\(error)"])
				#endif
			}
		}

		// this should transparently throw any errors that are thrown within the users task, as well as any unexpected errors that may be thrown by LMDB.
		// cancellation errors that occurr outside of the users code should NOT cascade outside of this group.
		try await withThrowingTaskGroup(of:Void.self) { tg in
			// primary task loop runs here. 
			tg.addTask { [nextTargetDate, mutateLogger = mutateLogger, en = encodedName, myPID] in
				var nextTargetDate = nextTargetDate

				mainLoop: while true {

					// determine how much time should pass before running the task
					let delayTime = nextTargetDate.timeIntervalSince(Date())
					if delayTime > 0 {
						// wait for the next target date
						mutateLogger?.debug("sleeping task until fire time")
						do {
							try await Task.sleep(nanoseconds:UInt64(delayTime * 1e9))
						} catch is CancellationError {
							break mainLoop
						}
					} else if delayTime < 0 {
						mutateLogger?.debug("task will fire immediately")
						// fire now
						nextTargetDate = Date()
					}

					// run the task
					mutateLogger?.debug("running task.")
					
					// unexpected errors here should cause the task to cancel
					do {
						try await task()
					} catch let error {
						mutateLogger?.error("user task block failed with thrown error", metadata:["error":"\(error)"])
						throw error
					}

					// write the new timing data to the database
					let someTrans = try Transaction(env:env, readOnly:false)
					mutateLogger?.debug("updating task timing data.", metadata:["next_target_date":"\(nextTargetDate)"])
					// write the new fire date
					try schedule_lastFireDate.setEntry(key:en, value:EncodedDate(nextTargetDate), flags:[], tx:someTrans)

					// validate that we are still the owner of the schedule name and that we should continue firing it
					let shouldBreak:Bool
					do {
						if try schedule_pid.loadEntry(key:en, tx:someTrans) != myPID {
							// if the pid has changed, then the task has been rescheduled, so break out of the main loop
							mutateLogger?.warning("task \(name) has been rescheduled")
							shouldBreak = true
						} else {
							let nowDate = Date()
							while nextTargetDate <= nowDate {
								nextTargetDate = nextTargetDate.addingTimeInterval(interval)
								mutateLogger?.trace("next target date \(nextTargetDate) is in the past, incrementing by \(interval) seconds")
							}
							// continue the main loop 
							mutateLogger?.debug("task \(name) will fire next at \(nextTargetDate), which is ahead of \(nowDate)")
							shouldBreak = false
						}
					} catch LMDBError.notFound {
						mutateLogger?.warning("task \(name) is no longer scheduled with this pid")
						shouldBreak = true
					}
					try someTrans.commit()
					
					// break the loop if the transaction deems we should, or if the task is under cancellation conditions
					guard shouldBreak == false && Task.isCancelled == false else {
						break mainLoop
					}
				}
			}

			tg.addTask {
				try await gracefulShutdown()
			}
			_ = try await tg.next()
			tg.cancelAll()
		}
	}
}