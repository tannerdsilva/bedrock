/*
LICENSE MIT
copyright (c) tanner silva 2026. all rights reserved.

bedrock

*/

/// the numeric values of the inotify event masks as defined by the linux kernel abi.
/// these values are restated here rather than imported from `<sys/inotify.h>` so that the linux event translation and the linux record decoder are compiled on every platform, which is what makes them testable on a machine that is not running linux.
/// - NOTE: the `__cbedrock_pathwatch` shim re-exports these same masks, with their values taken directly from the system header. a linux only test asserts that every value in this enumeration matches the system header exactly, so a drift between this restatement and the kernel abi cannot pass unnoticed.
internal enum InotifyABI {

	/// the watched path was written to.
	internal static let modify:UInt32 = 0x00000002

	/// the metadata of the watched path changed.
	internal static let attrib:UInt32 = 0x00000004

	/// a file that was opened for writing was closed.
	internal static let closeWrite:UInt32 = 0x00000008

	/// an entry was moved out of a watched directory.
	internal static let movedFrom:UInt32 = 0x00000040

	/// an entry was moved into a watched directory.
	internal static let movedTo:UInt32 = 0x00000080

	/// an entry was created in a watched directory.
	internal static let create:UInt32 = 0x00000100

	/// an entry was removed from a watched directory.
	internal static let delete:UInt32 = 0x00000200

	/// the watched path itself was removed.
	internal static let deleteSelf:UInt32 = 0x00000400

	/// the watched path itself was moved.
	internal static let moveSelf:UInt32 = 0x00000800

	/// the filesystem that contains the watched path was unmounted.
	internal static let unmount:UInt32 = 0x00002000

	/// the kernel's event queue overflowed, which means that events were lost.
	internal static let queueOverflow:UInt32 = 0x00004000

	/// the kernel removed the watch.
	internal static let ignored:UInt32 = 0x00008000

	/// the reported entry is a directory.
	internal static let isDirectory:UInt32 = 0x40000000
}
