import RAW
import QuickLMDB

@RAW_staticbuff(bytes:4)
@MDB_comparable()
public struct AddressV4:RAW_comparable_fixed, Equatable, Comparable, Hashable {
	public typealias RAW_fixed_type = RAW_staticbuff_storetype

	public init?(_ address:String) {
		let parts = address.split(separator:".")
		guard parts.count == 4 else {
			return nil
		}
		var octets = [UInt8]()
		for part in parts {
			guard let asInt = UInt8(part) else {
				return nil
			}
			octets.append(asInt)
		}
		guard octets.count == 4 else {
			return nil
		}
		self = octets.RAW_access {
			return Self(RAW_staticbuff:$0.baseAddress!)
		}
	}

	public init?(netmaskPrefix:UInt8) {
		guard netmaskPrefix <= 32 else {
			return nil
		}
		var fourBytes:(UInt8, UInt8, UInt8, UInt8) = (0xFF, 0xFF, 0xFF, 0xFF)
		let extraBits = Int(netmaskPrefix % 8)
		if extraBits > 0 {
			switch Int(netmaskPrefix / 8) {
				case 0:
					fourBytes.0 = 0xFF << (8 - extraBits)
				case 1:
					fourBytes.1 = 0xFF << (8 - extraBits)
				case 2:
					fourBytes.2 = 0xFF << (8 - extraBits)
				case 3:
					fourBytes.3 = 0xFF << (8 - extraBits)
				default:
					break
			}
		}

		self.init(RAW_staticbuff:&fourBytes)
	}

	public static func & (lhs:AddressV4, rhs:AddressV4) -> AddressV4 {
		return lhs.RAW_access_staticbuff { lhsPtr -> AddressV4 in
			return rhs.RAW_access_staticbuff { rhsPtr -> AddressV4 in
				let lhsBytes = lhsPtr.assumingMemoryBound(to:UInt8.self)
				let rhsBytes = rhsPtr.assumingMemoryBound(to:UInt8.self)
				return withUnsafePointer(to:(lhsBytes[0] & rhsBytes[0], lhsBytes[1] & rhsBytes[1], lhsBytes[2] & rhsBytes[2], lhsBytes[3] & rhsBytes[3])) {
					return AddressV4(RAW_staticbuff:$0)
				}
			}
		}
	}


	public static prefix func ~ (_ address:AddressV4) -> AddressV4 {
		return address.RAW_access_staticbuff { ptr in
			let bytes = ptr.assumingMemoryBound(to:UInt8.self)
			return withUnsafePointer(to:(~bytes[0], ~bytes[1], ~bytes[2], ~bytes[3])) {
				return AddressV4(RAW_staticbuff:$0)
			}
		}
	}

	public static func | (lhs:AddressV4, rhs:AddressV4) -> AddressV4 {
		return lhs.RAW_access_staticbuff { lhsPtr -> AddressV4 in
			return rhs.RAW_access_staticbuff { rhsPtr -> AddressV4 in
				let lhsBytes = lhsPtr.assumingMemoryBound(to:UInt8.self)
				let rhsBytes = rhsPtr.assumingMemoryBound(to:UInt8.self)
				return withUnsafePointer(to:(lhsBytes[0] | rhsBytes[0], lhsBytes[1] | rhsBytes[1], lhsBytes[2] | rhsBytes[2], lhsBytes[3] | rhsBytes[3])) {
					return AddressV4(RAW_staticbuff:$0)
				}
			}
		}
	}
}

extension AddressV4:CustomDebugStringConvertible {
	public var debugDescription:String {
		return String(self)
	}
}


extension String {
	public init(_ address:AddressV4) {
		self = address.RAW_access_staticbuff({
			let ptr = $0.assumingMemoryBound(to:AddressV4.RAW_staticbuff_storetype.self)
			return "\(ptr.pointee.0).\(ptr.pointee.1).\(ptr.pointee.2).\(ptr.pointee.3)"
		})
	}
}

@RAW_staticbuff(concat:AddressV4, AddressV4)
public struct RangeV4:RAW_comparable_fixed, Equatable, Comparable, Hashable {
	public typealias RAW_fixed_type = RAW_staticbuff_storetype

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
		self = Self(lower:AddressV4(RAW_staticbuff:&lowerBytes), upper:AddressV4(RAW_staticbuff:&upperBytes))
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
		return "\(lowerBound)-\(upperBound)"
	}
}

@RAW_staticbuff(concat:AddressV4, RAW_byte)
@MDB_comparable()
public struct NetworkV4:RAW_comparable_fixed, Equatable, Comparable, Hashable {
	public typealias RAW_fixed_type = RAW_staticbuff_storetype

	public let address:AddressV4
	fileprivate let _subnet_prefix:RAW_byte
	public var subnetPrefix:UInt8 {
		get {
			return _subnet_prefix.RAW_native()
		}
	}
	
	public var range:RangeV4 {
		get {
			return RangeV4(address:address, netmask:AddressV4(netmaskPrefix:_subnet_prefix.RAW_native())!)
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
		let hasNetmaskPrefix = AddressV4(netmaskPrefix:prefix)
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
}

extension NetworkV4:CustomDebugStringConvertible {
	public var debugDescription:String {
		return "\(address)/\(subnetPrefix)"
	}
}