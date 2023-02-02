import ArgumentParser
import Logging

// Enables log levels to be directly specified and translated from command line arguments
extension Logging.Logger.Level:ExpressibleByArgument {
	/// Initialize a Log Level enum from a command line argument
	public init?(argument:String) {
		switch argument.lowercased() {
			case "critical":
			self = .critical
			case "error":
			self = .error
			case "warning":
			self = .warning
			case "notice":
			self = .notice
			case "info":
			self = .info
			case "debug":
			self = .debug
			case "trace":
			self = .trace
			default:
			return nil
		}
	}
	
	/// All possible command-line values for this type
	public static let allValueStrings = ["critical", "error", "warning", "notice", "info", "debug", "trace"]
	
	/// Completion values for this type
	public static let defaultCompletionKind = CompletionKind.list(Self.allValueStrings)
}
