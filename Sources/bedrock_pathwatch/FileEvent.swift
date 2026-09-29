/*
LICENSE MIT
copyright (c) tanner silva 2026. all rights reserved.

bedrock

*/

import bedrock

/// the kinds of filesystem change that a ``PathWatcher`` reports.
/// this is a bitmask because both supported kernels report filesystem changes as a set of flags, and a single change can carry more than one kind at once: a file that is unlinked commonly reports that it was removed and that its link count changed in the same breath.
/// - NOTE: not every kind is deliverable on every platform. consult ``PathWatcher/deliverableKinds`` before writing cross platform code that depends on a specific kind.
public struct FileEventKind:OptionSet, Sendable, Hashable {

	/// the raw value of the bitmask.
	public let rawValue:UInt32

	/// initialize a kind bitmask with the given raw value.
	/// - parameter rawValue: the raw value of the bitmask.
	public init(rawValue:UInt32) {
		self.rawValue = rawValue
	}

	/// the contents of a watched path were written to.
	/// when the watched path is a directory, this kind means that the set of entries in that directory changed. macOS cannot report which entry changed, so a directory change is reported with this kind and no entry name.
	public static let modified:FileEventKind = FileEventKind(rawValue:1 << 0)

	/// the metadata of a watched path changed. this includes ownership, permissions, and link count.
	public static let attributesChanged:FileEventKind = FileEventKind(rawValue:1 << 1)

	/// an entry appeared inside a watched directory. the name of the entry is reported in ``FileEvent/child``.
	public static let appeared:FileEventKind = FileEventKind(rawValue:1 << 2)

	/// an entry left a watched directory. the name of the entry is reported in ``FileEvent/child``.
	public static let disappeared:FileEventKind = FileEventKind(rawValue:1 << 3)

	/// the last writer of a watched file closed it. this is the strongest available signal that a file has finished being written to.
	public static let closedAfterWrite:FileEventKind = FileEventKind(rawValue:1 << 4)

	/// the watched path itself was unlinked. this kind is terminal: the watch is dead once this kind is reported.
	public static let removedSelf:FileEventKind = FileEventKind(rawValue:1 << 5)

	/// the watched path itself was moved or renamed. this kind is terminal: the watch is dead once this kind is reported.
	public static let renamedSelf:FileEventKind = FileEventKind(rawValue:1 << 6)

	/// the watch was ended by the kernel rather than by the watching code. this kind is terminal.
	public static let watchEnded:FileEventKind = FileEventKind(rawValue:1 << 7)

	/// the kinds that end a watch.
	public static let terminal:FileEventKind = [.removedSelf, .renamedSelf, .watchEnded]
}

/// a single filesystem change that was observed by a ``PathWatcher``.
public struct FileEvent:Sendable {

	/// the path that was registered with the watcher. when ``child`` is present, this is the watched directory that contains the entry that changed.
	public let path:Path

	/// the name of the directory entry that changed, when the platform reports it.
	/// - NOTE: only linux reports entry names. this value is always `nil` on macOS, where a change to the contents of a watched directory is reported as ``FileEventKind/modified`` with no entry name attached.
	public let child:String?

	/// the kinds of change that were reported.
	public let kind:FileEventKind

	/// whether the change concerns a directory.
	/// - NOTE: for a change that is reported inside a watched directory on linux, this describes the entry itself. macOS never reports entry level changes, so on macOS this value always describes the watched path.
	public let isDirectory:Bool

	/// the kernel's rename cookie, when the change is one half of a move that the kernel reported as a pair of events.
	/// two events that share a non zero cookie describe one rename: an entry named by ``child`` left the directory that reported ``FileEventKind/disappeared`` and arrived in the directory that reported ``FileEventKind/appeared``.
	/// - NOTE: macOS does not report rename cookies, so this value is always 0 on macOS.
	public let cookie:UInt32

	/// initialize a file event.
	/// - parameter path: the path that was registered with the watcher.
	/// - parameter child: the name of the directory entry that changed, when the platform reports it.
	/// - parameter kind: the kinds of change that were reported.
	/// - parameter isDirectory: whether the change concerns a directory.
	/// - parameter cookie: the kernel's rename cookie, when the change is one half of a reported move.
	public init(path:Path, child:String?, kind:FileEventKind, isDirectory:Bool, cookie:UInt32) {
		self.path = path
		self.child = child
		self.kind = kind
		self.isDirectory = isDirectory
		self.cookie = cookie
	}
}

#if os(macOS)
import Darwin

extension FileEventKind {

