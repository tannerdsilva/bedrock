import RAW
import QuickLMDB

#if os(Linux)
import Glibc
#elseif os(macOS)
import Darwin
#endif

@RAW_staticbuff(bytes:16)
@MDB_comparable()
public struct AddressV6:RAW_comparable_fixed, Equatable, Comparable, Hashable {
	public typealias RAW_fixed_type = RAW_staticbuff_storetype

	public init?(_ address:String) {
		var initialBytes:RAW_staticbuff_storetype = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
		var byteIndex = 0
		let segments = address.split(separator:":", omittingEmptySubsequences:false)
		var foundCompression = false
		withUnsafeMutablePointer(to:&initialBytes) { ptr in
			let bytes = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to:UInt8.self)
			
			let compressionIndex = segments.firstIndex(of:"")
			
			for (index, segment) in segments.enumerated() {
				if segment.isEmpty {
					if index == compressionIndex { // handle compression "::"
						let remainingSegments = 8 - (segments.count - 1)
						byteIndex += remainingSegments * 2
						foundCompression = true
					}
				} else {
					let segmentValue = UInt16(segment, radix: 16)
					guard segmentValue != nil else {
						return
					}
					bytes[byteIndex] = UInt8(segmentValue! >> 8)
					bytes[byteIndex + 1] = UInt8(segmentValue! & 0xFF)
					byteIndex += 2
				}
			}
		}
		if byteIndex != 16 && !foundCompression {
			return nil
		}
		self = Self(RAW_staticbuff:&initialBytes)
	}

	public init?(netmaskPrefix:UInt8) {
		// sixteen byte tuple initialized to 0xFF for each byte
		var sixteenBytes:RAW_staticbuff_storetype = (0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF)
		let fullBytes = Int(netmaskPrefix / 8)
		let extraBits = Int(netmaskPrefix % 8)
		switch fullBytes {
			case 15: sixteenBytes.15 = 0xFF << (8 - extraBits)
			case 14: sixteenBytes.14 = 0xFF << (8 - extraBits)
			case 13: sixteenBytes.13 = 0xFF << (8 - extraBits)
			case 12: sixteenBytes.12 = 0xFF << (8 - extraBits)
			case 11: sixteenBytes.11 = 0xFF << (8 - extraBits)
			case 10: sixteenBytes.10 = 0xFF << (8 - extraBits)
			case 9: sixteenBytes.9 = 0xFF << (8 - extraBits)
			case 8: sixteenBytes.8 = 0xFF << (8 - extraBits)
			case 7: sixteenBytes.7 = 0xFF << (8 - extraBits)
			case 6: sixteenBytes.6 = 0xFF << (8 - extraBits)
			case 5: sixteenBytes.5 = 0xFF << (8 - extraBits)
			case 4: sixteenBytes.4 = 0xFF << (8 - extraBits)
			case 3: sixteenBytes.3 = 0xFF << (8 - extraBits)
			case 2: sixteenBytes.2 = 0xFF << (8 - extraBits)
			case 1: sixteenBytes.1 = 0xFF << (8 - extraBits)
			case 0: sixteenBytes.0 = 0xFF << (8 - extraBits)
			default: return nil
		}
		self = Self(RAW_staticbuff:&sixteenBytes)
	}

	public static func & (lhs:AddressV6, rhs:AddressV6) -> AddressV6 {
		return lhs.RAW_access_staticbuff { lhsPtr -> AddressV6 in
			return rhs.RAW_access_staticbuff { rhsPtr -> AddressV6 in
				let lhsBytes = lhsPtr.assumingMemoryBound(to:UInt8.self)
				let rhsBytes = rhsPtr.assumingMemoryBound(to:UInt8.self)
				return withUnsafePointer(to:(lhsBytes[0] & rhsBytes[0], lhsBytes[1] & rhsBytes[1], lhsBytes[2] & rhsBytes[2], lhsBytes[3] & rhsBytes[3], lhsBytes[4] & rhsBytes[4], lhsBytes[5] & rhsBytes[5], lhsBytes[6] & rhsBytes[6], lhsBytes[7] & rhsBytes[7], lhsBytes[8] & rhsBytes[8], lhsBytes[9] & rhsBytes[9], lhsBytes[10] & rhsBytes[10], lhsBytes[11] & rhsBytes[11], lhsBytes[12] & rhsBytes[12], lhsBytes[13] & rhsBytes[13], lhsBytes[14] & rhsBytes[14], lhsBytes[15] & rhsBytes[15])) { (ptr:UnsafePointer<AddressV6.RAW_staticbuff_storetype>) in
					return AddressV6(RAW_staticbuff:ptr)
				}
			}
		}
	}

	public static prefix func ~ (_ address:AddressV6) -> AddressV6 {
		return address.RAW_access_staticbuff { ptr in
			let bytes = ptr.assumingMemoryBound(to:UInt8.self)
			return withUnsafePointer(to:(~bytes[0], ~bytes[1], ~bytes[2], ~bytes[3], ~bytes[4], ~bytes[5], ~bytes[6], ~bytes[7], ~bytes[8], ~bytes[9], ~bytes[10], ~bytes[11], ~bytes[12], ~bytes[13], ~bytes[14], ~bytes[15])) { (ptr:UnsafePointer<AddressV6.RAW_staticbuff_storetype>) in
				return AddressV6(RAW_staticbuff:ptr)
			}
		}
	}

	public static func | (lhs:AddressV6, rhs:AddressV6) -> AddressV6 {
		return lhs.RAW_access_staticbuff { lhsPtr -> AddressV6 in
			return rhs.RAW_access_staticbuff { rhsPtr -> AddressV6 in
				let lhsBytes = lhsPtr.assumingMemoryBound(to:UInt8.self)
				let rhsBytes = rhsPtr.assumingMemoryBound(to:UInt8.self)
				return withUnsafePointer(to:(lhsBytes[0] | rhsBytes[0], lhsBytes[1] | rhsBytes[1], lhsBytes[2] | rhsBytes[2], lhsBytes[3] | rhsBytes[3], lhsBytes[4] | rhsBytes[4], lhsBytes[5] | rhsBytes[5], lhsBytes[6] | rhsBytes[6], lhsBytes[7] | rhsBytes[7], lhsBytes[8] | rhsBytes[8], lhsBytes[9] | rhsBytes[9], lhsBytes[10] | rhsBytes[10], lhsBytes[11] | rhsBytes[11], lhsBytes[12] | rhsBytes[12], lhsBytes[13] | rhsBytes[13], lhsBytes[14] | rhsBytes[14], lhsBytes[15] | rhsBytes[15])) { (ptr:UnsafePointer<AddressV6.RAW_staticbuff_storetype>) in
					return AddressV6(RAW_staticbuff:ptr)
				}
			}
		}
	}
}


