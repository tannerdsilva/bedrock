/*
LICENSE MIT
copyright (c) tanner silva 2025. all rights reserved.

bedrock

*/

import Testing
@testable import bedrock_pthread

import __cbedrock_threads
import bedrock_future
import func Foundation.sleep

extension Tag {
	@Tag internal static var swiftSlashPThread:Self
}

fileprivate final class MyTest {
	init(_ expect:Confirmation) {
		self.expect = expect
	}
	let expect:Confirmation
	deinit {
		expect.confirm()
	}
}


// a declaration of the pthread worker that will be used to test the pthreads.
fileprivate struct SimpleReturnWorker<A:Sendable>:PThreadWork {
	// the argument type of the pthread worker
	typealias ArgumentType = A
	
	// the return type of the pthread worker
	typealias ReturnType = A
	
	// the input argument for the worker 
	private let ia:ArgumentType
	
	// initialize the worker thing with a given argument value
	internal init(_ a:consuming ArgumentType) {
		ia = a
	}
	
	// the pthread work that needs to be executed
	fileprivate mutating func pthreadWork() throws -> ReturnType {
		return ia
	}
}

fileprivate struct CancelTestWorker:PThreadWork {
	// the argument type of the pthread worker
	typealias ArgumentType = (Confirmation, Future<Void, Never>, Future<Void, Never>)
	
	// the return type of the pthread worker
	typealias ReturnType = Void
	
	// the input argument for the worker 
	private let freeConfirm:Confirmation
	private let lf:Future<Void, Never>
	private let cf:Future<Void, Never>
	
	// initialize the worker thing with a given argument value
	internal init(_ a:consuming ArgumentType) {
		(self.freeConfirm, self.lf, self.cf) = withUnsafeMutablePointer(to:&a) { aPtr in
			return (aPtr.pointee.0, aPtr.pointee.1, aPtr.pointee.2)
		}
	}
	
	// the pthread work that needs to be executed
	fileprivate mutating func pthreadWork() throws -> ReturnType {
		let testThing = MyTest(freeConfirm)
		
		try lf.setSuccess(())
	}
}

extension BedrockTestSuite {
	@Suite("bedrock_pthread_tests",
		.serialized,
		.tags(.swiftSlashPThread)
	)
	internal struct PThreadTests {
		@Test("bedrock_pthread :: return values from pthreads", .timeLimit(.minutes(1)))
		func testPthreadReturn() async throws {
			for _ in 0..<512 {
				let randomString = String.random(length:56)
				let myString:String? = try await SimpleReturnWorker<String?>.run(randomString)!.get()
				#expect(randomString == myString)
			}
		}

		
		@Test("bedrock_pthread :: cancellation of pthreads that are already in flight (with memory checks)", .timeLimit(.minutes(1)))
		func testPthreadCancellation() async throws {
			try await confirmation("confirm that memoryspace is freed as a result of the cancellation", expectedCount:1) { freeConfirm in
				try await confirmation("confirm that the pthread does not return", expectedCount:0) { returnConfirm in
					
					let launchFuture = Future<Void, Never>()
					let cancelFuture = Future<Void, Never>()
					
					// launch the pthread that will be subject to cancellation testing.
					let runTask = try await bedrock_pthread.launch { [lf = launchFuture, cf = cancelFuture] in
						
						// declare a memory artifact within the pthread.
						_ = MyTest(freeConfirm)
						
						try lf.setSuccess(())
						
						// wait for the cancelation to be set.
						cf.blockingResult()!.get()
						
						// test for cancellation. this would usually be the end of the pthread.
						pthread_testcancel()
						
						// this should never fulfill.
						returnConfirm.confirm()
					}
					
					// wait for the thread to launch.
					await launchFuture.result()!.get()
					
					// cancel the thread
					try runTask.cancel()
					
					// set the cancellation future to success.
					try cancelFuture.setSuccess(())
					
					let gotReturn:Bool
					switch await runTask.workResult() {
					case .success:
						gotReturn = true
					case .failure(let error):
						#expect(error is CancellationError)
						gotReturn = false
					case .none:
						gotReturn = false
					}
					#expect(gotReturn == false)
				}
			}
		}
	}
}


extension String {
	// utility function to generate a random string of given length
	internal static func random(length: Int) -> String {
		let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_+=-`~/?.>,<;:'\""
		return String((0..<length).map { _ in characters.randomElement()! })
	}
}
