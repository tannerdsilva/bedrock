import RAW

@RAW_staticbuff(bytes:16)
public struct AddressV6:RAW_comparable_fixed {
	public init?(_ address:String) {
		let segments = address.split(separator: ":", omittingEmptySubsequences: false)
        var bytes = [UInt8]()
        var compressionIndex: Int? = nil

        // Count actual non-empty segments and identify compression
        var actualSegmentCount = 0
        for (index, segment) in segments.enumerated() {
            if segment.isEmpty {
                if compressionIndex == nil {
                    compressionIndex = index
                } else {
                    // Multiple "::" found, which is invalid
                    return nil
                }
            } else {
                actualSegmentCount += 1
            }
        }

        // Calculate the number of segments to be filled with zero
        var segmentsToFill = 8 - actualSegmentCount
        if compressionIndex != nil {
            segmentsToFill += 1 // Include the "::" compression in the count
        }

        // Parse and fill segments
        for (index, segment) in segments.enumerated() {
            if segment.isEmpty {
                if index == compressionIndex { // Fill with zeros if it's the compression index
                    for _ in 0..<segmentsToFill {
                        bytes.append(0)
                        bytes.append(0)
                    }
                }
            } else {
                guard let segmentValue = UInt16(segment, radix: 16) else {
                    return nil // Invalid hexadecimal segment
                }
                bytes.append(UInt8(segmentValue >> 8))
                bytes.append(UInt8(segmentValue & 0xFF))
            }
        }

        // Ensure the total bytes count is exactly 16
        guard bytes.count == 16 else {
            return nil
        }

		self = bytes.RAW_access {
			return Self(RAW_staticbuff:$0.baseAddress!)
		}
	}
}

extension String {
	public init(_ address:AddressV6) {
		self = address.RAW_access_staticbuff({
			let bytes = $0.assumingMemoryBound(to:UInt8.self)
			return String(format:"%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x", bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15])
		})
	}
}