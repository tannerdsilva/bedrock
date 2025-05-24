//import XCTest
//@testable import bedrock
//@testable import cbedrock
//
//final class bedrockTests:XCTestCase {
////    func testExample() throws {
////        // This is an example of a functional test case.
////        // Use XCTAssert and related functions to verify your tests produce the correct
////        // results.
////        XCTAssertEqual(bedrock().text, "Hello, World!")
////    }
//
//	func testLineParser() {
//		let lineTestData = [Data("this is a test of the first line".utf8), Data("".utf8), Data("this is a test of the third line".utf8), Data("line4".utf8)];
//		var patternData = Data()
//		patternData.append(10)
//		let lineDataMerged = Data(lineTestData.joined(separator:patternData))
//		var buildThings = [Data]()
//		patternData.withUnsafeMutableBytes({ patternIn in
//			var myLP = _cbedrock_lp_init(patternIn.baseAddress!.bindMemory(to: UInt8.self, capacity:1), 1);
//			lineDataMerged.withUnsafeBytes({ dataIn in
//				_cbedrock_lp_intake(&myLP, dataIn.baseAddress!.bindMemory(to:UInt8.self, capacity:dataIn.count), dataIn.count) { bytes, size in
//					let getData = Data(bytes:bytes, count:size)
//					buildThings.append(getData)
//				}
//			})
//			_cbedrock_lp_close(&myLP) { bytes, size in
//				let getData = Data(bytes:bytes, count:size)
//				buildThings.append(getData)
//			};
//		})
//		XCTAssert(lineTestData == buildThings)
//	}
//}
