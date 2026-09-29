/*
LICENSE MIT
copyright (c) tanner silva 2026. all rights reserved.

bedrock

*/

#if os(Linux)
import Glibc
import __cbedrock_pathwatch
import bedrock
import bedrock_fifo
import bedrock_future
import bedrock_pthread

/// the linux engine: one inotify instance, waited on with `poll` alongside the wakeup channel.
/// - NOTE: this file is not compiled on macOS, and no other platform's compiler ever type checks it. the checklist for closing this half of the target out on a linux host is:
/// 	1. `swift build` and then `swift test`. every error this file produces has to be fixed on the host; none of them can be reproduced anywhere else.
/// 	2. confirm that the assertions in `InotifyRecordParserTests` that compare ``InotifyABI`` against the values that the `__cbedrock_pathwatch` shim re-exports from `<sys/inotify.h>` pass. those assertions are compiled only on linux.
/// 	3. confirm that `PathWatcherTests` reports entry names and `closedAfterWrite` events, which only happen on linux.
/// 	4. if `struct pollfd`, `POLLIN`, or `poll` turn out not to be visible from the `Glibc` module, replace the wait with `epoll_create1`, `epoll_ctl`, and `epoll_wait` over `primitive` and `wakeup.reading`, both registered with `EPOLLIN|EPOLLET`. those calls are known to import cleanly from the `Glibc` module.
/// 	5. confirm with `ls /proc/self/fd` that a watcher holds three file descriptors no matter how many paths it watches.
internal final class LinuxPathWatchEngine:PathWatchEngine, @unchecked Sendable {

	internal typealias ArgumentType = PathWatchSetup
	internal typealias ReturnType = Void
	internal typealias ThrowType = Never

	/// the inotify file descriptor that this engine polls.
	internal let primitive:Int32

	/// the channel that interrupts the wait.
	private let wakeup:WakeupPipe

	/// the stream of operations to perform.
	private let requests:FIFO<PathWatchRequest, Never>

	/// the counter of armed registrations.
	private let counter:ActiveWatchCounter

	/// the armed registrations, keyed by the watch descriptor that the kernel assigned.
	private var registrations:[Int32:Registration] = [:]

	/// the watch descriptor that belongs to each registration identifier.
	private var identifiers:[UInt64:Int32] = [:]

	/// the next registration identifier to hand out.
	private var nextIdentifier:UInt64 = 1

	/// the capacity of the record buffer. a record is at most `sizeof(struct inotify_event)` plus a name of `NAME_MAX` bytes, padded to a four byte boundary, which is far smaller than this. the kernel reports `EINVAL` rather than splitting a record that does not fit.
	private static let recordBufferCapacity = 4096

	/// one armed registration.
	private struct Registration {
		internal let identifier:UInt64
		internal let path:Path
		internal let kinds:FileEventKind
		internal let channel:FIFO<FileEvent, PathWatcherError>
		internal let isDirectory:Bool
	}

	internal init(_ setup:consuming PathWatchSetup) {
		primitive = setup.primitive
		wakeup = setup.wakeup
		requests = setup.requests
		counter = setup.counter
	}

	deinit {
		_ = close(primitive)
		WakeupPipe.closeHandles(wakeup)
	}

	internal static func newPrimitive() throws(PathWatcherError) -> Int32 {
		let descriptor = __cbedrock_pathwatch_inotify_init()
		guard descriptor >= 0 else {
			throw PathWatcherError.kernelResourceFailure(__cbedrock_pathwatch_errno())
		}
		return descriptor
	}

	internal static func armWakeup(_ primitive:Int32, wakeup:WakeupPipe) throws(PathWatcherError) {
		// the wait mechanism on linux takes its file handles as arguments to each individual wait, so there is no kernel registration to perform here.
	}

	internal static func closePrimitive(_ primitive:consuming Int32) {
		_ = close(primitive)
	}

