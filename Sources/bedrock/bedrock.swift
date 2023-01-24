import Logging
import Foundation


/// builds a logger with a label and pre-configured log level based on the build mode of the codebase
public func makeDefaultLogger(label:String) -> Logger {
	var makeLogger = Logger(label:label)
	#if DEBUG
		makeLogger.logLevel = .debug
	#else
		makeLogger.logLevel = .warning
	#endif
	return makeLogger
}

/// returns the username that the calling process is running as
public func getCurrentUser() -> String {
	return String(validatingUTF8:getpwuid(geteuid()).pointee.pw_name)!
}


