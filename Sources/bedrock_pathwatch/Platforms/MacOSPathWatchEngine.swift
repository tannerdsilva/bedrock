/*
LICENSE MIT
copyright (c) tanner silva 2026. all rights reserved.

bedrock

*/

#if os(macOS)
import Darwin
import __cbedrock_pathwatch
import bedrock
import bedrock_fifo
import bedrock_future
import bedrock_pthread

/// the macOS engine: one kqueue instance, and one `O_EVTONLY` file descriptor per watched path.
/// - NOTE: the file descriptors that watch paths are owned by this engine rather than by the watcher that created it. bedrock_pthread deinitializes the engine on both the normal return path and the cancellation path, so this is the one place where those descriptors are guaranteed to be released no matter how the polling thread is stopped.
internal final class MacOSPathWatchEngine:PathWatchEngine, @unchecked Sendable {

	internal typealias ArgumentType = PathWatchSetup
	internal typealias ReturnType = Void
	internal typealias ThrowType = Never

	/// the kqueue file descriptor that this engine polls.
	internal let primitive:Int32

	/// the channel that interrupts the wait.
	private let wakeup:WakeupPipe

	/// the stream of operations to perform.
	private let requests:FIFO<PathWatchRequest, Never>

	/// the counter of armed registrations.
	private let counter:ActiveWatchCounter

	/// the armed registrations, keyed by the file descriptor that watches each path.
	private var registrations:[Int32:Registration] = [:]

	/// the file descriptor that watches each registration identifier.
	private var descriptors:[UInt64:Int32] = [:]

	/// the next registration identifier to hand out.
	private var nextIdentifier:UInt64 = 1

	/// the memory space that the kernel writes events into.
	private var eventBuffer:UnsafeMutablePointer<Darwin.kevent> = .allocate(capacity:32)

