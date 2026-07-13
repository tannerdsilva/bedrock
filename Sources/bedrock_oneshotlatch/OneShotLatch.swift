/*
LICENSE MIT
copyright (c) tanner silva 2026. all rights reserved.

bedrock

*/

import Synchronization
import class Dispatch.DispatchSemaphore

/// used to block a waiter for synchronous blocking until the latch is released.
/// NOTE: each instance of this class must handle a single waiter block latch. the instance is not reusable and there cannot be multiple waiters.
public final class OneShotLatch<Shot:Sendable>:Sendable {

	/// thrown when a latch is attempted to be unlocked or waited more than once - violating the one-shot semantics of this latch.
	public struct OneShotSemanticViolation:Swift.Error {}
	
	/// the internal state core of the one-shot latch.
	internal struct Core:~Copyable {
		
		/// has the one-shot latch been unlocked by an unlocker yet?
		internal private(set) var hasBeenUnlocked:Bool = false
		/// has the waiter started waiting for the latch to be released yet?
		internal private(set) var hasBeenWaited:Bool = false
		
		/// the semaphore primitive to block & unblock a waiting thread.
		private let semaphore:DispatchSemaphore = DispatchSemaphore(value:0)
		
		/// the result of the "one shot". when a result is assigned to a one-shot latch, any waiter that exists is unlatched and they are able to acquire this result.
		internal let result:Mutex<Shot?>
		fileprivate init() {
			result = .init(nil)
		}

		/// fire the "one shot" that will unlatch a waiter. an instance of `Shot` is passed to this function to mark its unlatching.
		internal mutating func fire(_ element:sending Shot) throws(OneShotSemanticViolation) {
			guard hasBeenUnlocked == false else {
				throw OneShotSemanticViolation()
			}
			hasBeenUnlocked = true
			result.withLock { result in
				result = element
			}
			semaphore.signal()
		}

		/// retrieve the semaphore for waiting.
		internal mutating func semaphoreForWaiting() throws(OneShotSemanticViolation) -> DispatchSemaphore {
			guard hasBeenWaited == false else {
				throw OneShotSemanticViolation()
			}
			hasBeenWaited = true
			return semaphore
		}

		/// after the semaphore has been unlatched, this function can be used to retrieve the `Shot` instance that triggered the unlatching.
		internal borrowing func resultAfterWaiting() -> Shot {
			return result.withLock { result in
				return result!
			}
		}
	}
	
	/// mutex guarded "core state" of the one-shot latch mechanism instance.
	internal let core:Mutex<Core> = .init(.init())
	
	/// initialize a new instance of the one-shot latch.
	public init() {}
	
	/// unlatch the mechanism.
	/// - if there is a waiter, the waiter will no longer block.
	/// - if there is not a waiter, they will not block when it comes time for `wait()`ing.
	public borrowing func fire(_ element:sending Shot) throws(OneShotSemanticViolation) {
		try core.withLock { coreState throws(OneShotSemanticViolation) in
			try coreState.fire(element)
		 }
	}
	
	/// an internal enum to represent the one of two states that this latch can be in when a user calls the `wait()` function.
	private enum ShotOrSemaphore {
		/// the single shot that cause the instance to become unlatched.
		case shot(Shot)
		/// the semaphore that shall be used to wait for the unlatching of this instance.
		case semaphore(DispatchSemaphore)
	}

	@available(*, noasync, message:"OneShotLatch.wait() is a synchronous blocking call. it is not compatible with async contexts.")
	public borrowing func wait() throws(OneShotSemanticViolation) -> Shot {
		let checkState:ShotOrSemaphore = try core.withLock({ coreState throws(OneShotSemanticViolation) -> ShotOrSemaphore in
			guard coreState.hasBeenUnlocked == false else {
				return coreState.result.withLock { result in
					.shot(result!)
				}
			}
			return .semaphore(try coreState.semaphoreForWaiting())
		})
		switch checkState {
			case .shot(let shot):
				return shot
			case .semaphore(let semaphore):
				semaphore.wait()
				return core.withLock { coreState in
					return coreState.resultAfterWaiting()
				}
		}
	}
}