	internal func pthreadWork() throws(Never) -> Void {
		var waitDescriptors = [
			pollfd(fd:primitive, events:Int16(POLLIN), revents:0),
			pollfd(fd:wakeup.reading, events:Int16(POLLIN), revents:0)
		]
		repeat {
			// this waits until either the inotify instance has records to read or the wakeup channel is signaled. a timeout of -1 means that there is no timeout at all.
			let waitResult = waitDescriptors.withUnsafeMutableBufferPointer { buffer in
				return poll(buffer.baseAddress!, 2, -1)
			}
			if waitResult < 0 {
				let code = __cbedrock_pathwatch_errno()
				if code == EINTR {
					pthread_testcancel()
					continue
				}
				fatalError("bedrock_pathwatch :: poll failed with errno \(code). this is an internal error. \(#file):\(#line)")
			}
			wakeup.drain()
			// the work below adds and removes watches and records which ones this engine holds, so it runs with cancellation disabled: a cancellation that landed in the middle of one of those sequences would leave a watch that nothing holds and nothing releases.
			withoutCancellation {
				performPendingRequests()
				if waitDescriptors[0].revents & Int16(POLLIN) != 0 {
					readPendingRecords()
				}
			}
			// this is the cancellation point of the loop: everything above it is safe to interrupt, and the kernel state of every watch is owned by this thread.
			pthread_testcancel()
		} while true
	}

	/// runs the given work with pthread cancellation disabled, so that a sequence of system calls and bookkeeping is observed either entirely or not at all by the teardown of this engine.
	private func withoutCancellation<R>(_ body:() -> R) -> R {
		var previousState:Int32 = 0
		pthread_setcancelstate(Int32(PTHREAD_CANCEL_DISABLE), &previousState)
		defer {
			pthread_setcancelstate(previousState, nil)
		}
		return body()
	}

	/// performs every operation that the polling thread was asked to perform while it was waiting.
	private func performPendingRequests() {
		let consumer = requests.makeSyncConsumerNonBlocking()
		while let request = consumer.next() {
			switch request {
				case .arm(let path, let kinds, let channel, let acknowledgement):
					arm(path:path, kinds:kinds, channel:channel, acknowledgement:acknowledgement)
				case .disarm(let identifier):
					disarm(identifier)
			}
		}
	}

	/// arms a registration. this runs on the polling thread, which is what makes it safe for this engine to own the kernel state of every registration without any locking.
	private func arm(path:Path, kinds:FileEventKind, channel:FIFO<FileEvent, PathWatcherError>, acknowledgement:Future<UInt64, PathWatcherError>) {
		let location = path.path()
		let watchDescriptor = location.withCString { pointer in
			return __cbedrock_pathwatch_inotify_add(primitive, pointer, FileEventKind.inotifyMask(for:kinds))
		}
		guard watchDescriptor >= 0 else {
			// the acknowledgement is created for exactly one registration and is only ever completed by this thread, so completing it cannot fail.
			try! acknowledgement.setFailure(failure(for:path, errno:__cbedrock_pathwatch_errno()))
			return
		}
		guard registrations[watchDescriptor] == nil else {
			// this path resolves to an object that the kernel already watches, so the kernel answered with the descriptor of the existing registration rather than with a new one. the two registrations could not be told apart afterwards, and the request is refused rather than silently stealing the events of the registration that is already armed. the watch is deliberately not removed here: it belongs to the registration that is already armed.
			try! acknowledgement.setFailure(.pathAlreadyWatched(path))
			return
		}
		var status = stat()
		guard location.withCString({ pointer in return stat(pointer, &status) }) == 0 else {
			let code = __cbedrock_pathwatch_errno()
			_ = __cbedrock_pathwatch_inotify_rm(primitive, watchDescriptor)
			try! acknowledgement.setFailure(failure(for:path, errno:code))
			return
		}
		let identifier = nextIdentifier
		nextIdentifier += 1
		registrations[watchDescriptor] = Registration(identifier:identifier, path:path, kinds:kinds, channel:channel, isDirectory:(status.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR))
		identifiers[identifier] = watchDescriptor
		counter.increment()
		try! acknowledgement.setSuccess(identifier)
	}

