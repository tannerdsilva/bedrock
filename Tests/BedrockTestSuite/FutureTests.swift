/*
LICENSE MIT
copyright (c) tanner silva 2026. all rights reserved.

bedrock

*/

import Testing
import Synchronization

@testable import bedrock_future
@testable import bedrock_pthread

extension Tag {
	@Tag internal static var future:Self
}

extension BedrockTestSuite {
	@Suite("bedrock_future_tests",
		.serialized,
		.tags(.future)
	)
	internal struct FutureTests {
		internal static func randomInt() -> Int {
			return Int.random(in:Int.min...Int.max)
		}
		internal static func randomString(length:Int) -> String {
			let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
			return String((0..<length).map({ _ in letters.randomElement()! }))
		}

		// IntHeap must be a class to test reference counting and deallocation
		private final class IntHeap:Sendable, Equatable {
			private let state:Mutex<(value:Int, conf:Confirmation?)>
			internal init(_ initialValue:Int, c:Confirmation) {
				state = Mutex((value:initialValue, conf:c))
			}
			internal func getValue() -> Int {
				return state.withLock({ $0.value })
			}
			internal func replaceConfirmation(_ newConf:Confirmation?) {
				state.withLock({ $0.conf = newConf })
			}
			internal static func == (lhs:IntHeap, rhs:IntHeap) -> Bool {
				return lhs.getValue() == rhs.getValue()
			}
			deinit {
				state.withLock({ $0.conf?.confirm() })
			}
		}

		private final class RandomTestError:Sendable, Swift.Error, Equatable {
			private let state:Mutex<(code:Int, message:String, conf:Confirmation?)>
			internal init(code:Int, message:String, confirmation:Confirmation?) {
				state = Mutex((code:code, message:message, conf:confirmation))
			}
			internal func replaceConfirmation(_ newConf:Confirmation?) {
				state.withLock({ $0.conf = newConf })
			}
			internal static func == (lhs:RandomTestError, rhs:RandomTestError) -> Bool {
				return lhs.state.withLock({ $0.code }) == rhs.state.withLock({ $0.code }) &&
					lhs.state.withLock({ $0.message }) == rhs.state.withLock({ $0.message })
			}
			deinit {
				state.withLock({ $0.conf?.confirm() })
				state.withLock({ $0.conf = nil })
			}
		}

		@Test("bedrock_future :: test successful assignment with memory checks (random integer value)", .timeLimit(.minutes(1)))
		mutating internal func setSuccessWithMemoryChecks() async throws {
			try await confirmation("successful result value deallocation (with consume)", expectedCount:100) { resultValueDeallocatorCounter in
				var future:Future<IntHeap, Swift.Error> = Future<IntHeap, Swift.Error>()
				for _ in 0..<100 {
					let randomValue = IntHeap(Self.randomInt(), c:resultValueDeallocatorCounter)
					#expect(future.hasResult() == false)
					try future.setSuccess(randomValue)
					let result = try await future.result()!.get().getValue()
					#expect(result == randomValue.getValue())
					#expect(future.hasResult() == true)
					future = Future<IntHeap, Swift.Error>()
				}
			}
			try await confirmation("successful result value deallocation (no consume)", expectedCount:100) { resultValueDeallocatorCounter in
				var future:Future<IntHeap, Swift.Error> = Future<IntHeap, Swift.Error>()
				for _ in 0..<100 {
					let randomValue = IntHeap(Self.randomInt(), c:resultValueDeallocatorCounter)
					try future.setSuccess(randomValue)
					future = Future<IntHeap, Swift.Error>()
				}
			}

			// test a loop of 100 successful results with the result NOT being consumed
			try await confirmation("successful result value deallocation (direct pass)", expectedCount:100) { resultValueDeallocatorCounter in
				var future:Future<IntHeap, Swift.Error> = Future<IntHeap, Swift.Error>()
				for _ in 0..<100 {
					_ = try await confirmation("testing for internal result value retention on direct pass", expectedCount:0) { resultValueHopeNoCountHere in
						try future.setSuccess(IntHeap(Self.randomInt(), c:resultValueHopeNoCountHere))
					}
					try await future.result()!.get().replaceConfirmation(resultValueDeallocatorCounter)
					future = Future<IntHeap, Swift.Error>()
				}
			}
		}