extension String {
	public init(_ address:AddressV6) {
		self = address.RAW_access_staticbuff({
			let bytes = $0.assumingMemoryBound(to:UInt8.self)
			let stringBuffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity:40)
			guard inet_ntop(AF_INET6, bytes, stringBuffer.baseAddress, 40) != nil else {
				fatalError("ipv6 address could not be string encoded")
			}
			return String(cString:stringBuffer.baseAddress!)
		})
	}
}

@RAW_staticbuff(concat:AddressV6, AddressV6)
public struct RangeV6:RAW_comparable_fixed, Equatable, Comparable, Hashable {
	public typealias RAW_fixed_type = RAW_staticbuff_storetype

	public let lowerBound:AddressV6
	public let upperBound:AddressV6
	public init(lower:AddressV6, upper:AddressV6) {
		self.lowerBound = lower
		self.upperBound = upper
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
		self = Self(lower:AddressV6(RAW_staticbuff:&lowerBytes), upper:AddressV6(RAW_staticbuff:&upperBytes))
	}
	
	public init?(_ rangeString:String) {
		let parts = rangeString.split(separator:"-", omittingEmptySubsequences:true).map(String.init)
		guard parts.count == 2, let lower = AddressV6(parts[0]), let upper = AddressV6(parts[1]), lower <= upper else {
			return nil
		}
		self.init(lower:lower, upper:upper)
	}

	public func contains(_ address:AddressV6) -> Bool {
		return lowerBound <= address && address <= upperBound
	}

	public func overlaps(_ range:RangeV6) -> Bool {
		return contains(range.lowerBound) || contains(range.upperBound)
	}
}

@RAW_staticbuff(concat:AddressV6, RAW_byte)
@MDB_comparable()
public struct NetworkV6:RAW_comparable_fixed, Equatable, Comparable, Hashable {
	public typealias RAW_fixed_type = RAW_staticbuff_storetype

	public let address:AddressV6
	fileprivate let _subnet_prefix:RAW_byte
	public var subnet_prefix:UInt8 {
		get {
			return _subnet_prefix.RAW_native()
		}
	}
	
	public var range:RangeV6 {
		get {
			return RangeV6(address:address, netmask:AddressV6(netmaskPrefix:_subnet_prefix.RAW_native())!)
		}
	}
	
	public init(address:AddressV6, subnetPrefix:UInt8) {
		self.address = address
		self._subnet_prefix = RAW_byte(RAW_native:subnetPrefix)
	}
	
	public init?(_ cidr:String) {
		let parts = cidr.split(separator:"/").map(String.init)
		guard parts.count == 2,
			let address = AddressV6(parts[0]),
			let prefix = UInt8(parts[1]),
			prefix <= 128 else {
			return nil
		}
		
		self.address = address
		self._subnet_prefix = RAW_byte(RAW_native:prefix)
		guard AddressV6(netmaskPrefix:prefix) != nil else {
			return nil
		}
	}
	
	public func contains(_ address:AddressV6) -> Bool {
		return range.contains(address)
	}
	
	public func overlaps(with network:NetworkV6) -> Bool {
		return range.overlaps(network.range)
	}
}