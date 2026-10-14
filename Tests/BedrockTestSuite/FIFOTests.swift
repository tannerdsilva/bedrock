/*
LICENSE MIT
copyright (c) tanner silva 2026. all rights reserved.

bedrock

*/

import Testing
@testable import bedrock_fifo
@testable import bedrock_pthread

extension Tag {
	@Tag internal static var fifo:Self
}

extension BedrockTestSuite {
	@Suite("bedrock_fifo_tests",
		.serialized,
		.tags(.fifo)
	)
	internal struct FIFOTests {
		@Test("bedrock_fifo :: basic usage with deinitialization checks", .timeLimit(.minutes(1)))
		func testFIFOWithDeinitTool() async {
			var fifo:FIFO<WhenDeinitTool<Int>, Never>? = try! FIFO<WhenDeinitTool<Int>, Never>()
			fifo = nil
			#expect(fifo == nil)
		}

		@Test("bedrock_fifo :: basic usage for no consumption", .timeLimit(.minutes(1)))
		func testNoConsumption() async {
			// test the scenario where nothing is ever consumed. ensure that the references are deinitialized properly when the fifo is deinitialized.
			var fifo:FIFO<WhenDeinitTool<Int>, Never>? = try! FIFO<WhenDeinitTool<Int>, Never>()
			await confirmation("verify correct memory management of elements passed to the fifo", expectedCount:5) { deinitExp in
				fifo!.yield(WhenDeinitTool(1, deinitExp))
				fifo!.yield(WhenDeinitTool(2, deinitExp))
				fifo!.yield(WhenDeinitTool(3, deinitExp))
				fifo!.yield(WhenDeinitTool(4, deinitExp))
				fifo!.yield(WhenDeinitTool(5, deinitExp))
				fifo = nil
			}
		}

		@Test("bedrock_fifo :: memory management in partial consumption scenario (async)", .timeLimit(.minutes(1)))
		func testPartialConsumption() async {
			// test a partial consumption scenario. ensure that the references are deinitialized properly when the fifo is deinitialized.
			var fifo:FIFO<WhenDeinitTool<Int>, Never>? = try! FIFO<WhenDeinitTool<Int>, Never>()
			await confirmation("verify correct memory management of elements passed to the fifo", expectedCount:2) { deinitOuter in
				await withTaskGroup(of:[Int].self) { tg in
					await confirmation("verify correct memory management of elements passed to the fifo", expectedCount:3) { deinitInner in
						tg.addTask { [asc = fifo!.makeAsyncConsumer()] in
							var buildInts = [Int]()
							var nextElement:WhenDeinitTool<Int>? = await asc.next()
							while nextElement != nil {
								buildInts.append(nextElement!.value)
								if buildInts.count == 3 {
									break
								} else {
									nextElement = await asc.next()
								}
							}
							return buildInts
						}
						fifo!.yield(WhenDeinitTool(1, deinitInner))
						fifo!.yield(WhenDeinitTool(2, deinitInner))
						fifo!.yield(WhenDeinitTool(3, deinitInner))
						fifo!.yield(WhenDeinitTool(4, deinitOuter))
						fifo!.yield(WhenDeinitTool(5, deinitOuter))
						try! fifo!.finish()
						await tg.waitForAll()
					}
				}
				fifo = nil
			}
		}

		@Test("bedrock_fifo :: testing large number of elements (async)", .timeLimit(.minutes(1)))
		func testFullConsumption() async {
			let elementCount = 10000
			// test a full consumption scenario. ensure that the references are deinitialized properly when the fifo is deinitialized.
			let fifo:FIFO<WhenDeinitTool<Int>, Never>? = try! FIFO<WhenDeinitTool<Int>, Never>()
			await confirmation("verify correct memory management of elements passed to the fifo", expectedCount:elementCount) { deinitOuter in
				await withTaskGroup(of:[Int].self) { tg in
					tg.addTask { [asc = fifo!.makeAsyncConsumer()] in
						var buildInts = [Int]()
						var nextElement:WhenDeinitTool<Int>? = await asc.next()
						while nextElement != nil {
							buildInts.append(nextElement!.value)
							nextElement = await asc.next()
						}
						return buildInts
					}
					var written = [Int]()
					for i in 0..<elementCount {
						fifo!.yield(WhenDeinitTool(i, deinitOuter))
						written.append(i)
					}
					try! fifo!.finish()
					#expect(await tg.next() == written)
				}
			}
		}

