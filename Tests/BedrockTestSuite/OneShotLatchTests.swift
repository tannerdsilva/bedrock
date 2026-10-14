/*
LICENSE MIT
copyright (c) tanner silva 2026. all rights reserved.

bedrock

*/

import Testing
import Synchronization

@testable import bedrock_future
@testable import bedrock_oneshot_latch
@testable import bedrock_pthread

extension Tag {
	@Tag internal static var oneShotLatch:Self
}

extension BedrockTestSuite {
	@Suite("bedrock_oneshot_latch_tests",
		.serialized,
		.tags(.oneShotLatch)
	)
	internal struct OneShotLatchTests {
		@Test("bedrock_oneshot_latch :: confirm deinit after unlock - no wait", .timeLimit(.minutes(1)))
		func testOneShotLatchMemoryManagement() async throws {
			try await confirmation("confirm correct memory management throughout lifecycle", expectedCount:1) { deinitConf in
				let latch = WhenDeinitTool(OneShotLatch<Void>(), deinitConf)
				try latch.value.fire(())
			}
		}

		@Test("bedrock_oneshot_latch :: a waiting thread is released by a fire", .timeLimit(.minutes(1)))
		func testSyncWaitReleasedByFire() async throws {
			let latch = OneShotLatch<Int>()
			// the wait blocks the thread that calls it, so it runs on a pthread rather than on a swift concurrency thread.
			let waitingThread = try bedrock_pthread.launch {
				// the latch wait is a throwing operation, and the pthread delivers the outcome through the returned future.
				return try latch.wait()
			}
			try await Task.sleep(nanoseconds:100_000_000)
			try latch.fire(41)
			let outcome = await waitingThread.workResult()
			let shot = try outcome!.get()
			#expect(shot == 41)
		}

		@Test("bedrock_oneshot_latch :: a fire that arrives before the wait is observed immediately", .timeLimit(.minutes(1)))
		func testFireBeforeWait() throws {
			let latch = OneShotLatch<Int>()
			try latch.fire(7)
			let shot = try latch.wait()
			#expect(shot == 7)
		}

		@Test("bedrock_oneshot_latch :: a second fire is refused", .timeLimit(.minutes(1)))
		func testSecondFireIsRefused() throws {
			let latch = OneShotLatch<Int>()
			try latch.fire(1)
			do {
				try latch.fire(2)
				Issue.record("a second fire was not refused")
			} catch {
				// a second fire is refused, which is the one shot semantic of the latch.
			}
		}

		@Test("bedrock_oneshot_latch :: a second parking wait is refused", .timeLimit(.minutes(1)))
		func testSecondParkingWaitIsRefused() async throws {
			let latch = OneShotLatch<Int>()
			// the first wait parks a thread on the latch, which is the only wait that the latch allows.
			let parkingThread = try bedrock_pthread.launch { [latch] in
				return try latch.wait()
			}
			// give the first thread time to park, so that the second wait is unambiguously the second caller.
			try await Task.sleep(nanoseconds:100_000_000)
			// the second wait runs on another pthread, and is refused because the latch already has a waiter.
			let refusedThread = try bedrock_pthread.launch { [latch] in
				do {
					_ = try latch.wait()
					return false
				} catch {
					return true
				}
			}
			let wasRefused = try await refusedThread.workResult()!.get()
			#expect(wasRefused == true)
			try latch.fire(41)
			let shot = try await parkingThread.workResult()!.get()
			#expect(shot == 41)
		}

		@Test("bedrock_oneshot_latch :: repeated reads of a fired latch return the same shot", .timeLimit(.minutes(1)))
		func testRepeatedReadsReturnTheSameShot() throws {
			let latch = OneShotLatch<Int>()
			try latch.fire(1)
			let first = try latch.wait()
			let second = try latch.wait()
			#expect(first == 1)
			#expect(second == 1)
		}
	}
}