import RAW

@RAW_staticbuff(bytes:4)
public struct AddressV4:RAW_comparable_fixed {
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
}

extension String {
	public init(_ address:AddressV4) {
		self = address.RAW_access_staticbuff({
			let ptr = $0.assumingMemoryBound(to:AddressV4.RAW_staticbuff_storetype.self)
			return "\(ptr.pointee.0).\(ptr.pointee.1).\(ptr.pointee.2).\(ptr.pointee.3)"
		})
	}
}