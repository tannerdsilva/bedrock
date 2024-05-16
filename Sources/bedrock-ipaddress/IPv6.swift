import RAW
import QuickLMDB

@RAW_staticbuff(bytes:16)
@MDB_comparable()
public struct AddressV6:RAW_comparable_fixed, Equatable, Comparable {
	public init?(_ address:String) {
		var bytes = [UInt8](repeating: 0, count: 16)
		let segments = address.split(separator: ":", omittingEmptySubsequences: false)
        var byteIndex = 0
        var foundCompression = false
        
        // Determine where the compression index is (if it exists)
        let compressionIndex = segments.firstIndex(of: "")
        
        for (index, segment) in segments.enumerated() {
            if segment.isEmpty {
                if index == compressionIndex { // handle compression "::"
                    let remainingSegments = 8 - (segments.count - 1)
                    byteIndex += remainingSegments * 2
                    foundCompression = true
                }
            } else {
                guard let segmentValue = UInt16(segment, radix: 16) else {
                    return nil // invalid hexadecimal segment
                }
                bytes[byteIndex] = UInt8(segmentValue >> 8)
                bytes[byteIndex + 1] = UInt8(segmentValue & 0xFF)
                byteIndex += 2
            }
        }
        
        // If no compression was found and byteIndex is not at the end, it's an error
        if byteIndex != 16 && !foundCompression {
            return nil
        }

		self = Self(RAW_staticbuff:&bytes)
	}

	public init?(netmaskPrefix:UInt8) {
		guard netmaskPrefix <= 128 else {
			return nil
		}
		var bytes = [UInt8](repeating:0, count:16)
		let fullBytes = Int(netmaskPrefix / 8)
		let extraBits = Int(netmaskPrefix % 8)
		for i in 0..<fullBytes {
			bytes[i] = 0xFF
		}
		if extraBits > 0 {
			bytes[fullBytes] = 0xFF << (8 - extraBits)
		}
		self = Self(RAW_staticbuff:&bytes)
	}

	public func masked(by netmask:AddressV6) -> AddressV6 {
		return self.RAW_access_staticbuff { addressBytes -> AddressV6 in
			netmask.RAW_access_staticbuff { maskBytes -> AddressV6 in
				let addressPtr = addressBytes.assumingMemoryBound(to:UInt8.self)
				let maskPtr = maskBytes.assumingMemoryBound(to:UInt8.self)
				return withUnsafePointer(to:(addressPtr[0] & maskPtr[0], addressPtr[1] & maskPtr[1], addressPtr[2] & maskPtr[2], addressPtr[3] & maskPtr[3], addressPtr[4] & maskPtr[4], addressPtr[5] & maskPtr[5], addressPtr[6] & maskPtr[6], addressPtr[7] & maskPtr[7], addressPtr[8] & maskPtr[8], addressPtr[9] & maskPtr[9], addressPtr[10] & maskPtr[10], addressPtr[11] & maskPtr[11], addressPtr[12] & maskPtr[12], addressPtr[13] & maskPtr[13], addressPtr[14] & maskPtr[14], addressPtr[15] & maskPtr[15])) {
					return AddressV6(RAW_staticbuff:$0)
				}
			}
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

public typealias RangeV6 = ClosedRange<AddressV6>
extension RangeV6 {
	public init?(_ rangeString:String) {
		let parts = rangeString.split(separator:"-", omittingEmptySubsequences:true).map(String.init)
		guard parts.count == 2, let lower = AddressV6(parts[0]), let upper = AddressV6(parts[1]), lower <= upper else {
			return nil
		}
		self = lower...upper
	}

	public init(address:AddressV6, netmask:AddressV6) {
		var lowerBytes = [UInt8](repeating:0, count:16)
		var upperBytes = [UInt8](repeating:0, count:16)
		withUnsafePointer(to:address) { address in
			withUnsafePointer(to:netmask) { netmask in
				for i in 0..<16 {
					lowerBytes[i] = address.withMemoryRebound(to:UInt8.self, capacity:16) { $0[i] & netmask.withMemoryRebound(to:UInt8.self, capacity:16) { $0[i] } }
					upperBytes[i] = address.withMemoryRebound(to:UInt8.self, capacity:16) { $0[i] | ~netmask.withMemoryRebound(to:UInt8.self, capacity:16) { $0[i] } }
				}
			}
		}
		self = AddressV6(RAW_staticbuff:&lowerBytes)...AddressV6(RAW_staticbuff:&upperBytes)
	}
}


public struct NetworkV6 {
	public let address:AddressV6
	public let prefix:UInt8
	
	public let range:RangeV6
	
	public init?(_ cidr:String) {
		let parts = cidr.split(separator:"/").map(String.init)
		guard parts.count == 2,
			let address = AddressV6(parts[0]),
			let prefix = UInt8(parts[1]),
			prefix <= 128 else {
			return nil
		}
		
		self.address = address
		self.prefix = prefix
		let hasNetmaskPrefix = AddressV6(netmaskPrefix:prefix)
		guard hasNetmaskPrefix != nil else {
			return nil
		}
		self.range = RangeV6(address:address, netmask:hasNetmaskPrefix!)
	}
	
	public func contains(_ address:AddressV6) -> Bool {
		return range.contains(address)
	}
	
	public func overlaps(with network:NetworkV6) -> Bool {
		return range.overlaps(network.range)
	}
}