	/// releases a registration.
	private func disarm(_ identifier:UInt64) {
		guard let watchDescriptor = identifiers.removeValue(forKey:identifier) else {
			// the registration was already released, which happens when its watch ended before the caller let go of it.
			return
		}
		registrations.removeValue(forKey:watchDescriptor)
		// the kernel answers a removed watch with an `IN_IGNORED` record, which finds no registration to report to and is therefore discarded.
		_ = __cbedrock_pathwatch_inotify_rm(primitive, watchDescriptor)
		counter.decrement()
	}

	/// reads and reports every record that is waiting on the inotify instance.
	private func readPendingRecords() {
		var buffer = [UInt8](repeating:0, count:LinuxPathWatchEngine.recordBufferCapacity)
		readLoop: while true {
			let byteCount = buffer.withUnsafeMutableBytes { rawBuffer in
				return __cbedrock_pathwatch_inotify_read(primitive, rawBuffer.baseAddress!, rawBuffer.count)
			}
			guard byteCount > 0 else {
				// a non-blocking read that returns nothing means that the queue is now empty, which is the state this function exists to reach. any other outcome ends the drain as well, and the records that were already read have already been reported.
				break readLoop
			}
			let decoded = buffer.withUnsafeBytes { rawBuffer in
				return InotifyRecordParser.decode(UnsafeRawBufferPointer(rebasing:rawBuffer[0..<Int(byteCount)]))
			}
			if decoded.truncated {
				// the kernel never splits a record across reads, so a partial record means that this process misread the stream and can no longer be trusted to report it faithfully.
				terminateAll(reason:.kernelDropped)
				break readLoop
			}
			for record in decoded.records {
				dispatch(record)
			}
		}
	}

	/// reports a single record to the registration that produced it.
	private func dispatch(_ record:InotifyRecordParser.Record) {
		if record.mask & InotifyABI.queueOverflow != 0 {
			// the kernel's queue overflowed and records were lost, so what is left of this stream cannot be trusted by any consumer.
			terminateAll(reason:.queueOverflowed)
			return
		}
		guard let registration = registrations[record.watchDescriptor] else {
			// a disarm raced with a record that the kernel had already queued, or the kernel reported the end of a watch that this engine had already reported itself.
			return
		}
		let kinds = FileEventKind.from(inotifyMask:record.mask)
		let isDirectory = record.name == nil ? registration.isDirectory : (record.mask & InotifyABI.isDirectory != 0)
		let fileEvent = FileEvent(path:registration.path, child:record.name, kind:kinds, isDirectory:isDirectory, cookie:record.cookie)
		guard let reason = FileEventKind.inotifyEndReason(mask:record.mask) else {
			registration.channel.yield(fileEvent)
			return
		}
		// the watch is released before its last event is reported, so that a caller which reacts to that event already observes the registration as released. the order of these statements is load bearing.
		registrations.removeValue(forKey:record.watchDescriptor)
		identifiers.removeValue(forKey:registration.identifier)
		counter.decrement()
		registration.channel.yield(fileEvent)
		registration.channel.finish(throwing:PathWatcherError.watchEnded(registration.path, reason))
	}

	/// ends every armed registration, which is how this engine responds to a stream that it can no longer report faithfully.
	private func terminateAll(reason:PathWatcherError.Reason) {
		let terminated = registrations.count
		for (watchDescriptor, registration) in registrations {
			registration.channel.finish(throwing:PathWatcherError.watchEnded(registration.path, reason))
			_ = __cbedrock_pathwatch_inotify_rm(primitive, watchDescriptor)
		}
		registrations.removeAll()
		identifiers.removeAll()
		counter.decrement(by:terminated)
	}

	/// translates a system error into the error that a caller sees.
	private func failure(for path:Path, errno code:Int32) -> PathWatcherError {
		switch code {
			case ENOENT:
				return .pathNotFound(path)
			case EACCES, EPERM:
				return .notPermitted(path)
			case ENOSPC, EMFILE, ENFILE:
				// every watched path costs one inotify watch, which the kernel caps separately from file descriptors.
				return .tooManyWatches(path)
			default:
				return .systemError(path, code)
		}
	}
}
#endif
