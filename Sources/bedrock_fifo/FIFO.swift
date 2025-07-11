/* LICENSE MIT
copyright (c) tanner silva 2025. all rights reserved.

bedrock

*/

import __cbedrock_fifo
import bedrock_contained

/// fifo is a mechanism that operates very similarly to a native Swift AsyncStream. the tool is designed for use with a single producer and a single consumer. the tool is thread-safe and reentrancy-safe, but is not intended for use with multiple producers or multiple consumers.
public final class FIFO<Element, Failure>:@unchecked Sendable where Failure:Swift.Error {
	
	/// used to convey one of the possible outcomes of consuming the next element from the FIFO.
	public enum ConsumeResult {
		/// the next element was successfully consumed from the FIFO.
		case element(Element)
		/// the FIFO was closed, and no more elements may be consumed.
		case capped(Result<Void, Failure>)
		/// the FIFO is currently empty, and no elements may be consumed at this time.
		case wouldBlock
	}

	/// used to convey the various types of results that may occur when yielding an element into the FIFO.
	public enum YieldResult {
		/// the yield value was successfully passed into the FIFO
		case success
		/// the FIFO was closed, and the yield value was not passed into the FIFO
		case fifoClosed
		/// the FIFO was full, and the yield value was not passed into the FIFO
		case fifoFull
	}
	
	// underlying c implementation
	private let datachain_primitive_ptr:UnsafeMutablePointer<__cbedrock_fifo_linkpair_t>
	
	/// initialize a new FIFO with a specified maximum element count.
	/// - parameters:
	///		- maximumElementCount: the maximum number of elements that may be held in the FIFO at any given time.
	public init(maximumElementCount:size_t) {
		// memory setup
		let newPointer = __cbedrock_fifo_init(true)

		// set the maximum element count if it was passed
		guard __cbedrock_fifo_set_max_elements(newPointer, maximumElementCount) == true else {
			fatalError("bedrock - failed to set maximum element count - \(#file):\(#line)")
		}
		datachain_primitive_ptr = newPointer
	}

	/// initialize a new FIFO with no maximum element count. yielded elements will be retained indefinitely until they are consumed or the FIFO is deinitialized.
	public init() {
		datachain_primitive_ptr = __cbedrock_fifo_init(true)
	}

	/// pass an element into the FIFO for consumption. the element will be held until it is consumed by the consumer. if the FIFO is closed, the element will be held until the FIFO is deinitialized. if a maximum element count was set, the element will be immediately discarded if the FIFO is full.
	@discardableResult public borrowing func yield(_ element:consuming Element) -> YieldResult {
		let um = Unmanaged.passRetained(Contained(element)).toOpaque()
		passLoop: repeat {
			logicSwitch: switch __cbedrock_fifo_pass(datachain_primitive_ptr, um) {
				// try again
				case 1:
					break logicSwitch

				// success return
				case 0:
					return .success

				// the FIFO is closed
				case -1:
					_ = Unmanaged<Contained<Element>>.fromOpaque(um).takeRetainedValue()
					return .fifoClosed

				// the FIFO is full
				case -2:
					_ = Unmanaged<Contained<Element>>.fromOpaque(um).takeRetainedValue()
					return .fifoFull
				default:
					fatalError("bedrock - unexpected return value from __cbedrock_fifo_pass - \(#file):\(#line)")
			}
		} while true
	}

	/// finish the FIFO. after calling this function, the FIFO will not accept any more data. additional objects may be passed into the FIFO, and they will be held and eventually dereferenced when the FIFO is deinitialized.
	public borrowing func finish() {
		let resultElement = Unmanaged.passRetained(Contained<Result<Void, Failure>>(.success(())))
		guard __cbedrock_fifo_pass_cap(datachain_primitive_ptr, resultElement.toOpaque()) == true else {
			_ = resultElement.takeRetainedValue()
			return
		}
	}

	/// finish the FIFO. after calling this function, the FIFO will not accept any more data. additional objects may be passed into the FIFO, and they will be held and eventually dereferenced when the FIFO is deinitialized.
	public borrowing func finish(throwing finishingError:consuming Failure) {
		let resultElement = Unmanaged.passRetained(Contained<Result<Void, Failure>>(.failure(finishingError)))
		guard __cbedrock_fifo_pass_cap(datachain_primitive_ptr, resultElement.toOpaque()) == true else {
			_ = resultElement.takeRetainedValue()
			return
		}
	}

	deinit {
		// close the fifo and capture the various pointers that are being held and returned by this function.
		var items = [UnsafeMutableRawPointer]()
		let capPointer:(Bool, UnsafeMutableRawPointer?) = withUnsafeMutablePointer(to:&items) { itemsPointer in
			var capPtr:UnsafeMutableRawPointer? = nil
			return (__cbedrock_fifo_close(datachain_primitive_ptr, { pointer, ctx in
				ctx!.assumingMemoryBound(to:[UnsafeMutableRawPointer].self).pointee.append(pointer)
			}, itemsPointer, &capPtr), capPtr)
		}
		// consume a reference to each of the items that were being held by the FIFO
		for item in items {
			_ = Unmanaged<Contained<Element>>.fromOpaque(item).takeRetainedValue()
		}
		// consume the cap pointer if it was returned
		if capPointer.0 == true && capPointer.1 != nil {
			_ = Unmanaged<Contained<Result<Void, Failure>>>.fromOpaque(capPointer.1!).takeRetainedValue()
		}
	}
}

