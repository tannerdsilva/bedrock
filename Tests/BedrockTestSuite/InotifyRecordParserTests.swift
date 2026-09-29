/*
LICENSE MIT
copyright (c) tanner silva 2026. all rights reserved.

bedrock

*/

import Testing
@testable import bedrock_pathwatch
import __cbedrock_pathwatch

extension BedrockTestSuite {

	/// the decoder tests exercise the linux inotify record layout on every host, including hosts that have no inotify at all, by decoding fabricated record streams.
	@Suite("bedrock_pathwatch_inotify",
		.serialized,
		.tags(.bedrock, .pathwatch)
	)
	internal struct InotifyRecordParserTests {

		/// builds a single inotify record, exactly as the kernel lays it out.
		private static func record(watchDescriptor:Int32, mask:UInt32, cookie:UInt32, name:String?) -> [UInt8] {
			var bytes = [UInt8]()
			func appendInteger(_ value:UInt32) {
				bytes.append(UInt8(truncatingIfNeeded:value))
				bytes.append(UInt8(truncatingIfNeeded:value >> 8))
				bytes.append(UInt8(truncatingIfNeeded:value >> 16))
				bytes.append(UInt8(truncatingIfNeeded:value >> 24))
			}
			appendInteger(UInt32(bitPattern:watchDescriptor))
			appendInteger(mask)
			appendInteger(cookie)
			guard let name else {
				appendInteger(0)
				return bytes
			}
			var nameBytes = Array(name.utf8)
			nameBytes.append(0)
			// the kernel pads the name field to a four byte boundary.
			while nameBytes.count % 4 != 0 {
				nameBytes.append(0)
			}
			appendInteger(UInt32(nameBytes.count))
			bytes.append(contentsOf:nameBytes)
			return bytes
		}

		private static func decode(_ bytes:[UInt8]) -> (records:[InotifyRecordParser.Record], truncated:Bool) {
			return bytes.withUnsafeBytes { rawBuffer in
				return InotifyRecordParser.decode(rawBuffer)
			}
		}

		@Test("inotify :: a record that names an entry is decoded")
		func namedRecordIsDecoded() {
			let decoded = Self.decode(Self.record(watchDescriptor:7, mask:InotifyABI.create, cookie:0, name:"a.txt")).records
			#expect(decoded.count == 1)
			#expect(decoded.first?.watchDescriptor == 7)
			#expect(decoded.first?.mask == InotifyABI.create)
			#expect(decoded.first?.cookie == 0)
			#expect(decoded.first?.name == "a.txt")
		}

		@Test("inotify :: a name that fills its field exactly is decoded")
		func fullWidthNameIsDecoded() {
			// a name of three bytes is padded by one byte, which is the boundary case of the four byte alignment.
			let decoded = Self.decode(Self.record(watchDescriptor:1, mask:InotifyABI.delete, cookie:0, name:"abc")).records
			#expect(decoded.first?.name == "abc")
			// a name of four bytes needs no padding at all.
			let unpadded = Self.decode(Self.record(watchDescriptor:1, mask:InotifyABI.delete, cookie:0, name:"abcd")).records
			#expect(unpadded.first?.name == "abcd")
		}

		@Test("inotify :: a record that carries no name reports no name")
		func unnamedRecordIsDecoded() {
			let decoded = Self.decode(Self.record(watchDescriptor:3, mask:InotifyABI.deleteSelf, cookie:0, name:nil)).records
			#expect(decoded.count == 1)
			#expect(decoded.first?.name == nil)
			#expect(decoded.first?.mask == InotifyABI.deleteSelf)
		}

		@Test("inotify :: a stream of records is decoded in order")
		func streamIsDecodedInOrder() {
			var bytes = [UInt8]()
			bytes.append(contentsOf:Self.record(watchDescriptor:1, mask:InotifyABI.create, cookie:0, name:"one"))
			bytes.append(contentsOf:Self.record(watchDescriptor:2, mask:InotifyABI.modify, cookie:9, name:"two"))
			bytes.append(contentsOf:Self.record(watchDescriptor:3, mask:InotifyABI.ignored, cookie:0, name:nil))
			let decoded = Self.decode(bytes).records
			#expect(decoded.count == 3)
			#expect(decoded.map { $0.watchDescriptor } == [1, 2, 3])
			#expect(decoded.map { $0.name } == ["one", "two", nil])
			#expect(decoded[1].cookie == 9)
		}