	/// the number of events that the event buffer can hold.
	private var eventBufferCapacity:Int32 = 32

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
		for descriptor in registrations.keys {
			_ = close(descriptor)
		}
		eventBuffer.deallocate()
		_ = close(primitive)
		WakeupPipe.closeHandles(wakeup)
	}

	internal static func newPrimitive() throws(PathWatcherError) -> Int32 {
		let descriptor = kqueue()
		guard descriptor >= 0 else {
			throw PathWatcherError.kernelResourceFailure(__cbedrock_pathwatch_errno())
		}
		return descriptor
	}

	internal static func armWakeup(_ primitive:Int32, wakeup:WakeupPipe) throws(PathWatcherError) {
		var change = Darwin.kevent()
		change.ident = UInt(wakeup.reading)
		change.filter = Int16(EVFILT_READ)
		change.flags = UInt16(EV_ADD | EV_CLEAR)
		change.fflags = 0
		change.data = 0
		change.udata = nil
		guard kevent(primitive, &change, 1, nil, 0, nil) == 0 else {
			throw PathWatcherError.kernelResourceFailure(__cbedrock_pathwatch_errno())
		}
	}

	internal static func closePrimitive(_ primitive:consuming Int32) {
		_ = close(primitive)
	}

	internal func pthreadWork() throws(Never) -> Void {
		repeat {
			// this waits until something changes. `nil` as the timeout means that there is no timeout at all.
			let eventCount = kevent(primitive, nil, 0, eventBuffer, eventBufferCapacity, nil)
			if eventCount < 0 {
				let code = __cbedrock_pathwatch_errno()
				if code == EINTR {
					// a signal interrupted the wait. this is also where a pending cancellation is observed if the signal that interrupted the wait was a cancellation.
					pthread_testcancel()
					continue
				}
				fatalError("bedrock_pathwatch :: kevent failed with errno \(code). this is an internal error. \(#file):\(#line)")
			}
			wakeup.drain()
			// the work below opens and closes descriptors and records which ones this engine owns. it therefore runs with cancellation disabled: a cancellation that landed in the middle of one of those sequences would leave a descriptor that nothing owns, and nothing would release it, because the teardown of this engine releases exactly the descriptors that its bookkeeping names.
			withoutCancellation {
				performPendingRequests()
				for index in 0..<Int(eventCount) {
					dispatch(eventBuffer[index])
				}
				if (eventCount * 2) > eventBufferCapacity {
					reallocate(to:eventBufferCapacity * 2)
				}
			}
			// this is the cancellation point of the loop: everything above it is safe to interrupt, and everything that a watch owns has been released by the time the loop is entered again.
			pthread_testcancel()
		} while true
	}

	/// grows the event buffer.
	private func reallocate(to capacity:Int32) {
		eventBuffer.deallocate()
		eventBufferCapacity = capacity
		eventBuffer = .allocate(capacity:Int(capacity))
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
		let descriptor = open(location, O_EVTONLY)
		guard descriptor >= 0 else {
			// the acknowledgement is created for exactly one registration and is only ever completed by this thread, so completing it cannot fail.
			try! acknowledgement.setFailure(failure(for:path, errno:__cbedrock_pathwatch_errno()))
			return
		}
		var status = stat()
		// the descriptor that was just opened is what describes the vnode that this watch monitors, so it is described directly rather than by name. that keeps a path that changes identity between the open and the description from being reported as a failure.
		guard fstat(descriptor, &status) == 0 else {
			let code = __cbedrock_pathwatch_errno()
			_ = close(descriptor)
			try! acknowledgement.setFailure(failure(for:path, errno:code))
			return
		}
		var change = Darwin.kevent()
		change.ident = UInt(descriptor)
		change.filter = Int16(EVFILT_VNODE)
		change.flags = UInt16(EV_ADD | EV_CLEAR)
		change.fflags = FileEventKind.macOSNoteFlags(for:kinds)
		change.data = 0
		change.udata = nil
		guard kevent(primitive, &change, 1, nil, 0, nil) == 0 else {
			let code = __cbedrock_pathwatch_errno()
			_ = close(descriptor)
			try! acknowledgement.setFailure(failure(for:path, errno:code))
			return
		}
		let identifier = nextIdentifier
		nextIdentifier += 1
		registrations[descriptor] = Registration(identifier:identifier, path:path, kinds:kinds, channel:channel, isDirectory:(status.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR))
		descriptors[identifier] = descriptor
		counter.increment()
		try! acknowledgement.setSuccess(identifier)
	}

	/// releases a registration.
	private func disarm(_ identifier:UInt64) {
		guard let descriptor = descriptors.removeValue(forKey:identifier) else {
			// the registration was already released, which happens when its watch ended before the caller let go of it.
			return
		}
		registrations.removeValue(forKey:descriptor)
		// closing the descriptor removes every kqueue registration that was armed for it, so no explicit deletion is performed.
		_ = close(descriptor)
		counter.decrement()
	}

	/// reports a single event to the registration that produced it.
	private func dispatch(_ event:Darwin.kevent) {
		let descriptor = Int32(event.ident)
		if descriptor == wakeup.reading {
			// the wakeup channel is drained by the caller of this function.
			return
		}
		guard event.filter == Int16(EVFILT_VNODE) else {
			return
		}
		guard let registration = registrations[descriptor] else {
			// a disarm raced with an event that the kernel had already queued.
			return
		}
		let kinds = FileEventKind.from(macOSNoteFlags:event.fflags)
		let fileEvent = FileEvent(path:registration.path, child:nil, kind:kinds, isDirectory:registration.isDirectory, cookie:0)
		guard let reason = FileEventKind.macOSEndReason(noteFlags:event.fflags) else {
			registration.channel.yield(fileEvent)
			return
		}
		// the watch is released before its last event is reported, so that a caller which reacts to that event already observes the registration as released. the order of these statements is load bearing.
		registrations.removeValue(forKey:descriptor)
		descriptors.removeValue(forKey:registration.identifier)
		// closing the descriptor removes every kqueue registration that was armed for it, so no explicit deletion is performed.
		_ = close(descriptor)
		counter.decrement()
		registration.channel.yield(fileEvent)
		registration.channel.finish(throwing:PathWatcherError.watchEnded(registration.path, reason))
	}

	/// translates a system error into the error that a caller sees.
	private func failure(for path:Path, errno code:Int32) -> PathWatcherError {
		switch code {
			case ENOENT:
				return .pathNotFound(path)
			case EACCES, EPERM:
				return .notPermitted(path)
			case EMFILE, ENFILE:
				// every watched path costs one file descriptor on macOS.
				return .tooManyWatches(path)
			default:
				return .systemError(path, code)
		}
	}
}
#endif
