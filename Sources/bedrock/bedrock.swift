import Logging

#if os(Linux)
import Glibc
#elseif os(macOS)
import Darwin
#endif

/// builds a logger with a label and pre-configured log level based on the build mode of the codebase
public func makeDefaultLogger(label:consuming String, logLevel:consuming Logger.Level) -> Logger {
	var makeLogger = Logger(label:label)
	makeLogger.logLevel = logLevel
	return makeLogger
}

/// returns the username that the calling process is running as
public func getCurrentUser() -> String {
	return String(validatingUTF8:getpwuid(geteuid()).pointee.pw_name)!
}


