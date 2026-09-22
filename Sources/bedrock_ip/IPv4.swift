import RAW
import __cbedrock_ip

@RAW_staticbuff(bytes:4)
@RAW_staticbuff_fixedwidthinteger_type<UInt32>(bigEndian:true)
public struct AddressV4:RAW_comparable_fixed, Equatable, Comparable, Hashable, Sendable {
	public init?(_ address:consuming String) {
		var addressv4BE = in_addr()
		guard inet_pton(AF_INET, address, &addressv4BE) == 1 else {
			return nil
		}
		let storage = withUnsafeBytes(of:&addressv4BE.s_addr) {
			$0.load(as:RAW_fixed_type.self)
		}
		self = .init(RAW_staticbuff:storage)
	}

	public init?(subnetPrefix netmaskPrefix:UInt8) {
		guard netmaskPrefix <= 32 else {
			return nil
		}
		var fourBytes:RAW_fixed_type = (0, 0, 0, 0)
		let fullByteCount = Int(netmaskPrefix / 8)
		switch fullByteCount {
			case 1:
				fourBytes.0 = 0xFF
			case 2:
				fourBytes = (0xFF, 0xFF, 0, 0)
			case 3:
				fourBytes = (0xFF, 0xFF, 0xFF, 0)
			case 4:
				fourBytes = (0xFF, 0xFF, 0xFF, 0xFF)
			default:
				break
			}
		let extraBits = Int(netmaskPrefix % 8)
		if extraBits > 0 {
			let mask = (0xFF << (8 - extraBits)) & 0xFF
			switch fullByteCount {
				case 0:
					fourBytes.0 = UInt8(mask)
				case 1:
					fourBytes.1 = UInt8(mask)
				case 2:
					fourBytes.2 = UInt8(mask)
				case 3:
					fourBytes.3 = UInt8(mask)
				default:
					break
			}
		}
		self.init(RAW_staticbuff:fourBytes)
	}

	public static func & (lhs:AddressV4, rhs:AddressV4) -> AddressV4 {
		return lhs.RAW_access_immutable { lhsBytes -> AddressV4 in
			return rhs.RAW_access_immutable { rhsBytes -> AddressV4 in
				return AddressV4(RAW_staticbuff:(lhsBytes[0] & rhsBytes[0], lhsBytes[1] & rhsBytes[1], lhsBytes[2] & rhsBytes[2], lhsBytes[3] & rhsBytes[3]))
			}
		}
	}

	public static prefix func ~ (_ address:AddressV4) -> AddressV4 {
		return address.RAW_access_immutable { bytes in
			return AddressV4(RAW_staticbuff:(~bytes[0], ~bytes[1], ~bytes[2], ~bytes[3]))
		}
	}

	public static func | (lhs:AddressV4, rhs:AddressV4) -> AddressV4 {
		return lhs.RAW_access_immutable{ lhsBytes -> AddressV4 in
			return rhs.RAW_access_immutable { rhsBytes -> AddressV4 in
				return AddressV4(RAW_staticbuff:(lhsBytes[0] | rhsBytes[0], lhsBytes[1] | rhsBytes[1], lhsBytes[2] | rhsBytes[2], lhsBytes[3] | rhsBytes[3]))
			}
		}
	}
}

extension AddressV4:CustomDebugStringConvertible, Codable {
	public var debugDescription:String {
		return "AddressV4(\(String(self))"
	}
	public init(from decoder:Decoder) throws {
		let container = try decoder.singleValueContainer()
		let addressString = try container.decode(String.self)
		guard let address = AddressV4(addressString) else {
			throw DecodingError.dataCorruptedError(in:container, debugDescription:"Invalid IPv4 address")
		}
		self = address
	}
	public func encode(to encoder:Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(String(self))
	}
}


extension String {
	public init(_ address:AddressV4) {
		self = address.RAW_access_immutable { bytes in
			let ptr = UnsafeRawPointer(bytes.baseAddress!).assumingMemoryBound(to:AddressV4.RAW_fixed_type.self)
			return "\(ptr.pointee.0).\(ptr.pointee.1).\(ptr.pointee.2).\(ptr.pointee.3)"
		}
	}
}

public typealias sockaddr_in = __cbedrock_ip.sockaddr_in
extension AddressV4 {
	public func sockaddr_in(port:UInt16) -> sockaddr_in {
		var newIn = bedrock_ip.sockaddr_in()
		newIn.sin_family = sa_family_t(AF_INET)
		newIn.sin_port = port.bigEndian
		newIn.sin_addr = RAW_access_immutable { bytes in
			return UnsafeRawPointer(bytes.baseAddress!).assumingMemoryBound(to:in_addr.self).pointee
		}
		return newIn
	}
}


@RAW_staticbuff(concat:AddressV4.self, AddressV4.self)
public struct RangeV4:RAW_comparable_fixed, Equatable, Comparable, Hashable, Sendable {
	public let lowerBound:AddressV4
	public let upperBound:AddressV4
	public init(lower:AddressV4, upper:AddressV4) {
		self.lowerBound = lower
		self.upperBound = upper
	}
	
