import cbedrock
import struct Foundation.Data
import protocol Foundation.ContiguousBytes

/// LineParser is a structure that separates a byte stream by a specified pattern.
public class ByteParser {
	internal var isClosed:Bool = false
	internal var lineparser:lineparser_t

	/// Initialize a line parser with a specified separator pattern.
	/// Parameters:
	/// - separator: The pattern to separate the byte stream by.
	public init<B>(separator:B) throws where B:ContiguousBytes {
		self.lineparser = separator.withUnsafeBytes { sepBytes in
			return lp_init(sepBytes.baseAddress!.bindMemory(to:UInt8.self, capacity:sepBytes.count), UInt8(sepBytes.count))
		}
	}

	/// Feed a byte stream into the parser.
	/// Returns: An array of Data objects, each containing a separated element of the byte stream.
	public func intake<B>(_ data:B) -> [Data] where B:ContiguousBytes {
		data.withUnsafeBytes { dataBytes in
			var buildLines = [Data]()
			lp_intake(&self.lineparser, dataBytes.baseAddress!.bindMemory(to:UInt8.self, capacity:dataBytes.count), dataBytes.count, { (data, length) in
				let newData = Data(bytes:data, count:length)
				buildLines.append(newData)
			})
			return buildLines
		}
	}

	/// Finish the parsing and return any remaining data.
	/// Returns: An array of Data objects, each containing a separated element of the byte stream.
	public func finish() -> [Data] {
		var buildLines = [Data]()
		lp_close(&self.lineparser, { (data, length) in
			let newData = Data(bytes:data, count:length)
			buildLines.append(newData)
		})
		isClosed = true
		return buildLines
	}

	deinit {
		if isClosed == false {
			lp_close_dataloss(&self.lineparser)
		}
	}
}