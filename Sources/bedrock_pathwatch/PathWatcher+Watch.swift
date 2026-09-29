/*
LICENSE MIT
copyright (c) tanner silva 2026. all rights reserved.

bedrock

*/

import bedrock
import bedrock_fifo

extension PathWatcher {

	/// an active registration on a ``PathWatcher``.
	/// a watch is the exclusive consumer of the events that its registration produces, and it releases the registration when it is deinitialized, so a registration lives exactly as long as the handle that represents it. letting go of a watch is therefore the only way to stop watching a path, and it is also the only cleanup that a caller has to perform.
	public struct Watch:~Copyable {

		/// the identifier of this registration.
		public let id:UInt64

		/// the path that was registered.
		public let path:Path

		/// the kinds of change that were requested when this registration was armed.
		/// - NOTE: terminal kinds are always requested regardless of what this value holds, because a watch that cannot report its own death cannot be cleaned up.
		public let kinds:FileEventKind

		/// the consumer that drains the events of this registration.
		internal let consumer:FIFO<FileEvent, PathWatcherError>.AsyncConsumer

		/// the watcher that owns this registration.
		internal let watcher:PathWatcher

		/// initialize a new watch.
		/// - parameter id: the identifier of this registration.
		/// - parameter path: the path that was registered.
		/// - parameter kinds: the kinds of change that were requested.
		/// - parameter consumer: the consumer that drains the events of this registration.
		/// - parameter watcher: the watcher that owns this registration.
		internal init(id:UInt64, path:Path, kinds:FileEventKind, consumer:FIFO<FileEvent, PathWatcherError>.AsyncConsumer, watcher:PathWatcher) {
			self.id = id
			self.path = path
			self.kinds = kinds
			self.consumer = consumer
			self.watcher = watcher
		}

		/// wait for the next event that this registration produces.
		/// - returns: the next event. `nil` is only returned if the stream ended without an error, which the watcher does not currently do.
		/// - throws: a ``PathWatcherError`` after the last event of the watch has been delivered, when the watch ended because the watched path was removed, because it was renamed, or because the kernel dropped the watch. the final event is delivered before this error is thrown, so a caller that only cares about the terminal event can treat the throw as the end of the stream.
		public borrowing func next() async throws(PathWatcherError) -> FileEvent? {
			return try await consumer.next()
		}

		deinit {
			watcher.disarm(id)
		}
	}
}