		@Test("bedrock_future :: test failure assignment with memory checks (random integer value)", .timeLimit(.minutes(1)))
		mutating func testSetFailureWithRandomErrors() async throws {
			try await confirmation("successful error value deallocation (with consume)", expectedCount:100) { resultValueDeallocatorCounter in
				var future:Future<IntHeap, RandomTestError> = Future<IntHeap, RandomTestError>()
				for _ in 0..<100 {
					let error = RandomTestError(code:Self.randomInt(), message:Self.randomString(length:20), confirmation:resultValueDeallocatorCounter)
					try future.setFailure(error)
					let result = await future.result()!
					#expect(result == Result.failure(error))
					future = Future<IntHeap, RandomTestError>()
				}
			}

			try await confirmation("successful error value deallocation (no consume)", expectedCount:100) { resultValueDeallocatorCounter in
				var future:Future<IntHeap, RandomTestError> = Future<IntHeap, RandomTestError>()
				for _ in 0..<100 {
					let error = RandomTestError(code:Self.randomInt(), message:Self.randomString(length:20), confirmation:resultValueDeallocatorCounter)
					try future.setFailure(error)
					future = Future<IntHeap, RandomTestError>()
				}
			}

			try await confirmation("successful error value deallocation (direct pass)", expectedCount:100) { resultValueDeallocatorCounter in
				var future:Future<IntHeap, RandomTestError> = Future<IntHeap, RandomTestError>()
				for _ in 0..<100 {
					let randomInt = Self.randomInt()
					let randomMessage = Self.randomString(length:20)
					_ = try await confirmation("testing for internal error value retention on direct pass", expectedCount:0) { resultValueHopeNoCountHere in
						try future.setFailure(RandomTestError(code:randomInt, message:randomMessage, confirmation:resultValueHopeNoCountHere))
					}
					let result = await future.result()!
					#expect(result == Result.failure(RandomTestError(code:randomInt, message:randomMessage, confirmation:nil)))
					guard case .failure(let e) = result else {
						fatalError("should never happen")
					}
					e.replaceConfirmation(resultValueDeallocatorCounter)
					future = Future<IntHeap, RandomTestError>()
				}
			}
		}

		@Test("bedrock_future :: test async waiter with cancellation", .timeLimit(.minutes(1)))
		func testAsyncWaiterCancellation() async throws {
			// test dropping the future while a `whenResult` callback is pending. this verifies that deinit resumes the pending waiters with nil and drops their references.
			await confirmation("test for correct dereferencing of @escaping handler references after dropping the future", expectedCount:1) { cancelCounter in
				let future = Future<Int, Never>()
				_ = future.whenResult { [d = WhenDeinitTool(cancelCounter, cancelCounter)] r in
					_ = d
					#expect(r == nil)
				}
				// the future goes out of scope here, which triggers the deinit that notifies the pending waiter with nil.
			}

			// test task cancellation
			let future2 = Future<Int, Never>()
			let task = Task<Bool, Never> {
				do {
					_ = try await future2.result(throwing:CancellationError.self, onCurrentTaskCancellation:CancellationError())
					return false
				} catch {
					return true
				}
			}
			task.cancel()
			let didThrow = await task.value
			#expect(didThrow == true)

			// ensure that the future can still be set without crashing, even though the cancelled task ignored the result.
			try future2.setSuccess(5)
		}

		@Test("bedrock_future :: test whenResult synchronous firing", .timeLimit(.minutes(1)))
		func testWhenResultSynchronous() async throws {
			let future = Future<Int, Never>()
			try future.setSuccess(10)

			await confirmation("whenResult fires synchronously", expectedCount:1) { syncFire in
				let handlerID = future.whenResult { result in
					syncFire.confirm()
					#expect(result != nil)
					#expect(result!.get() == 10)
				}
				#expect(handlerID == nil)
			}
		}

