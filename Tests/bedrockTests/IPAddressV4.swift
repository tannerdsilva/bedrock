import XCTest
@testable import RAW
@testable import bedrock_ipaddress

final class AddressV4Tests: XCTestCase {
    func testAddressV4Encoding() {
        let addressString = "192.168.0.1"
        let address = AddressV4(addressString)
        XCTAssertEqual(String(address!), addressString)
    }
    
    func testInvalidAddressV4() {
        let invalidAddressString = "192.168.0"
        let address = AddressV4(invalidAddressString)
        XCTAssertNil(address)
    }
    
    func testAddressV4Decoding() {
        let addressString = "192.168.0.1"
        let address = AddressV4(addressString)
        XCTAssertEqual(String(address!), addressString)
    }

	func testAddressV4Range() {
		let rangeString = NetworkV4("192.168.1.1/24")!
		XCTAssertEqual(String(rangeString.range.upperBound), "192.168.1.255")
	}
}

extension AddressV4Tests {
    static var allTests = [
        ("testAddressV4Encoding", testAddressV4Encoding),
        ("testInvalidAddressV4", testInvalidAddressV4),
        ("testAddressV4Decoding", testAddressV4Decoding),
    ]
}