	public init(address:AddressV4, netmask:AddressV4) {
		var lowerBytes = [UInt8](repeating:0, count:4)
		var upperBytes = [UInt8](repeating:0, count:4)
		withUnsafePointer(to:address) { address in
			withUnsafePointer(to:netmask) { netmask in
				for i in 0..<4 {
					lowerBytes[i] = address.withMemoryRebound(to:UInt8.self, capacity:4) { $0[i] & netmask.withMemoryRebound(to:UInt8.self, capacity:4) { $0[i] } }
					upperBytes[i] = address.withMemoryRebound(to:UInt8.self, capacity:4) { $0[i] | ~netmask.withMemoryRebound(to:UInt8.self, capacity:4) { $0[i] } }
				}
			}
		}
		let lowerStorage = lowerBytes.withUnsafeBytes { $0.load(as:AddressV4.RAW_fixed_type.self) }
		let upperStorage = upperBytes.withUnsafeBytes { $0.load(as:AddressV4.RAW_fixed_type.self) }
		self = Self(lower:AddressV4(RAW_staticbuff:lowerStorage), upper:AddressV4(RAW_staticbuff:upperStorage))
	}
	
	public init?(_ rangeString:String) {
		let parts = rangeString.split(separator:"-", omittingEmptySubsequences:true).map(String.init)
		guard parts.count == 2, let lower = AddressV4(parts[0]), let upper = AddressV4(parts[1]), lower <= upper else {
			return nil
		}
		self.init(lower:lower, upper:upper)
	}

	public func contains(_ address:AddressV4) -> Bool {
		return lowerBound <= address && address <= upperBound
	}

	public func overlaps(_ range:RangeV4) -> Bool {
		return contains(range.lowerBound) || contains(range.upperBound)
	}
}

extension RangeV4:CustomDebugStringConvertible {
	public var debugDescription:String {
		return "RangeV4(\(String(lowerBound))-\(String(upperBound)))"
	}
}

@RAW_staticbuff(concat:AddressV4.self, RAW_byte.self)
public struct NetworkV4:RAW_comparable_fixed, Equatable, Comparable, Hashable, Sendable, LosslessStringConvertible {
	public var description:String {
		return "\(String(address))/\(subnetPrefix)"
	}
	
	public let address:AddressV4
	fileprivate let _subnet_prefix:RAW_byte
	public var subnetPrefix:UInt8 {
		get {
			return _subnet_prefix.RAW_native()
		}
	}

	public var subnetMask:AddressV4 {
		get {
			return AddressV4(subnetPrefix:_subnet_prefix.RAW_native())!
		}
	}
	
	public var range:RangeV4 {
		get {
			return RangeV4(address:address, netmask:AddressV4(subnetPrefix:_subnet_prefix.RAW_native())!)
		}
	}
	
	public init(address:AddressV4, subnetPrefix:UInt8) {
		self.address = address
		self._subnet_prefix = RAW_byte(RAW_native:subnetPrefix)
	}
	
	public init?(_ cidr:String) {
		let parts = cidr.split(separator:"/")
		guard parts.count == 2,
			let address = AddressV4(String(parts[0])),
			let prefix = UInt8(String(parts[1])),
			prefix <= 32 else {
			return nil
		}
		
		self.address = address
		self._subnet_prefix = RAW_byte(RAW_native:prefix)
		let hasNetmaskPrefix = AddressV4(subnetPrefix:prefix)
		guard hasNetmaskPrefix != nil else {
			return nil
		}
	}
	
	public func contains(_ address:AddressV4) -> Bool {
		return range.contains(address)
	}
	
	public func overlaps(with network:NetworkV4) -> Bool {
		return range.overlaps(network.range)
	}

		public static func RAW_compare(lhs_data:UnsafeRawPointer, rhs_data:UnsafeRawPointer) -> Int32 {
		// mask off any unnecessary bits in the address before comparing
		let boundLHS = lhs_data.assumingMemoryBound(to:Self.self)
		let boundRHS = rhs_data.assumingMemoryBound(to:Self.self)

		let lhsMasked = boundLHS.pointee.address & boundLHS.pointee.subnetMask
		let rhsMasked = boundRHS.pointee.address & boundRHS.pointee.subnetMask
		return withUnsafePointer(to:lhsMasked) { lhsMaskedPtr in
			return withUnsafePointer(to:rhsMasked) { rhsMaskedPtr in
				let cmpResult = AddressV4.RAW_compare(lhs_data:UnsafeRawPointer(lhsMaskedPtr), rhs_data:UnsafeRawPointer(rhsMaskedPtr))
				switch cmpResult {
					case 0:
						// matching masked addresses, compare subnet prefixes
						return Int32(boundLHS.pointee.subnetPrefix) - Int32(boundRHS.pointee.subnetPrefix)
					default:
						return Int32(cmpResult)
				}
			}
		}
	}
}
extension NetworkV4:CustomDebugStringConvertible, Codable {
	public var debugDescription:String {
		return "NetworkV4(\(String(address))/\(subnetPrefix))"
	}
	public init(from decoder:Decoder) throws {
		let container = try decoder.singleValueContainer()
		let cidr = try container.decode(String.self)
		guard let network = NetworkV4(cidr) else {
			throw DecodingError.dataCorruptedError(in:container, debugDescription:"Invalid IPv4 network")
		}
		self = network
	}
	public func encode(to encoder:Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode("\(address)/\(subnetPrefix)")
	}
}
