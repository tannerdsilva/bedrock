import XCTest
@testable import RAW
@testable import bedrock_ipaddress

final class AddressV6Tests: XCTestCase {
    func testAddressV6Encoding() {
        let addressString = "2001:0db8:85a3:0000:0000:8a2e:0370:7334"
        let address = AddressV6(addressString)
        XCTAssertEqual(String(address!), addressString)
    }
    
    func testInvalidAddressV6() {
        let invalidAddressString = "2001:0db8:85a3:!:8a2e:0370"
        let address = AddressV6(invalidAddressString)
        XCTAssertNil(address)
    }
    
    func testAddressV6Decoding() {
        let addressString = "2001:0db8:85a3:0000:0000:8a2e:0370:7334"
        let address = AddressV6(addressString)
        XCTAssertEqual(String(address!), addressString)
    }

	func testAddressV6Range() {
		let addy = AddressV6("fe80::1")!
		let rangeString = NetworkV6("fe80:fe80:fe80:fe80::1/64")!
		XCTAssertEqual(String(rangeString.range.upperBound), "fe80:fe80:fe80:fe80:ffff:ffff:ffff:ffff")
	}
}

extension AddressV6Tests {
    static var allTests = [
        ("testAddressV6Encoding", testAddressV6Encoding),
        ("testInvalidAddressV6", testInvalidAddressV6),
        // ("testAddressV6Decoding", testAddressV6Decoding), .
    ]
}