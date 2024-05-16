import RAW
import QuickLMDB

@RAW_staticbuff(bytes:4)
@MDB_comparable()
public struct AddressV4:RAW_comparable_fixed, Equatable, Comparable {
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
		var bytes = [UInt8](repeating:0, count:4)
		let fullBytes = Int(netmaskPrefix / 8)
		let extraBits = Int(netmaskPrefix % 8)

		// Fill full byte sections of the netmask
		for i in 0..<fullBytes {
			bytes[i] = 0xFF
		}

		// Set the remaining bits in the next byte
		if extraBits > 0 {
			bytes[fullBytes] = 0xFF << (8 - extraBits)
		}

		self.init(RAW_staticbuff:&bytes)
	}

	public func masked(by netmask:AddressV4) -> AddressV4 {
		return self.RAW_access_staticbuff { addressBytes -> AddressV4 in
			return netmask.RAW_access_staticbuff { maskBytes -> AddressV4 in
				let addressPtr = addressBytes.assumingMemoryBound(to:UInt8.self)
				let maskPtr = maskBytes.assumingMemoryBound(to:UInt8.self)
				return withUnsafePointer(to:(addressPtr[0] & maskPtr[0], addressPtr[1] & maskPtr[1], addressPtr[2] & maskPtr[2], addressPtr[3] & maskPtr[3])) {
					return AddressV4(RAW_staticbuff:$0)
				}
			}
		}
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
public struct RangeV4 {
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

public struct NetworkV4 {
	public let address:AddressV4
	public let prefix:UInt8
	
	public let range:RangeV4
	
	public init?(_ cidr:String) {
		let parts = cidr.split(separator:"/").map(String.init)
		guard parts.count == 2,
			let address = AddressV4(parts[0]),
			let prefix = UInt8(parts[1]),
			prefix <= 32 else {
			return nil
		}
		
		self.address = address
		self.prefix = prefix
		let hasNetmaskPrefix = AddressV4(netmaskPrefix:prefix)
		guard hasNetmaskPrefix != nil else {
			return nil
		}
		self.range = RangeV4(address:address, netmask:hasNetmaskPrefix!)
	}
	
	public func contains(_ address:AddressV4) -> Bool {
		return range.contains(address)
	}
	
	public func overlaps(with network:NetworkV4) -> Bool {
		return range.overlaps(network.range)
	}
}