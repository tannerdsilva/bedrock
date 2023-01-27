import ArgumentParser
import Logging

extension Logging.Logger.Level:ExpressibleByArgument {
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
	
	public static var allValueStrings = ["critical", "error", "warning", "notice", "info", "debug", "trace"]
}
