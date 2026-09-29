/*
LICENSE MIT
copyright (c) tanner silva 2026. all rights reserved.

bedrock

*/

/// decodes the byte stream that the linux `inotify` interface produces into discrete records.
/// the record layout is the kernel's `struct inotify_event`: a 32 bit watch descriptor, a 32 bit mask, a 32 bit cookie, and a 32 bit name length, followed by a name of that length. the kernel pads the name with null bytes to a four byte boundary, and reports a name length of zero for changes that concern the watched path itself rather than an entry inside it.
/// - NOTE: this type is deliberately platform neutral so that the linux decoding path is compiled and tested on every platform. it performs no system calls.
internal enum InotifyRecordParser {

	/// the size of the fixed size header that precedes every record's name.
	internal static let headerSize = 16

	/// one decoded inotify record.
	internal struct Record:Equatable {

		/// the watch descriptor that the record belongs to.
		internal let watchDescriptor:Int32

		/// the mask of events that the record reports.
		internal let mask:UInt32

		/// the cookie that pairs the two halves of a reported move.
		internal let cookie:UInt32

		/// the name of the entry that the record concerns, when the record reports one.
		internal let name:String?
	}

	/// decodes every complete record that the given bytes hold.
	/// a trailing partial record is never read past the end of the buffer, and its presence is reported so that the caller can react to a stream that it cannot trust.
	/// - parameter bytes: the raw bytes that were read from an inotify file handle.
	/// - returns: the decoded records, and whether a trailing partial record was present.
	internal static func decode(_ bytes:UnsafeRawBufferPointer) -> (records:[Record], truncated:Bool) {
		var records:[Record] = []
		var offset = 0
		var truncated = false
		decodeLoop: while offset < bytes.count {
			guard offset + headerSize <= bytes.count else {
				// a partial header at the tail of the buffer.
				truncated = true
				break decodeLoop
			}
			let watchDescriptor = bytes.loadUnaligned(fromByteOffset:offset, as:Int32.self)
			let mask = bytes.loadUnaligned(fromByteOffset:offset + 4, as:UInt32.self)
			let cookie = bytes.loadUnaligned(fromByteOffset:offset + 8, as:UInt32.self)
			let nameLength = Int(bytes.loadUnaligned(fromByteOffset:offset + 12, as:UInt32.self))
			let recordSize = headerSize + nameLength
			guard offset + recordSize <= bytes.count else {
				// a partial record at the tail of the buffer.
				truncated = true
				break decodeLoop
			}
			var name:String? = nil
			if nameLength > 0 {
				let nameBytes = UnsafeRawBufferPointer(rebasing:bytes[(offset + headerSize)..<(offset + recordSize)])
				// the kernel pads the name to a four byte boundary with null bytes, so the name is the bytes that precede the first null byte.
				let terminator = nameBytes.firstIndex(of:0) ?? nameBytes.count
				name = String(decoding:nameBytes[0..<terminator], as:UTF8.self)
			}
			records.append(Record(watchDescriptor:watchDescriptor, mask:mask, cookie:cookie, name:name))
			offset += recordSize
		}
		return (records, truncated)
	}
}