	/// the kqueue vnode note flags that request the given kinds from the kernel.
	internal static func macOSNoteFlags(for kinds:FileEventKind) -> UInt32 {
		var flags:UInt32 = 0
		if kinds.contains(.modified) || kinds.contains(.appeared) || kinds.contains(.disappeared) {
			// a directory reports changes to its entries as a write to the directory itself, so the entry level kinds ask for the write note even though macOS is unable to report an entry name.
			flags |= UInt32(NOTE_WRITE)
		}
		if kinds.contains(.modified) {
			flags |= UInt32(NOTE_EXTEND)
		}
		if kinds.contains(.attributesChanged) {
			flags |= UInt32(NOTE_ATTRIB) | UInt32(NOTE_LINK)
		}
		// the terminal notes are always requested, even when the caller did not ask for them: a watch that is unable to report its own death would leak its file descriptor and silently stop working.
		flags |= UInt32(NOTE_DELETE) | UInt32(NOTE_RENAME) | UInt32(NOTE_REVOKE)
		return flags
	}

	/// translates kqueue vnode note flags into the kinds that bedrock reports.
	internal static func from(macOSNoteFlags:UInt32) -> FileEventKind {
		var kinds:FileEventKind = []
		if macOSNoteFlags & (UInt32(NOTE_WRITE) | UInt32(NOTE_EXTEND)) != 0 {
			kinds.insert(.modified)
		}
		if macOSNoteFlags & (UInt32(NOTE_ATTRIB) | UInt32(NOTE_LINK)) != 0 {
			kinds.insert(.attributesChanged)
		}
		if macOSNoteFlags & UInt32(NOTE_DELETE) != 0 {
			kinds.insert(.removedSelf)
		}
		if macOSNoteFlags & UInt32(NOTE_RENAME) != 0 {
			kinds.insert(.renamedSelf)
		}
		if macOSNoteFlags & UInt32(NOTE_REVOKE) != 0 {
			kinds.insert(.watchEnded)
		}
		return kinds
	}

	/// the reason that a watch ended, when the given note flags are what ended it. `nil` means that the watch is still alive.
	internal static func macOSEndReason(noteFlags:UInt32) -> PathWatcherError.Reason? {
		if noteFlags & UInt32(NOTE_DELETE) != 0 {
			return .unlinked
		}
		if noteFlags & UInt32(NOTE_RENAME) != 0 {
			return .renamed
		}
		if noteFlags & UInt32(NOTE_REVOKE) != 0 {
			return .unmounted
		}
		return nil
	}
}
#endif

extension FileEventKind {

	/// the inotify event mask that requests the given kinds from the kernel.
	/// - NOTE: this is deliberately not compiled out on macOS. the linux decoding path is only meaningful when it can be exercised, and keeping the translation in the shared layer is what allows the linux half of this target to be tested on every platform.
	internal static func inotifyMask(for kinds:FileEventKind) -> UInt32 {
		var mask:UInt32 = 0
		if kinds.contains(.modified) {
			mask |= InotifyABI.modify
		}
		if kinds.contains(.attributesChanged) {
			mask |= InotifyABI.attrib
		}
		if kinds.contains(.closedAfterWrite) {
			mask |= InotifyABI.closeWrite
		}
		if kinds.contains(.appeared) {
			mask |= InotifyABI.create | InotifyABI.movedTo
		}
		if kinds.contains(.disappeared) {
			mask |= InotifyABI.delete | InotifyABI.movedFrom
		}
		// the terminal masks are always requested for the same reason as on macOS.
		mask |= InotifyABI.deleteSelf | InotifyABI.moveSelf | InotifyABI.unmount
		return mask
	}

	/// translates an inotify event mask into the kinds that bedrock reports.
	internal static func from(inotifyMask:UInt32) -> FileEventKind {
		var kinds:FileEventKind = []
		if inotifyMask & InotifyABI.modify != 0 {
			kinds.insert(.modified)
		}
		if inotifyMask & InotifyABI.attrib != 0 {
			kinds.insert(.attributesChanged)
		}
		if inotifyMask & InotifyABI.closeWrite != 0 {
			kinds.insert(.closedAfterWrite)
		}
		if inotifyMask & (InotifyABI.create | InotifyABI.movedTo) != 0 {
			kinds.insert(.appeared)
		}
		if inotifyMask & (InotifyABI.delete | InotifyABI.movedFrom) != 0 {
			kinds.insert(.disappeared)
		}
		if inotifyMask & InotifyABI.deleteSelf != 0 {
			kinds.insert(.removedSelf)
		}
		if inotifyMask & InotifyABI.moveSelf != 0 {
			kinds.insert(.renamedSelf)
		}
		if inotifyMask & (InotifyABI.ignored | InotifyABI.unmount | InotifyABI.queueOverflow) != 0 {
			kinds.insert(.watchEnded)
		}
		return kinds
	}

	/// the reason that a watch ended, when the given mask is what ended it. `nil` means that the watch is still alive.
	internal static func inotifyEndReason(mask:UInt32) -> PathWatcherError.Reason? {
		if mask & InotifyABI.deleteSelf != 0 {
			return .unlinked
		}
		if mask & InotifyABI.moveSelf != 0 {
			return .renamed
		}
		if mask & InotifyABI.unmount != 0 {
			return .unmounted
		}
		if mask & InotifyABI.ignored != 0 {
			return .kernelDropped
		}
		return nil
	}
}
