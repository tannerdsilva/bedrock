/*
LICENSE MIT
copyright (c) tanner silva 2026. all rights reserved.

bedrock

*/

import Testing
import __cbedrock_pathwatch

#if os(Linux)
import Glibc
#elseif os(macOS)
import Darwin
#endif

extension Tag {
	@Tag internal static var cbedrock_pathwatch:Self
}

extension __cbedrock_test_suite {

	@Suite("__cbedrock_pathwatch",
		.serialized,
		.tags(.__cbedrock, .cbedrock_pathwatch)
	)
	internal struct __cbedrock_pathwatch_tests {

		@Test("__cbedrock_pathwatch :: the wakeup pipe is non-blocking on both ends")
		func wakeupPipeIsNonBlocking() {
			var fds = [Int32](repeating:-1, count:2)
			let created = fds.withUnsafeMutableBufferPointer { buffer in
				return __cbedrock_pathwatch_wakeup_pipe(buffer.baseAddress!)
			}
			#expect(created == 0)
			#expect(fds[0] >= 0)
			#expect(fds[1] >= 0)

			// a write never parks the calling thread, even before the pipe has been read from.
			var byte:UInt8 = 0
			_ = withUnsafePointer(to:&byte) { bytePointer in
				return write(fds[1], bytePointer, 1)
			}

			var readBuffer = [UInt8](repeating:0, count:8)
			let readCount = readBuffer.withUnsafeMutableBufferPointer { buffer in
				return read(fds[0], buffer.baseAddress!, 8)
			}
			#expect(readCount == 1)
			#expect(readBuffer[0] == 0)

			// a read of an empty pipe reports that nothing is pending rather than parking the calling thread.
			let emptyCount = readBuffer.withUnsafeMutableBufferPointer { buffer in
				return read(fds[0], buffer.baseAddress!, 8)
			}
			#expect(emptyCount == -1)
			#expect(__cbedrock_pathwatch_errno() == EAGAIN)

			_ = close(fds[0])
			_ = close(fds[1])
		}

		@Test("__cbedrock_pathwatch :: errno is observable from swift")
		func errnoIsObservable() {
			// creat reports the errno of the most recent failing call, which is how a caller diagnoses a failed arming.
			let descriptor = creat("/nonexistent/bedrock_pathwatch/probe", 0o644)
			#expect(descriptor == -1)
			#expect(__cbedrock_pathwatch_errno() == ENOENT)
		}
	}
}
