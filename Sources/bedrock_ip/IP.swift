import RAW
import QuickLMDB

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

	case v4(AddressV4)
	case v6(AddressV6)
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
}