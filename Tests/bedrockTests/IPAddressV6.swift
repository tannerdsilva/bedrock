import Testing
@testable import RAW
@testable import bedrock_ip

extension BedrockTestSuite {
	
	@Suite("BedrockTestSuite :: AddressV6Tests",
		.serialized
	)
	internal struct AddressV6Tests {
		
	}
}

/*final class AddressV6Tests {
    func testAddressV6Encoding() {
        let addressString = "2001:0db8:85a3:0000:0000:8a2e:0370:7334"
        let address = AddressV6(addressString)
        XCTAssertEqual(AddressV6(String(address!)), AddressV6(addressString))
    }
    
    func testInvalidAddressV6() {
        let invalidAddressString = "2001:0db8:85a3:!:8a2e:0370"
        let address = AddressV6(invalidAddressString)
        XCTAssertNil(address)
    }
    
    func testAddressV6Decoding() {
        let addressString = "2001:0db8:85a3:0000:0000:8a2e:0370:7334"
        let address = AddressV6(addressString)
        XCTAssertEqual(AddressV6(String(address!)), AddressV6(addressString))
    }

	func testAddressV6RangeUpperBound() {
		// let addy = AddressV6("fe80::1")!
		let rangeString = NetworkV6("fe80:fe80:fe80:fe80::1/64")!
		XCTAssertEqual(rangeString.range.upperBound, AddressV6("fe80:fe80:fe80:fe80:ffff:ffff:ffff:ffff"))
	}

	func testAddressV6RangeLowerBound() {
		// let addy = AddressV6("fe80::1")!
		let rangeString = NetworkV6("fe80:fe80:fe80:fe80::1/64")!
		XCTAssertEqual(rangeString.range.lowerBound, AddressV6("fe80:fe80:fe80:fe80:0000:0000:0000:0000"))
	}
}*/