		@Test("bedrock_fifo :: intentional overflow of maximum element count (async)", .timeLimit(.minutes(1)))
		func testMaxElementOverflow() async {
			let writeCount = 10000
			let maxCount:UInt64 = 10
			// test a scenario where the maximum element count is deliberately exceeded. every element that is refused is released, and the consumed set is exactly the buffered one.
			var fifo:FIFO<WhenDeinitTool<Int>, Never>? = try! FIFO<WhenDeinitTool<Int>, Never>(maximumElementCount:maxCount)
			await confirmation("verify correct memory management of elements passed to the fifo", expectedCount:writeCount) { deinitThing in
				await withTaskGroup(of:[Int].self) { tg in
					var written = [Int]()
					for i in 0..<writeCount {
						if i < maxCount {
							#expect(fifo!.yield(WhenDeinitTool(i, deinitThing)) == .success)
						} else {
							#expect(fifo!.yield(WhenDeinitTool(i, deinitThing)) == .fifoFull)
						}
						written.append(i)
					}
					tg.addTask { [asc = fifo!.makeAsyncConsumer()] in
						var buildInts = [Int]()
						var nextElement:WhenDeinitTool<Int>? = await asc.next()
						while nextElement != nil {
							buildInts.append(nextElement!.value)
							nextElement = await asc.next()
						}
						return buildInts
					}
					try! fifo!.finish()
					let expected = Array(written.prefix(10))
					let foundItem = await tg.next()!
					#expect(expected == foundItem, "\(foundItem) != \(expected)")
					fifo = nil
				}
			}
		}

		@Test("bedrock_fifo :: a maximum element count of zero is refused", .timeLimit(.minutes(1)))
		func testZeroMaximumElementCount() {
			do {
				_ = try FIFO<Int, Never>(maximumElementCount:0)
				Issue.record("a maximum element count of zero was not refused")
			} catch {
				// a maximum element count of zero is refused.
			}
		}

		@Test("bedrock_fifo :: a finished fifo refuses a second finish", .timeLimit(.minutes(1)))
		func testSecondFinishIsRefused() throws {
			let fifo = try FIFO<Int, Never>()
			try fifo.finish()
			do {
				try fifo.finish()
				Issue.record("a second finish was not refused")
			} catch {
				// a second finish is refused because the fifo is already finished.
			}
		}

		@Test("bedrock_fifo :: a yield into a finished fifo is refused", .timeLimit(.minutes(1)))
		func testYieldAfterFinish() throws {
			let fifo = try FIFO<Int, Never>()
			try fifo.finish()
			#expect(fifo.yield(1) == .fifoClosed)
		}

		@Test("bedrock_fifo :: synchronous non-blocking consumer drains what is buffered", .timeLimit(.minutes(1)))
		func testSyncConsumerNonBlocking() throws {
			let fifo = try FIFO<Int, Never>()
			fifo.yield(1)
			fifo.yield(2)
			let consumer = fifo.makeSyncConsumerNonBlocking()
			var drained = [Int]()
			while let element = consumer.next() {
				drained.append(element)
			}
			#expect(drained == [1, 2])
		}

		@Test("bedrock_fifo :: synchronous blocking consumer waits for an element", .timeLimit(.minutes(1)))
		func testSyncConsumerBlocking() async throws {
			let fifo = try FIFO<Int, Never>()
			// the blocking consumer parks a thread until an element is available, so it runs on a pthread rather than on a swift concurrency thread. the consumer itself is created on that thread.
			let consumingThread = try bedrock_pthread.launch { [fifo] in
				let consumer = fifo.makeSyncConsumerBlocking()
				return consumer.next()
			}
			fifo.yield(41)
			let outcome = await consumingThread.workResult()
			let element = try outcome!.get()
			#expect(element == 41)
		}

		@Test("bedrock_fifo :: an error that finishes the fifo is thrown by the consumer", .timeLimit(.minutes(1)))
		func testFinishWithErrorIsThrown() async throws {
			enum TestError:Swift.Error { case end }
			let fifo = try FIFO<Int, TestError>()
			fifo.yield(1)
			try fifo.finish(withError:.end)
			let consumer = fifo.makeAsyncConsumer()
			let first = try await consumer.next()
			#expect(first == 1)
			do {
				_ = try await consumer.next()
				Issue.record("the consumer did not throw the error that capped the fifo")
			} catch {
				// the error that capped the fifo is thrown to the consumer once the buffer has been drained.
			}
		}

		@Test("bedrock_fifo :: only one waiter may exist at a time", .timeLimit(.minutes(1)))
		func testOnlyOneWaiter() async throws {
			let fifo = try FIFO<Int, Never>()
			// the first consumer parks a waiter in the fifo, and the second is refused while that waiter is pending. the consumer is created on the task that consumes from it.
			let parked = Task { [fifo] in
				let consumer = fifo.makeAsyncConsumerExplicit()
				return await consumer.next()
			}
			try await Task.sleep(nanoseconds:100_000_000)
			do {
				_ = try fifo.nextSynchronous()
				Issue.record("a second waiter was not refused")
			} catch {
				// a second waiter is refused while the first one is still parked.
			}
			fifo.yield(1)
			_ = await parked.value
		}
	}
}