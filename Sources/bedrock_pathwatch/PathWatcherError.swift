/*
LICENSE MIT
copyright (c) tanner silva 2026. all rights reserved.

bedrock

*/

import bedrock

/// the errors that a ``PathWatcher`` throws.
public enum PathWatcherError:Swift.Error, Sendable {

	/// thrown when the operating system refuses to create the kernel primitive that a watcher polls with.
	/// the associated value is the value of `errno` as reported by the operating system.
	case kernelResourceFailure(Int32)

	/// thrown when the pthread that polls for filesystem changes cannot be launched.
	case launchFailure

	/// thrown when the path to be watched does not exist.
	case pathNotFound(Path)

	/// thrown when the path to be watched cannot be watched because the calling process does not have permission to watch it.
	case notPermitted(Path)

	/// thrown when the operating system cannot allocate the resources that are required to watch one more path.
	/// on macOS every watched path costs one file descriptor; on linux every watched path costs one inotify watch.
	case tooManyWatches(Path)

	/// thrown when a path cannot be watched because the object that it resolves to is already being watched.
	/// - NOTE: linux identifies a watch by the object that it describes rather than by the path that was used to reach it, so two registrations that resolve to the same object cannot be told apart by the kernel: they share a single watch descriptor and a single event mask. macOS has no such restriction, because every watch holds a descriptor of its own.
	case pathAlreadyWatched(Path)

	/// thrown when the operating system reports an error that does not have a dedicated case in this enumeration.
	case systemError(Path, Int32)

	/// thrown from ``PathWatcher/Watch/next()`` after the last event of a watch has been delivered, describing why the watch ended.
	/// re-arming a watch that ended is the caller's decision: a watch that ended because its path was unlinked or renamed cannot be revived without watching the path again.
	case watchEnded(Path, Reason)

	/// the reason that a watch ended.
	public enum Reason:Sendable, Equatable {

		/// the watched path itself was unlinked.
		case unlinked

		/// the watched path itself was moved or renamed.
		case renamed

		/// the filesystem that contains the watched path was unmounted.
		case unmounted

		/// the kernel's event queue overflowed and events were lost, so no consumer can trust the stream any further.
		case queueOverflowed

		/// the kernel removed the watch for a reason that is not otherwise described by this enumeration.
		case kernelDropped
	}
}
