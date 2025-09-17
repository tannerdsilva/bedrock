import RAW
import __cbedrock_ip

@RAW_staticbuff(bytes:16)
@RAW_staticbuff_fixedwidthinteger_type<UInt128>(bigEndian:true)
public struct AddressV6:RAW_comparable_fixed, Equatable, Comparable, Hashable, Sendable {
	public typealias RAW_fixed_type = RAW_staticbuff_storetype
	public init?(_ address:String) {
		var addressv6BE = in6_addr()
		guard inet_pton(AF_INET6, address, &addressv6BE) == 1 else {
			return nil
		}
		#if os(Linux)
		self = .init(RAW_staticbuff:&addressv6BE.__in6_u.__u6_addr8)
		#elseif os(macOS)
		self = .init(RAW_staticbuff:&addressv6BE.__u6_addr.__u6_addr8)
		#endif
	}

	public init?(subnetPrefix netmaskPrefix: UInt8) {
		guard netmaskPrefix <= 128 else {
			return nil
		}

		// this logic could be done with a lot less code but it would require initializing and writing to bytes multiple times, whereas this way we only write to bytes once*
		var sixteenBytes:RAW_staticbuff_storetype
		let fullBytes = Int(netmaskPrefix / 8)
		switch fullBytes {
			case 15: sixteenBytes = (0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0)
			case 14: sixteenBytes = (0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0, 0)
			case 13: sixteenBytes = (0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0, 0, 0)
			case 12: sixteenBytes = (0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0, 0, 0, 0)
			case 11: sixteenBytes = (0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0, 0, 0, 0, 0)
			case 10: sixteenBytes = (0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0, 0, 0, 0, 0, 0)
			case 9: sixteenBytes = (0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0, 0, 0, 0, 0, 0, 0)
			case 8: sixteenBytes = (0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0)
			case 7: sixteenBytes = (0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0, 0)
			case 6: sixteenBytes = (0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
			case 5: sixteenBytes = (0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
			case 4: sixteenBytes = (0xFF, 0xFF, 0xFF, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
			case 3: sixteenBytes = (0xFF, 0xFF, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
			case 2: sixteenBytes = (0xFF, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
			case 1: sixteenBytes = (0xFF, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
			case 0: sixteenBytes = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
			default: fatalError() // should never happen with the guard above
		}

		let extraBits = Int(netmaskPrefix % 8)
		if extraBits > 0 {
			let mask = (0xFF << (8 - extraBits)) & 0xFF
			switch fullBytes {
				case 0: sixteenBytes.0 = UInt8(mask)
				case 1: sixteenBytes.1 = UInt8(mask)
				case 2: sixteenBytes.2 = UInt8(mask)
				case 3: sixteenBytes.3 = UInt8(mask)
				case 4: sixteenBytes.4 = UInt8(mask)
				case 5: sixteenBytes.5 = UInt8(mask)
				case 6: sixteenBytes.6 = UInt8(mask)
				case 7: sixteenBytes.7 = UInt8(mask)
				case 8: sixteenBytes.8 = UInt8(mask)
				case 9: sixteenBytes.9 = UInt8(mask)
				case 10: sixteenBytes.10 = UInt8(mask)
				case 11: sixteenBytes.11 = UInt8(mask)
				case 12: sixteenBytes.12 = UInt8(mask)
				case 13: sixteenBytes.13 = UInt8(mask)
				case 14: sixteenBytes.14 = UInt8(mask)
				case 15: sixteenBytes.15 = UInt8(mask)
				default: fatalError() // should never happen with the guard above and the switch above
			}
		}

		self = Self(RAW_staticbuff:sixteenBytes)
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
			return AddressV6(RAW_staticbuff:(~bytes[0], ~bytes[1], ~bytes[2], ~bytes[3], ~bytes[4], ~bytes[5], ~bytes[6], ~bytes[7], ~bytes[8], ~bytes[9], ~bytes[10], ~bytes[11], ~bytes[12], ~bytes[13], ~bytes[14], ~bytes[15]))
		}
	}

	public static func | (lhs:AddressV6, rhs:AddressV6) -> AddressV6 {
		return lhs.RAW_access_staticbuff { lhsPtr -> AddressV6 in
			return rhs.RAW_access_staticbuff { rhsPtr -> AddressV6 in
				let lhsBytes = lhsPtr.assumingMemoryBound(to:UInt8.self)
				let rhsBytes = rhsPtr.assumingMemoryBound(to:UInt8.self)
				return AddressV6(RAW_staticbuff:(lhsBytes[0] | rhsBytes[0], lhsBytes[1] | rhsBytes[1], lhsBytes[2] | rhsBytes[2], lhsBytes[3] | rhsBytes[3], lhsBytes[4] | rhsBytes[4], lhsBytes[5] | rhsBytes[5], lhsBytes[6] | rhsBytes[6], lhsBytes[7] | rhsBytes[7], lhsBytes[8] | rhsBytes[8], lhsBytes[9] | rhsBytes[9], lhsBytes[10] | rhsBytes[10], lhsBytes[11] | rhsBytes[11], lhsBytes[12] | rhsBytes[12], lhsBytes[13] | rhsBytes[13], lhsBytes[14] | rhsBytes[14], lhsBytes[15] | rhsBytes[15]))
			}
		}
	}
}

extension AddressV6:CustomDebugStringConvertible, Codable {
	public var debugDescription:String {
		return "AddressV6(\"\(String(self))\")"
	}

	public init(from decoder:Decoder) throws {
		let container = try decoder.singleValueContainer()
		let address = try container.decode(String.self)
		guard let addressv6 = AddressV6(address) else {
			throw DecodingError.dataCorruptedError(in:container, debugDescription:"invalid IPv6 address")
		}
		self = addressv6
	}
	
	public func encode(to encoder:Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(String(self))
	}
}


extension String {
	public init(_ address:AddressV6) {
		self = address.RAW_access_staticbuff({
			var transactable = in6_addr()
			#if os(Linux)
			transactable.__in6_u.__u6_addr8 = $0.assumingMemoryBound(to:AddressV6.RAW_staticbuff_storetype.self).pointee
			#elseif os(macOS)
			transactable.__u6_addr.__u6_addr8 = $0.assumingMemoryBound(to:AddressV6.RAW_staticbuff_storetype.self).pointee
			#endif
			let stringBuffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity:Int(INET6_ADDRSTRLEN))
			defer {
				stringBuffer.deallocate()
			}
			guard inet_ntop(AF_INET6, &transactable, stringBuffer.baseAddress, UInt32(INET6_ADDRSTRLEN)) != nil else {
				fatalError("ipv6 address could not be string encoded")
			}
			return String(cString:stringBuffer.baseAddress!)
		})
	}
}

public typealias sockaddr_in6 = __cbedrock_ip.sockaddr_in6
extension AddressV6 {
	public func sockaddr_in6(port:UInt16) -> sockaddr_in6 {
		var newIn = bedrock_ip.sockaddr_in6()
		newIn.sin6_family = sa_family_t(AF_INET6)
		newIn.sin6_port = port.bigEndian
		newIn.sin6_flowinfo = 0
		newIn.sin6_scope_id = 0
		newIn.sin6_addr = RAW_access_staticbuff {
			return $0.assumingMemoryBound(to:in6_addr.self).pointee
		}
		return newIn
	}
}

@RAW_staticbuff(concat:AddressV6.self, AddressV6.self)
public struct RangeV6:RAW_comparable_fixed, Equatable, Comparable, Hashable, Sendable {
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

extension RangeV6:CustomDebugStringConvertible {
	public var debugDescription:String {
		return "RangeV6(\"\(String(lowerBound))-\(String(upperBound))\")"
	}
}

@RAW_staticbuff(concat:AddressV6.self, RAW_byte.self)
public struct NetworkV6:RAW_comparable_fixed, Equatable, Comparable, Hashable, Sendable, LosslessStringConvertible {
	public var description:String {
		return "\(String(address))/\(subnetPrefix)"
	}
	
	public typealias RAW_fixed_type = RAW_staticbuff_storetype

	public let address:AddressV6
	fileprivate let _subnet_prefix:RAW_byte
	
	public var subnetPrefix:UInt8 {
		get {
			return _subnet_prefix.RAW_native()
		}
	}
	
	public var subnetMask:AddressV6 {
		get {
			return AddressV6(subnetPrefix:_subnet_prefix.RAW_native())!
		}
	}
	
	public var range:RangeV6 {
		get {
			return RangeV6(address:address, netmask:AddressV6(subnetPrefix:_subnet_prefix.RAW_native())!)
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
		guard AddressV6(subnetPrefix:prefix) != nil else {
			return nil
		}
	}
	
	public func contains(_ address:AddressV6) -> Bool {
		return range.contains(address)
	}
	
	public func overlaps(with network:NetworkV6) -> Bool {
		return range.overlaps(network.range)
	}

	public static func RAW_compare(lhs_data:UnsafeRawPointer, rhs_data:UnsafeRawPointer) -> Int32 {
		// mask off any unnecessary bits in the address before comparing

		let boundLHS = lhs_data.assumingMemoryBound(to:Self.self)
		let boundRHS = rhs_data.assumingMemoryBound(to:Self.self)

		return withUnsafePointer(to:(boundLHS.pointer(to: \.address)!.pointee & boundLHS.pointer(to: \.subnetMask)!.pointee)) { lhsMasked in
			return withUnsafePointer(to:(boundRHS.pointer(to: \.address)!.pointee & boundRHS.pointer(to: \.subnetMask)!.pointee)) { rhsMasked in
				
				// lhs and rhs are now masked to the same subnet, compare them.

				let cmpResult = AddressV6.RAW_compare(lhs_data:lhsMasked, rhs_data:rhsMasked)
				switch cmpResult {
					case 0:
						// matching masked addresses, compare subnet prefixes
						return Int32(boundLHS.pointer(to: \.subnetPrefix)!.pointee) - Int32(boundRHS.pointer(to: \.subnetPrefix)!.pointee)
					default:
						return Int32(cmpResult)
				}
			}
		}
	}
}

extension NetworkV6:CustomDebugStringConvertible, Codable {
	public var debugDescription:String {
		return "NetworkV6(\"\(String(address))/\(subnetPrefix)\")"
	}

	public init(from decoder:Decoder) throws {
		let container = try decoder.singleValueContainer()
		let cidr = try container.decode(String.self)
		guard let network = NetworkV6(cidr) else {
			throw DecodingError.dataCorruptedError(in:container, debugDescription:"invalid IPv6 CIDR string")
		}
		self = network
	}
	public func encode(to encoder:Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode("\(address)/\(subnetPrefix)")
	}
}
