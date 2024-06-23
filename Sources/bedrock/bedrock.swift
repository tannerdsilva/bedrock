import Logging

#if os(Linux)
import Glibc
#elseif os(macOS)
import Darwin
#endif

/// returns the username that the calling process is running as
public func getCurrentUser() -> String {
	return String(validatingUTF8:getpwuid(geteuid()).pointee.pw_name)!
}
