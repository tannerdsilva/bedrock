/*
LICENSE MIT
copyright (c) tanner silva 2026. all rights reserved.

bedrock

*/

import bedrock
import bedrock_fifo
import bedrock_future
import bedrock_pthread
import Synchronization

/// counts the registrations that a watcher currently holds.
/// the count is maintained by the polling thread and read by callers, which is what makes it useful for observing that a watcher released every file descriptor that it acquired.
internal final class ActiveWatchCounter:Sendable {

	private let storage:Mutex<Int> = .init(0)

	/// records that one more registration was armed.
	internal func increment() {
		storage.withLock { value in
			value += 1
		}
	}

	/// records that registrations were disarmed.
	/// - parameter amount: the number of registrations that were disarmed.
	internal func decrement(by amount:Int = 1) {
		storage.withLock { value in
			value -= amount
		}
	}

	/// the number of registrations that are currently armed.
	internal var value:Int {
		return storage.withLock { value in
			return value
		}
	}
}

/// an operation that a caller asks a polling thread to perform.
internal enum PathWatchRequest:Sendable {

	/// arm a watch for a path, and complete the acknowledgement with the identifier of the new registration.
	/// the acknowledgement is completed by the polling thread after the kernel registration succeeds, which is what allows ``PathWatcher/watch(path:kinds:)`` to guarantee that a watch is armed by the time it returns.
	case arm(path:Path, kinds:FileEventKind, channel:FIFO<FileEvent, PathWatcherError>, acknowledgement:Future<UInt64, PathWatcherError>)

	/// disarm the registration with the given identifier.
	case disarm(id:UInt64)
}

/// the memory space that is handed to a polling thread when a watcher is initialized.
internal struct PathWatchSetup:Sendable {

	/// the kernel primitive that the polling thread waits on.
	internal let primitive:Int32

	/// the channel that interrupts the polling thread.
	internal let wakeup:WakeupPipe

	/// the stream of operations that the polling thread performs.
	internal let requests:FIFO<PathWatchRequest, Never>

	/// the counter of currently armed registrations.
	internal let counter:ActiveWatchCounter
}

/// the interface that a platform's filesystem change mechanism implements.
/// an engine is the work that a polling thread runs: it is constructed on the polling thread, it owns every file descriptor that it uses, and it releases them when it is deinitialized. bedrock_pthread deinitializes an engine on both the normal return path and the cancellation path, so the descriptor ownership that this protocol implies holds in every case.
internal protocol PathWatchEngine:PThreadWork where ArgumentType == PathWatchSetup, ReturnType == Void, ThrowType == Never {

	/// creates a new kernel primitive for the engine to poll with.
	/// - throws: a ``PathWatcherError`` if the operating system refuses to create the primitive.
	static func newPrimitive() throws(PathWatcherError) -> Int32

	/// registers the wakeup channel with the kernel primitive, so that the polling thread can be interrupted while it waits.
	/// this is called once, by the initializing thread, before the polling thread is launched.
	/// - throws: a ``PathWatcherError`` if the operating system refuses the registration.
	static func armWakeup(_ primitive:Int32, wakeup:WakeupPipe) throws(PathWatcherError)

	/// closes a kernel primitive.
	/// - parameter primitive: the primitive to close.
	static func closePrimitive(_ primitive:consuming Int32)

	/// the kernel primitive that this engine polls with.
	var primitive:Int32 { get }
}
