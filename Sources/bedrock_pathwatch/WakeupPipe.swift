/*
LICENSE MIT
copyright (c) tanner silva 2026. all rights reserved.

bedrock

*/

import __cbedrock_pathwatch

#if os(Linux)
import Glibc
#elseif os(macOS)
import Darwin
#endif

/// a channel that a watcher uses to interrupt its polling thread.
/// both ends of the channel are non-blocking, so signaling a thread that is already awake can never block the signaling thread, and draining a thread that has nothing to drain can never block the polling thread.
internal struct WakeupPipe:Sendable {

	/// the file handle that the polling thread drains.
	internal let reading:Int32

	/// the file handle that any other thread writes to.
	internal let writing:Int32

	/// creates a new wakeup channel.
	/// - throws: a ``PathWatcherError`` if the operating system refuses to create the channel.
	internal init() throws(PathWatcherError) {
		var descriptors = [Int32](repeating:0, count:2)
		let result = descriptors.withUnsafeMutableBufferPointer { buffer in
			return __cbedrock_pathwatch_wakeup_pipe(buffer.baseAddress!)
		}
		guard result == 0 else {
			throw PathWatcherError.kernelResourceFailure(__cbedrock_pathwatch_errno())
		}
		self.reading = descriptors[0]
		self.writing = descriptors[1]
	}

	/// wakes the polling thread.
	/// a failed write is not an error: the only way that the write end can refuse a byte is by being full, which already means that the polling thread has a pending wakeup to observe.
	internal borrowing func signal() {
		let descriptor = writing
		var byte:UInt8 = 0
		_ = withUnsafeMutableBytes(of:&byte) { buffer in
			return write(descriptor, buffer.baseAddress!, 1)
		}
	}

	/// drains every pending wakeup from this channel.
	internal borrowing func drain() {
		let descriptor = reading
		var buffer = [UInt8](repeating:0, count:64)
		drainLoop: while true {
			let byteCount = buffer.withUnsafeMutableBufferPointer { pointer in
				return read(descriptor, pointer.baseAddress!, 64)
			}
			guard byteCount > 0 else {
				// a non-blocking read that returns nothing means that the channel is now empty, which is the state this function exists to reach.
				break drainLoop
			}
		}
	}

	/// closes both ends of a wakeup channel.
	/// - parameter channel: the channel to close.
	internal static func closeHandles(_ channel:consuming WakeupPipe) {
		_ = close(channel.reading)
		_ = close(channel.writing)
	}
}