extension FIFO {
	public func makeSyncConsumerNonblockingExplicit() -> SyncConsumerNonBlockingExplicit {
		return SyncConsumerNonBlockingExplicit(self)
	}

	public struct SyncConsumerNonBlockingExplicit {
		public enum WhenConsumingTaskCancelled {
			case noAction
			case finish
		}
		private let fifo:FIFO<Element, Failure>
		internal init(_ fifoIn:consuming FIFO) {
			fifo = fifoIn
		}

		public borrowing func next() -> ConsumeResult {
			return _nextExplicit()
		}
	}
}

extension FIFO {
	public func makeSyncConsumerNonBlocking() -> SyncConsumerNonBlocking {
		return SyncConsumerNonBlocking(self)
	}

	public struct SyncConsumerNonBlocking {
		private let fifo:FIFO<Element, Failure>
		internal init(_ fifoIn:consuming FIFO) {
			fifo = fifoIn
		}

		public borrowing func next() throws(Failure) -> Element? {
			return try _next()?.get()
		}
	}
}

extension FIFO {
	public func makeSyncConsumerBlockingExplicit() -> SyncConsumerBlockingExplicit {
		return SyncConsumerBlockingExplicit(self)
	}

	public struct SyncConsumerBlockingExplicit {
		public enum WhenConsumingTaskCancelled {
			case noAction
			case finish
		}
		private let fifo:FIFO<Element, Failure>
		internal init(_ fifoIn:consuming FIFO) {
			fifo = fifoIn
		}

		public borrowing func next() -> ConsumeResult {
			return _nextExplicit()
		}
	}
}

extension FIFO {
	public func makeSyncConsumerBlocking() -> SyncConsumerBlocking {
		return SyncConsumerBlocking(self)
	}

	public struct SyncConsumerBlocking {
		private let fifo:FIFO<Element, Failure>
		internal init(_ fifoIn:consuming FIFO) {
			fifo = fifoIn
		}

		public borrowing func next() throws(Failure) -> Element? {
			return try _next().get()
		}
	}
}

extension FIFO {
	/// create a new consumer for the FIFO. this should be the only consumer for the FIFO, as the FIFO is not intended for use with multiple consumers.
	public func makeAsyncConsumerExplicit() -> AsyncConsumerExplicit {
		return AsyncConsumerExplicit(self)
	}

	/// the primary structure for consuming elements from the FIFO in an explicit way.
	public struct AsyncConsumerExplicit {
		public enum WhenConsumingTaskCancelled {
			case noAction
			case finish
		}
		private let fifo:FIFO<Element, Failure>
		internal init(_ fifoIn:consuming FIFO) {
			fifo = fifoIn
		}
		public borrowing func next(whenTaskCancelled cancelAction:consuming WhenConsumingTaskCancelled = .noAction) async -> ConsumeResult {
			switch cancelAction {
				case .noAction:
					return await _nextExplicit()
				case .finish:
					return await withTaskCancellationHandler(operation: {
						await _nextExplicit()
					}, onCancel: { [f = fifo] in
						f.finish()
					})
			}
		}
	}
}

extension FIFO {
	/// create a new consumer for the FIFO. this should be the only consumer for the FIFO, as the FIFO is not intended for use with multiple consumers.
	public func makeAsyncConsumer() -> AsyncConsumer {
		return AsyncConsumer(self)
	}

	/// the primary structure for consuming elements from the FIFO.
	public struct AsyncConsumer {
		/// specifies the action to take when a task is cancelled while consuming the FIFO.
		public enum WhenConsumingTaskCancelled {
			/// when the current task is cancelled, the FIFO will not be affected. no actions will be taken.
			case noAction
			/// when the current task is cancelled, the FIFO will be finished.
			case finish
		}

		/// the FIFO being consumed
		private let fifo:FIFO<Element, Failure>

		/// initialize a new consumer for the specified FIFO.
		internal init(_ fifoIn:consuming FIFO) {
			fifo = fifoIn
		}

		/// wait asyncronously for the next element to consume from the FIFO.
		public borrowing func next(whenTaskCancelled cancelAction:consuming WhenConsumingTaskCancelled = .noAction) async throws(Failure) -> Element? {
			switch cancelAction {
				case .noAction:
					return try await _next().get()
				case .finish:
					return try await withTaskCancellationHandler(operation: {
						await _next()
					}, onCancel: { [f = fifo] in
						f.finish()
					}).get()
			}
		}
	}
}

