import RAW

extension Address:RAW_accessible {
	public borrowing func RAW_access<R, E>(_ body:(UnsafeBufferPointer<UInt8>) throws(E) -> R) throws(E) -> R where E:Swift.Error {
		switch self {
			case .v4(let addr):
				return try addr.RAW_access(body)
			case .v6(let addr):
				return try addr.RAW_access(body)
		}
	}
	public mutating func RAW_access_mutating<R, E>(_ body:(UnsafeMutableBufferPointer<UInt8>) throws(E) -> R) throws(E) -> R where E:Swift.Error {
		switch self {
			case .v4(var addr):
				let retVal = try addr.RAW_access_mutating(body)
				self = .v4(addr)
				return retVal
			case .v6(var addr):
				let retVal = try addr.RAW_access_mutating(body)
				self = .v6(addr)
				return retVal
		}
	}
}

extension Address:RAW_decodable {
	public init?(RAW_decode:UnsafeRawPointer, count:size_t) {
		switch count {
			case MemoryLayout<AddressV6.RAW_staticbuff_storetype>.size:
				guard let addr = AddressV6(RAW_decode:RAW_decode, count:count) else {
					return nil
				}
				self = .v6(addr)
			case MemoryLayout<AddressV4.RAW_staticbuff_storetype>.size:
				guard let addr = AddressV4(RAW_decode:RAW_decode, count:count) else {
					return nil
				}
				self = .v4(addr)
			default:
				return nil
		}
	}
}

public enum Address:Sendable, Hashable, Equatable, Comparable, Codable, LosslessStringConvertible {
    public var description:String {
		switch self {
			case .v4(let v4):
				return String(v4)
			case .v6(let v6):
				return String(v6)
		}
	}

    public init?(_ description:String) {
        if description.contains(":") {
			if let v6 = AddressV6(description) {
				self = .v6(v6)
			} else {
				return nil
			}
		} else if description.contains(".") {
			if let v4 = AddressV4(description) {
				self = .v4(v4)
			} else {
				return nil
			}
		} else {
			return nil
		}
	}

	public init(from decoder:Decoder) throws {
		let container = try decoder.singleValueContainer()
		let description = try container.decode(String.self)
		if description.contains(":") {
			if let v6 = AddressV6(description) {
				self = .v6(v6)
			} else {
				throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid IPv6 address")
			}
		} else if description.contains(".") {
			if let v4 = AddressV4(description) {
				self = .v4(v4)
			} else {
				throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid IPv4 address")
			}
		} else {
			throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid address")
		}
	}

	public func encode(to encoder:Encoder) throws {
		var container = encoder.singleValueContainer()
		switch self {
			case .v4(let v4):
				try container.encode(String(v4))
			case .v6(let v6):
				try container.encode(String(v6))
		}
	}

	public static func < (lhs:Address, rhs:Address) -> Bool {
		switch (lhs, rhs) {
			case (.v4(let lhs), .v4(let rhs)):
				return lhs < rhs
			case (.v6(let lhs), .v6(let rhs)):
				return lhs < rhs
			case (.v4, .v6):
				return true
			case (.v6, .v4):
				return false
		}
	}

	public static func == (lhs:Address, rhs:Address) -> Bool {
		switch (lhs, rhs) {
			case (.v4(let lhs), .v4(let rhs)):
				return lhs == rhs
			case (.v6(let lhs), .v6(let rhs)):
				return lhs == rhs
			default:
				return false
		}
	}

	public func hash(into hasher:inout Hasher) {
		switch self {
			case .v4(let v4):
				hasher.combine(v4)
			case .v6(let v6):
				hasher.combine(v6)
		}
	}

	case v4(AddressV4)
	case v6(AddressV6)
}

extension Network:RAW_accessible {
	public borrowing func RAW_access<R, E>(_ body:(UnsafeBufferPointer<UInt8>) throws(E) -> R) throws(E) -> R where E:Swift.Error {
		switch self {
			case .v4(let net):
				return try net.RAW_access(body)
			case .v6(let net):
				return try net.RAW_access(body)
		}
	}
	public mutating func RAW_access_mutating<R, E>(_ body:(UnsafeMutableBufferPointer<UInt8>) throws(E) -> R) throws(E) -> R where E:Swift.Error {
		switch self {
			case .v4(var net):
				let retVal = try net.RAW_access_mutating(body)
				self = .v4(net)
				return retVal
			case .v6(var net):
				let retVal = try net.RAW_access_mutating(body)
				self = .v6(net)
				return retVal
		}
	}
}

extension Network:RAW_decodable {
	public init?(RAW_decode:UnsafeRawPointer, count:size_t) {
		switch count {
			case MemoryLayout<NetworkV6.RAW_staticbuff_storetype>.size:
				guard let net = NetworkV6(RAW_decode:RAW_decode, count:count) else {
					return nil
				}
				self = .v6(net)
			case MemoryLayout<NetworkV4.RAW_staticbuff_storetype>.size:
				guard let net = NetworkV4(RAW_decode:RAW_decode, count:count) else {
					return nil
				}
				self = .v4(net)
			default:
				return nil
		}
	}
}

public enum Network:Sendable, Hashable, Equatable, Comparable, Codable, LosslessStringConvertible {
	public var description:String {
		switch self {
			case .v4(let v4):
				return String(v4)
			case .v6(let v6):
				return String(v6)
		}
	}

	public init?(_ description:String) {
		if description.contains(":") {
			if let v6 = NetworkV6(description) {
				self = .v6(v6)
			} else {
				return nil
			}
		} else if description.contains(".") {
			if let v4 = NetworkV4(description) {
				self = .v4(v4)
			} else {
				return nil
			}
		} else {
			return nil
		}
	}

	public init(from decoder:Decoder) throws {
		let container = try decoder.singleValueContainer()
		let description = try container.decode(String.self)
		if description.contains(":") {
			if let v6 = NetworkV6(description) {
				self = .v6(v6)
			} else {
				throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid IPv6 network")
			}
		} else if description.contains(".") {
			if let v4 = NetworkV4(description) {
				self = .v4(v4)
			} else {
				throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid IPv4 network")
			}
		} else {
			throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid network")
		}
	}

	public func encode(to encoder:Encoder) throws {
		var container = encoder.singleValueContainer()
		switch self {
			case .v4(let v4):
				try container.encode(v4)
			case .v6(let v6):
				try container.encode(v6)
		}
	}

	case v4(NetworkV4)
	case v6(NetworkV6)

	public static func < (lhs:Network, rhs:Network) -> Bool {
		switch (lhs, rhs) {
			case (.v4(let lhs), .v4(let rhs)):
				return lhs < rhs
			case (.v6(let lhs), .v6(let rhs)):
				return lhs < rhs
			case (.v4, .v6):
				return true
			case (.v6, .v4):
				return false
		}
	}

	public static func == (lhs:Network, rhs:Network) -> Bool {
		switch (lhs, rhs) {
			case (.v4(let lhs), .v4(let rhs)):
				return lhs == rhs
			case (.v6(let lhs), .v6(let rhs)):
				return lhs == rhs
			default:
				return false
		}
	}

	public func hash(into hasher:inout Hasher) {
		switch self {
			case .v4(let v4):
				hasher.combine(v4)
			case .v6(let v6):
				hasher.combine(v6)
		}
	}
}