		@Test("bedrock_future :: test blocking waiter", .timeLimit(.minutes(1)))
		func testBlockingWaiter() throws {
			let future = Future<Int, Never>()
			// the resolve happens on another thread, so that this thread is free to park on the latch.
			Task { [f = future] in try? f.setSuccess(5) }
			let result = future.waitSynchronously().wait()!.get()
			#expect(result == 5)
		}

		@Test("bedrock_future :: test blocking waiter already resolved", .timeLimit(.minutes(1)))
		func testBlockingWaiterAlreadyResolved() throws {
			let future = Future<Int, Never>()
			try future.setSuccess(7)
			let result = future.waitSynchronously().wait()!.get()
			#expect(result == 7)
		}

		@Test("bedrock_future :: test blocking waiter cancelled", .timeLimit(.minutes(1)))
		func testBlockingWaiterCancelled() async throws {
			let future = Future<Int, Never>()
			let resultTool = future.waitSynchronously()
			// the wait parks a thread, so it runs on a pthread rather than on a swift concurrency thread.
			let waitingThread = try bedrock_pthread.launch {
				return resultTool.wait()
			}
			try await Task.sleep(nanoseconds:200_000_000)
			#expect(future.cancelWaiter(resultTool.uid) == true)
			let outcome = await waitingThread.workResult()
			let capResult:Result<Int, Never>? = try outcome!.get()
			#expect(capResult == nil)
			// ensure that the future can still be set without crashing.
			try future.setSuccess(10)
			let finalOutcome = await future.result()
			#expect(finalOutcome?.get() == 10)
		}

		@Test("bedrock_future :: test code block waiter cancelled", .timeLimit(.minutes(1)))
		func testCodeBlockWaiterCancelled() async throws {
			let future = Future<Int, Never>()
			await confirmation("confirm that the waiter is cancelled", expectedCount:1) { cancelConfirm in
				let handlerID = future.whenResult { result in
					cancelConfirm.confirm()
					#expect(result == nil)
				}
				#expect(handlerID != nil)
				#expect(future.cancelWaiter(handlerID!) == true)
			}
		}

		@Test("bedrock_future :: test cancelling a factory fresh future", .timeLimit(.minutes(1)))
		func testCancellingVirginFuture() async throws {
			let future = Future<Int, Never>()
			#expect(future.cancelWaiter(123456789) == false) // should be a no-op, but not crash
			try future.setSuccess(42) // ensure that the future can still be set without crashing
			#expect(future.cancelWaiter(24680) == false) // should be a no-op, but not crash
		}

		// MARK: - torture tests

		@Test("bedrock_future :: torture test high concurrency resolvers", .timeLimit(.minutes(1)))
		func testHighConcurrencyResolvers() async throws {
			let future = Future<Int, Never>()
			let successCount = Atomic<Int>(0)
			let errorCount = Atomic<Int>(0)
			await withTaskGroup(of:Result<Bool, Never>.self) { group in
				for i in 0..<100 {
					group.addTask {
						do {
							try future.setSuccess(i)
							return .success(true)
						} catch {
							return .success(false)
						}
					}
				}
				for await result in group {
					if result == .success(true) {
						successCount.add(1, ordering:.acquiring)
					} else {
						errorCount.add(1, ordering:.acquiring)
					}
				}
			}

			#expect(successCount.load(ordering:.acquiring) == 1)
			#expect(errorCount.load(ordering:.acquiring) == 99)

			let result = await future.result()!.get()
			#expect(result >= 0 && result < 100)
		}