		@Test("inotify :: a record that is not fully contained in the buffer is discarded and reported")
		func truncatedRecordIsDiscarded() {
			var bytes = Self.record(watchDescriptor:1, mask:InotifyABI.create, cookie:0, name:"complete")
			let completeCount = bytes.count
			// a record whose name field claims more bytes than the buffer holds.
			bytes.append(contentsOf:Self.record(watchDescriptor:2, mask:InotifyABI.create, cookie:0, name:"truncated"))
			let truncated = Array(bytes[0..<(completeCount + 6)])
			let decoded = Self.decode(truncated)
			// the complete record is decoded, and the partial record is never read past the end of the buffer.
			#expect(decoded.records.count == 1)
			#expect(decoded.records.first?.name == "complete")
			// the partial record is reported rather than silently dropped, because a stream that reports a subset of what it was given cannot be trusted and the caller has to decide what to do about it.
			#expect(decoded.truncated == true)
		}

		@Test("inotify :: a partial header is discarded and reported")
		func truncatedHeaderIsDiscarded() {
			let record = Self.record(watchDescriptor:1, mask:InotifyABI.modify, cookie:0, name:"one")
			let partialHeader = Array(record[0..<Self.headerSizeForTesting - 3])
			let decoded = Self.decode(partialHeader)
			#expect(decoded.records.isEmpty)
			#expect(decoded.truncated == true)
		}

		@Test("inotify :: a complete buffer is not reported as truncated")
		func completeBufferIsNotTruncated() {
			let bytes = Self.record(watchDescriptor:1, mask:InotifyABI.modify, cookie:0, name:"one")
			let decoded = Self.decode(bytes)
			#expect(decoded.records.count == 1)
			#expect(decoded.truncated == false)
			#expect(Self.decode([]).truncated == false)
		}

		@Test("inotify :: only the bytes that a read reported are decoded")
		func trailingPaddingIsNotDecoded() {
			let record = Self.record(watchDescriptor:1, mask:InotifyABI.modify, cookie:0, name:"one")
			let padded = record + [UInt8](repeating:0, count:64)
			// decoding exactly the byte count that a read reported yields the record that was read.
			let exact = padded.withUnsafeBytes { rawBuffer in
				return InotifyRecordParser.decode(UnsafeRawBufferPointer(rebasing:rawBuffer.prefix(record.count)))
			}
			#expect(exact.records.count == 1)
			// decoding the entire buffer would also decode the padding, which is why the byte count of the read must be passed rather than the capacity of the buffer.
			#expect(Self.decode(padded).records.count != 1)
		}

		@Test("inotify :: a watch descriptor can be reused across records")
		func reusedWatchDescriptorIsDecoded() {
			var bytes = [UInt8]()
			bytes.append(contentsOf:Self.record(watchDescriptor:4, mask:InotifyABI.delete, cookie:0, name:"old"))
			bytes.append(contentsOf:Self.record(watchDescriptor:4, mask:InotifyABI.create, cookie:0, name:"new"))
			let decoded = Self.decode(bytes).records
			#expect(decoded.count == 2)
			#expect(decoded.map { $0.name } == ["old", "new"])
		}

		/// the size of the fixed size header that precedes every record's name, restated here so that a test can build a partial header on purpose.
		private static var headerSizeForTesting:Int {
			return 16
		}

		// MARK: mapping

		@Test("inotify :: every kernel mask is translated into the change that it reports")
		func masksAreTranslated() {
			#expect(FileEventKind.from(inotifyMask:InotifyABI.modify) == [.modified])
			#expect(FileEventKind.from(inotifyMask:InotifyABI.attrib) == [.attributesChanged])
			#expect(FileEventKind.from(inotifyMask:InotifyABI.create) == [.appeared])
			#expect(FileEventKind.from(inotifyMask:InotifyABI.movedTo) == [.appeared])
			#expect(FileEventKind.from(inotifyMask:InotifyABI.delete) == [.disappeared])
			#expect(FileEventKind.from(inotifyMask:InotifyABI.movedFrom) == [.disappeared])
			#expect(FileEventKind.from(inotifyMask:InotifyABI.closeWrite) == [.closedAfterWrite])
			#expect(FileEventKind.from(inotifyMask:InotifyABI.deleteSelf) == [.removedSelf])
			#expect(FileEventKind.from(inotifyMask:InotifyABI.moveSelf) == [.renamedSelf])
			#expect(FileEventKind.from(inotifyMask:InotifyABI.ignored) == [.watchEnded])
			#expect(FileEventKind.from(inotifyMask:InotifyABI.unmount) == [.watchEnded])
			#expect(FileEventKind.from(inotifyMask:InotifyABI.queueOverflow) == [.watchEnded])
		}

