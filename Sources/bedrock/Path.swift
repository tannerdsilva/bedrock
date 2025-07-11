/// represents a path on the hosts filesystem.
public struct Path:Sendable {

	/// the individual components of the path. these are assumed to be separated by their platform specific path separator.
	private var components:[String]

	/// initialize a path with a string.
	public init<S>(_ p:consuming S) where S:StringProtocol, S.SubSequence == Substring {
		components = p.split(separator: "/", omittingEmptySubsequences:true).map(String.init)
	}
	
	/// appends a component to the path.
	public mutating func appendPathComponent(_ component:consuming String) {
		components.append(component)
	}

	/// returns a new path with the component appended.
	public consuming func appendingPathComponent(_ component:consuming String) -> Path {
		var p = self
		p.appendPathComponent(component)
		return p
	}

	/// remove last component
	public mutating func removeLastComponent() {
		components.removeLast()
	}

	/// returns a new path with the last component removed.
	public consuming func removingLastComponent() -> Path {
		var p = self
		p.removeLastComponent()
		return p
	}

	/// returns the path as a string.
	public consuming func path() -> String {
		return "/" + components.joined(separator: "/")
	}
}

extension Path:Codable {
	public func encode(to encoder:Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(path())
	}
	public init(from decoder:Decoder) throws {
		let container = try decoder.singleValueContainer()
		self = .init(try container.decode(String.self))
	}
}

extension Path:ExpressibleByStringLiteral {
	/// initialize a path by a string literal value.
	public init(stringLiteral value: String) {
		self.init(value)
	}
}

extension String {
	/// initialize a string from a system host path.
	public init(_ p:Path) {
		self = p.path()
	}
}