		@Test("bedrock_future :: torture test high concurrency waiters", .timeLimit(.minutes(1)))
		func testHighConcurrencyWaiters() async throws {
			let future = Future<Int, Never>()
			let expectedValue = 42

			await withTaskGroup(of:Int?.self) { group in
				for _ in 0..<100 {
					group.addTask {
						return await future.result()?.get()
					}
				}

				// give the waiters a moment to register
				try! await Task.sleep(nanoseconds:100_000_000)
				try! future.setSuccess(expectedValue)

				for await result in group {
					#expect(result == expectedValue)
				}
			}
		}

		@Test("bedrock_future :: torture test high concurrency sync waiters", .timeLimit(.minutes(1)))
		func testHighConcurrencySyncWaiters() async throws {
			let future = Future<Int, Never>()
			let expectedValue = 99
			let threadsCount = 100
			let expectation = Atomic<Int>(0)

			// each thread parks on the latch until the result is set below.
			var runningThreads:[Running<GenericPThread<Bool>>] = []
			for _ in 0..<threadsCount {
				runningThreads.append(try bedrock_pthread.launch {
					if future.waitSynchronously().wait()?.get() == expectedValue {
						expectation.add(1, ordering:.sequentiallyConsistent)
						return true
					}
					return false
				})
			}

			// give the threads time to park on the latch
			try await Task.sleep(nanoseconds:200_000_000)
			try future.setSuccess(expectedValue)

			for thread in runningThreads {
				let outcome = await thread.workResult()
				#expect(outcome != nil)
				let didMatch = try outcome!.get()
				#expect(didMatch == true)
			}

			#expect(expectation.load(ordering:.sequentiallyConsistent) == threadsCount)
		}

		@Test("bedrock_future :: torture test multiple whenResult callbacks", .timeLimit(.minutes(1)))
		func testMultipleWhenResultCallbacks() async throws {
			let future = Future<Int, Never>()
			let expectedValue = 123

			try await confirmation("all callbacks fired", expectedCount:50) { confirm in
				for _ in 0..<50 {
					_ = future.whenResult { result in
						#expect(result?.get() == expectedValue)
						confirm()
					}
				}
				try future.setSuccess(expectedValue)
			}
		}

		@Test("bedrock_future :: torture test drop future with many whenResult callbacks", .timeLimit(.minutes(1)))
		func testDropFutureWithManyWhenResult() async throws {
			await confirmation("all callbacks cancelled on drop", expectedCount:100) { confirm in
				await confirmation("all callbacks cancelled on drop", expectedCount:100) { cancelCounter in
					let future = Future<Int, Never>()
					for _ in 0..<100 {
						_ = future.whenResult { [d = WhenDeinitTool((), confirm)] r in
							_ = d
							#expect(r == nil)
							cancelCounter.confirm()
						}
					}
					// the future goes out of scope here, which triggers the deinit that notifies every pending waiter with nil.
				}
			}
		}

		@Test("bedrock_future :: torture test stress result with cancellation", .timeLimit(.minutes(2)))
		func testStressResultWithCancellation() async throws {
			let future = Future<Int, Never>()
			let expectedValue = 777
			let totalTasks = 100
			let cancelTasks = totalTasks / 2

			var tasks:[Task<Bool, Never>] = []
			for i in 0..<totalTasks {
				let task = Task<Bool, Never> {
					try? await Task.sleep(nanoseconds:UInt64.random(in:1...4) * 1_000_000_000) // random sleep between 1 and 4 seconds
					do {
						let res = try await future.result(throwing:CancellationError.self, onCurrentTaskCancellation:CancellationError())
						return res?.get() == expectedValue
					} catch is CancellationError {
						return false // threw cancellation
					} catch {
						return false
					}
				}
				if i < cancelTasks {
					task.cancel()
				}
				tasks.append(task)
			}

			try future.setSuccess(expectedValue)

			var successCount = 0
			var cancelCount = 0
			for task in tasks {
				let result = await task.value
				if result {
					successCount += 1
				} else {
					cancelCount += 1
				}
			}

			#expect(successCount == totalTasks - cancelTasks)
			#expect(cancelCount == cancelTasks)
		}
	}
}