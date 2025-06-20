/*
LICENSE MIT
copyright (c) tanner silva 2025. all rights reserved.

bedrock

*/

import __cbedrock_future

/// internal tool to help extract the result from the future in a synchronous manner.
internal struct SyncResult:~Copyable {
	private var resultValue:SuccessFailureCancel? = nil
	private var waiter:__cbedrock_future_wait_t = __cbedrock_future_wait_t_init_struct()
	internal mutating func withWaiterPrimitiveAccess<R, E>(_ body:(UnsafeMutablePointer<SyncResult>) async throws(E) -> R) async throws(E) -> R where E:Swift.Error {
		return try await body(&self)
	}
	internal mutating func setResult(type:UInt8, pointer:UnsafeMutableRawPointer?) {
		resultValue = .success(type, pointer)
	}
	internal mutating func setError(type:UInt8, pointer:UnsafeMutableRawPointer?) {
		resultValue = .failure(type, pointer)
	}
	internal mutating func setCancel() {
		resultValue = .cancel
	}
	internal mutating func consumeResult() -> SuccessFailureCancel? {
		return resultValue
	}
}