import Logging

#if os(Linux)
import Glibc
#elseif os(macOS)
import Darwin
#endif

/// returns the username that the calling process is running as
public func getCurrentUser() -> String {
	return String(validatingCString:getpwuid(geteuid()).pointee.pw_name)!
}

extension bedrock.Path {
	/// returns the size of any file found at the path represented by the bedrock.Path structure.
	public func getFileSize() -> off_t {
		var statObj = stat()
		guard stat(path(), &statObj) == 0 else {
			return 0
		}
		return statObj.st_size
	}
}
