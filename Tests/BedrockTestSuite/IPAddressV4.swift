import Testing
@testable import RAW
@testable import bedrock_ip

extension BedrockTestSuite {
	@Suite("BedrockTestSuite :: AddressV4Tests",
		.serialized
	)
	internal struct AddressV4Tests {
		@Test("AddressV4Tests :: encoding")
		func testEncoding() {
			let addressString:String = "192.168.0.1"
			let address = AddressV4(addressString)
			#expect(String(address!) == addressString)
		}
		
		@Test("AddressV4Tests :: invalid init input")
		func testInitWithInvalidString() {
			let invalidAddressString = "192.168.0"
			let address = AddressV4(invalidAddressString)
			#expect(address == nil)
		}
		
		@Test("AddressV4Tests :: decoding")
		func decoding() {
			let addressString = "192.168.0.1"
			let address = AddressV4(addressString)
			#expect(String(address!) == addressString)
		}
		
		@Test("AddressVTests :: range")
		func rangeTest() {
			let rangeString = NetworkV4("192.168.1.1/24")!
			#expect(String(rangeString.range.upperBound) == "192.168.1.255")
		}
	}
}