extension FIFO.SyncConsumerNonBlockingExplicit {
	fileprivate borrowing func _nextExplicit() -> FIFO.ConsumeResult {
		var pointer:__cbedrock_ptr_t? = nil
		return FIFO._handleFIFOConsumeExplicit(__cbedrock_fifo_consume_nonblocking(fifo.datachain_primitive_ptr, &pointer), pointer)
	}
}
extension FIFO.SyncConsumerNonBlocking {
	fileprivate borrowing func _next() -> Result<Element?, Failure>? {
		var pointer:__cbedrock_ptr_t? = nil
		return FIFO._handleFIFOConsume(__cbedrock_fifo_consume_nonblocking(fifo.datachain_primitive_ptr, &pointer), pointer)
	}
}

extension FIFO.SyncConsumerBlockingExplicit {
	fileprivate borrowing func _nextExplicit() -> FIFO.ConsumeResult {
		var pointer:__cbedrock_ptr_t? = nil
		return FIFO._handleFIFOConsumeExplicit(__cbedrock_fifo_consume_blocking(fifo.datachain_primitive_ptr, &pointer), pointer)
	}
}
extension FIFO.SyncConsumerBlocking {
	fileprivate borrowing func _next() -> Result<Element?, Failure> {
		var pointer:__cbedrock_ptr_t? = nil
		return FIFO._handleFIFOConsume(__cbedrock_fifo_consume_blocking(fifo.datachain_primitive_ptr, &pointer), pointer)!
	}
}
extension FIFO.AsyncConsumerExplicit {
	fileprivate borrowing func _nextExplicit() async -> FIFO.ConsumeResult {
		return await withUnsafeContinuation({ (continuation:UnsafeContinuation<FIFO.ConsumeResult, Never>) in
			var pointer:__cbedrock_ptr_t? = nil
			let result = FIFO._handleFIFOConsumeExplicit(__cbedrock_fifo_consume_blocking(fifo.datachain_primitive_ptr, &pointer), pointer)
			continuation.resume(returning:result)
		})
	}
}
extension FIFO.AsyncConsumer {
	fileprivate borrowing func _next() async -> Result<Element?, Failure> {
		return await withUnsafeContinuation({ (continuation:UnsafeContinuation<Result<Element?, Failure>, Never>) in
			var pointer:__cbedrock_ptr_t? = nil
			continuation.resume(returning:FIFO._handleFIFOConsume(__cbedrock_fifo_consume_blocking(fifo.datachain_primitive_ptr, &pointer), pointer)!)
		})
	}
}

extension FIFO {
	fileprivate static func _handleFIFOConsumeExplicit(_ ret:__cbedrock_fifo_consume_result_t, _ pointer:__cbedrock_ptr_t?) -> ConsumeResult {
		switch ret {
			case  __CBEDROCK_FIFO_CONSUME_RESULT:
				return .element(Unmanaged<Contained<Element>>.fromOpaque(pointer!).takeRetainedValue().value())
			case  __CBEDROCK_FIFO_CONSUME_CAP:
				switch Unmanaged<Contained<Result<Void, Failure>>>.fromOpaque(pointer!).takeUnretainedValue().value() {
					case .success:
						return .capped(.success(()))
					case .failure(let err):
						return .capped(.failure(err))
				}
			case  __CBEDROCK_FIFO_CONSUME_WOULDBLOCK:
				return .wouldBlock
			case  __CBEDROCK_FIFO_CONSUME_INTERNAL_ERROR:
				fatalError("SwiftSlashFIFO :: got FIFO_CONSUME_INTERNAL_ERROR from _cbedrock_fifo_consume_blocking. this is a critical internal error :: \(#file):\(#line)")
			default:
				fatalError("SwiftSlashFIFO :: unexpected return value from _cbedrock_fifo_consume_blocking - \(#file):\(#line)")
		}
	}
	fileprivate static func _handleFIFOConsume(_ ret:__cbedrock_fifo_consume_result_t, _ pointer:__cbedrock_ptr_t?) -> Result<Element?, Failure>? {
		switch ret {
			case  __CBEDROCK_FIFO_CONSUME_RESULT:
				return .success(Unmanaged<Contained<Element>>.fromOpaque(pointer!).takeRetainedValue().value())
			case  __CBEDROCK_FIFO_CONSUME_CAP:
				switch Unmanaged<Contained<Result<Void, Failure>>>.fromOpaque(pointer!).takeUnretainedValue().value() {
					case .success:
						return .success(nil)
					case .failure(let err):
						return .failure(err)
				}
			case  __CBEDROCK_FIFO_CONSUME_WOULDBLOCK:
				return nil
			case  __CBEDROCK_FIFO_CONSUME_INTERNAL_ERROR:
				fatalError("bedrock - got FIFO_CONSUME_INTERNAL_ERROR from _cbedrock_fifo_consume_blocking - \(#file):\(#line)")
			default:
				fatalError("bedrock - unexpected return value from _cbedrock_fifo_consume_blocking - \(#file):\(#line)")
		}
	}
}