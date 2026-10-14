/*
LICENSE MIT
copyright (c) tanner silva 2026. all rights reserved.

bedrock

*/

import Testing

/// a reference type that confirms the moment it is deinitialized. a test uses it to witness that a mechanism released the values that it was holding.
/// - NOTE: this tool is what allows a test to assert on memory management rather than on the observable behaviour of a mechanism alone.
internal final class WhenDeinitTool<T:Sendable>:Sendable {
	private let conf:Confirmation
	internal let value:T
	internal init(_ value:T, _ conf:Confirmation) {
		self.conf = conf
		self.value = value
	}

	deinit {
		conf.confirm()
	}
}

extension WhenDeinitTool:Equatable, Hashable where T:Hashable, T:Equatable {
	static func == (lhs:WhenDeinitTool<T>, rhs:WhenDeinitTool<T>) -> Bool {
		return lhs.value == rhs.value
	}

	func hash(into hasher:inout Hasher) {
		hasher.combine(value)
	}
}