		@Test("inotify :: the reason that a watch ended is read from the mask")
		func endReasonsAreReadFromTheMask() {
			#expect(FileEventKind.inotifyEndReason(mask:InotifyABI.deleteSelf) == .unlinked)
			#expect(FileEventKind.inotifyEndReason(mask:InotifyABI.moveSelf) == .renamed)
			#expect(FileEventKind.inotifyEndReason(mask:InotifyABI.unmount) == .unmounted)
			#expect(FileEventKind.inotifyEndReason(mask:InotifyABI.ignored) == .kernelDropped)
			#expect(FileEventKind.inotifyEndReason(mask:InotifyABI.modify) == nil)
		}

		@Test("inotify :: a mask that reports several changes is translated into all of them")
		func combinedMasksAreTranslated() {
			let translated = FileEventKind.from(inotifyMask:InotifyABI.attrib | InotifyABI.deleteSelf)
			#expect(translated.contains(.attributesChanged))
			#expect(translated.contains(.removedSelf))
			#expect(translated.isDisjoint(with:.terminal) == false)
		}

		@Test("inotify :: the directory bit is not itself a change")
		func directoryBitIsNotAChange() {
			#expect(FileEventKind.from(inotifyMask:InotifyABI.isDirectory) == [])
		}

		@Test("inotify :: the masks that report the end of a watch are always requested")
		func terminalMasksAreAlwaysRequested() {
			let terminalMasks = InotifyABI.deleteSelf | InotifyABI.moveSelf | InotifyABI.unmount
			// a caller who asks for nothing at all still asks for the end of the watch.
			#expect(FileEventKind.inotifyMask(for:[]) & terminalMasks == terminalMasks)
			// a caller who only cares about writes still asks for the end of the watch, because a watch that cannot report its own death holds a descriptor that nothing will ever release and stops working without saying so.
			#expect(FileEventKind.inotifyMask(for:[.modified]) & terminalMasks == terminalMasks)
			// the end of a watch is raised by the kernel, so no mask of its own can be requested for it.
			#expect(FileEventKind.inotifyMask(for:[.modified]) & InotifyABI.modify == InotifyABI.modify)
		}

		@Test("inotify :: the changes that a caller asks for survive a round trip to a kernel mask")
		func requestedChangesSurviveRoundTrip() {
			let requestable:FileEventKind = [.modified, .attributesChanged, .appeared, .disappeared, .closedAfterWrite]
			let mask = FileEventKind.inotifyMask(for:requestable)
			let translated = FileEventKind.from(inotifyMask:mask)
			// every requested change is translated back, alongside the terminal changes that are always requested.
			#expect(translated.isSuperset(of:requestable))
			#expect(translated.contains(.removedSelf))
			#expect(translated.contains(.renamedSelf))
		}

		#if os(Linux)
		@Test("inotify :: the restated abi matches the system header")
		func restatedABIMatchesSystemHeader() {
			// the values in `InotifyABI` are restated so that the linux decoding path can be compiled and tested on hosts that are not running linux. this is the assertion that keeps the restatement honest, and it is only possible on a host where the system header exists.
			#expect(InotifyABI.modify == UInt32(__CBEDROCK_PATHWATCH_IN_MODIFY))
			#expect(InotifyABI.attrib == UInt32(__CBEDROCK_PATHWATCH_IN_ATTRIB))
			#expect(InotifyABI.closeWrite == UInt32(__CBEDROCK_PATHWATCH_IN_CLOSE_WRITE))
			#expect(InotifyABI.movedFrom == UInt32(__CBEDROCK_PATHWATCH_IN_MOVED_FROM))
			#expect(InotifyABI.movedTo == UInt32(__CBEDROCK_PATHWATCH_IN_MOVED_TO))
			#expect(InotifyABI.create == UInt32(__CBEDROCK_PATHWATCH_IN_CREATE))
			#expect(InotifyABI.delete == UInt32(__CBEDROCK_PATHWATCH_IN_DELETE))
			#expect(InotifyABI.deleteSelf == UInt32(__CBEDROCK_PATHWATCH_IN_DELETE_SELF))
			#expect(InotifyABI.moveSelf == UInt32(__CBEDROCK_PATHWATCH_IN_MOVE_SELF))
			#expect(InotifyABI.unmount == UInt32(__CBEDROCK_PATHWATCH_IN_UNMOUNT))
			#expect(InotifyABI.queueOverflow == UInt32(__CBEDROCK_PATHWATCH_IN_Q_OVERFLOW))
			#expect(InotifyABI.ignored == UInt32(__CBEDROCK_PATHWATCH_IN_IGNORED))
			#expect(InotifyABI.isDirectory == UInt32(__CBEDROCK_PATHWATCH_IN_ISDIR))
		}
		#endif
	}
}
