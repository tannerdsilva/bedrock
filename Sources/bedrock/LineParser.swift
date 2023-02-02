import cbedrock
import Foundation

/// ByteParser is a structure that separates a byte stream by a specified pattern.
//public class ByteParser {
//	enum Error:Swift.Error {
//		case invalidPatternLength
//	}
//	public var pattern:Data
//	internal var lineparser:lineparser_t?
//	
//	init(pattern:Data) throws {
//		guard pattern.count > 0 else {
//			throw Error.invalidPatternLength
//		}
//		self.pattern = pattern
//		self.lineparser = mutableCopy.withUnsafeMutableBytes({ patternIn in
//			return lp_init(patternIn.baseAddress!.bindMemory(to:UInt8.self, capacity:pattern.count), UInt8(pattern.count))
//		})
//	}
//	
//	public func resetBuffers() {
//		self.lineparser
//		
//	}
//}