/*
LICENSE MIT
copyright (c) tanner silva 2026. all rights reserved.

bedrock

*/

import bedrock
import bedrock_fifo
import bedrock_future
import bedrock_pthread

/// monitors filesystem paths for changes.
/// a watcher owns one kernel primitive and one pthread that polls it, which means that any number of paths can be monitored by a single watcher at the cost of a single polling thread. the pthread sleeps in the kernel while it waits, so an idle watcher consumes no processor time.
/// events are delivered in the order that the kernel reports them, and each watch is the exclusive consumer of the events that its own registration produces.
/// - NOTE: the kernel coalesces changes, and both supported platforms are permitted to drop records under memory pressure. treat an event stream as a notification that something changed, not as an auditable log of everything that happened.
public final class PathWatcher:Sendable {

	#if os(Linux)
	internal typealias PlatformEngine = LinuxPathWatchEngine
	#elseif os(macOS)
	internal typealias PlatformEngine = MacOSPathWatchEngine
	#endif

	/// the pthread that waits for filesystem changes.
	private let pollingThread:Running<PlatformEngine>

	/// the stream of operations that are handed to the polling thread.
	private let requests:FIFO<PathWatchRequest, Never>

	/// the channel that interrupts the polling thread.
	private let wakeup:WakeupPipe

	/// the number of registrations that this watcher holds.
	private let counter:ActiveWatchCounter

	/// the kinds of change that the platform this watcher runs on is able to report.
	/// kinds that are absent from this set are accepted by ``watch(path:kinds:)`` but can never be delivered: macOS cannot report that an entry appeared in, or disappeared from, a watched directory, and only linux reports that a writer closed a file.
	/// - NOTE: this is a property of the platform rather than of an instance, but it is deliberately reachable from an instance as well, so that a caller who already holds a watcher never has to name the platform.
	public static var deliverableKinds:FileEventKind {
		#if os(Linux)
		return [.modified, .attributesChanged, .appeared, .disappeared, .closedAfterWrite, .removedSelf, .renamedSelf, .watchEnded]
		#elseif os(macOS)
		return [.modified, .attributesChanged, .removedSelf, .renamedSelf, .watchEnded]
		#endif
	}

	/// the number of registrations that this watcher currently holds.
	/// this reaches zero once every ``Watch`` that was created from this watcher has been deinitialized, which makes it a direct witness of the fact that a watcher released every file descriptor that its registrations acquired.
	public var activeWatchCount:Int {
		return counter.value
	}

	/// initialize a new watcher, creating the kernel primitive that it polls with and launching the pthread that polls it.
	/// - throws: a ``PathWatcherError`` if the kernel primitive cannot be created, if the wakeup channel cannot be created, or if the polling thread cannot be launched.
	public init() throws(PathWatcherError) {
		let channel:WakeupPipe
		do {
			channel = try WakeupPipe()
		} catch {
			throw error
		}
		let kernelPrimitive:Int32
		do {
			kernelPrimitive = try PlatformEngine.newPrimitive()
		} catch {
			WakeupPipe.closeHandles(channel)
			throw error
		}
		do {
			try PlatformEngine.armWakeup(kernelPrimitive, wakeup:channel)
		} catch {
			PlatformEngine.closePrimitive(kernelPrimitive)
			WakeupPipe.closeHandles(channel)
			throw error
		}
		let requestStream = FIFO<PathWatchRequest, Never>()
		let registrationCounter = ActiveWatchCounter()
		let setup = PathWatchSetup(primitive:kernelPrimitive, wakeup:channel, requests:requestStream, counter:registrationCounter)
		let launchedThread:Running<PlatformEngine>
		do {
			launchedThread = try PlatformEngine.launch(setup)
		} catch {
			PlatformEngine.closePrimitive(kernelPrimitive)
			WakeupPipe.closeHandles(channel)
			throw PathWatcherError.launchFailure
		}
		self.pollingThread = launchedThread
		self.requests = requestStream
		self.wakeup = channel
		self.counter = registrationCounter
	}

	/// start watching a path for the kinds of change that are requested.
	/// the returned watch is armed by the time this function returns: the kernel registration is performed by the polling thread, and this function does not complete until that registration has succeeded. a caller that mutates the filesystem immediately after this function returns cannot lose the resulting event.
	/// - parameter path: the path to watch. the path must exist.
	/// - parameter kinds: the kinds of change to watch for. terminal kinds are always requested, regardless of whether they appear in this argument, because a watch that cannot report its own death cannot be cleaned up.
	/// - returns: a watch that is the exclusive consumer of the events that this registration produces.
	/// - throws: a ``PathWatcherError`` if the path cannot be watched. a path that resolves to an object which another watch of the same watcher already describes is refused with ``PathWatcherError/pathAlreadyWatched(_:)`` on linux, where the kernel identifies a watch by the object rather than by the path. macOS has no such restriction.
	public func watch(path:consuming Path, kinds:FileEventKind) async throws(PathWatcherError) -> Watch {
		let channel = FIFO<FileEvent, PathWatcherError>()
		let acknowledgement = Future<UInt64, PathWatcherError>()
		requests.yield(.arm(path:path, kinds:kinds, channel:channel, acknowledgement:acknowledgement))
		wakeup.signal()
		let outcome = await acknowledgement.result(throwingOnCurrentTaskCancellation:Never.self)
		guard let outcome else {
			// an acknowledgement is only cancelled when the watcher that created it is being torn down, which cannot happen while this call holds a reference to that watcher.
			throw PathWatcherError.watchEnded(path, .kernelDropped)
		}
		let identifier = try outcome.get()
		return Watch(id:identifier, path:path, kinds:kinds, consumer:channel.makeAsyncConsumer(), watcher:self)
	}

	/// asks the polling thread to release a registration.
	internal borrowing func disarm(_ identifier:UInt64) {
		requests.yield(.disarm(id:identifier))
		wakeup.signal()
	}

	deinit {
		// the polling thread is parked in a wait that a cancellation cannot reach, so the cancellation is requested first and the thread is then woken to observe it at its next cancellation test point. the order of these two statements is load bearing.
		try? pollingThread.cancel()
		wakeup.signal()
	}
}
