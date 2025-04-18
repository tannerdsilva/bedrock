import Testing
@testable import RAW
@testable import bedrock_ip

extension BedrockTestSuite {
	@Suite("BedrockTestSuite :: AddressV6Tests",
		.serialized
	)
	internal struct AddressV6Tests {
		@Test("AddressV6Tests :: encoding")
		func testEncoding() {
			let addressString = "2001:0db8:85a3:0000:0000:8a2e:0370:7334"
			let address = AddressV6(addressString)
			#expect(AddressV6(String(address!)) == AddressV6(addressString))
		}
		
		@Test("AddressV6Tests :: invalid init input")
		func testInvalidInit() {
			let invalidAddressString = "2001:0db8:85a3:!:8a2e:0370"
			let address = AddressV6(invalidAddressString)
			#expect(address == nil)
		}
		
		@Test("AddressV6Tests :: decoding") 
		func testDecoding() {
			let addressString = "2001:0db8:85a3:0000:0000:8a2e:0370:7334"
			let address = AddressV6(addressString)
			#expect(AddressV6(String(address!)) == AddressV6(addressString))
		}
		
		@Test("AddressV6Tests :: range upper boundary")
		func rangeLower() {
			let rangeString = NetworkV6("fe80:fe80:fe80:fe80::1/64")!
			#expect(rangeString.range.lowerBound == AddressV6("fe80:fe80:fe80:fe80:0000:0000:0000:0000"))
		}
		
		@Test("AddressV6Tests :: range lower boundary")
		func rangeUpper() {
			let rangeString = NetworkV6("fe80:fe80:fe80:fe80::1/64")!
			#expect(rangeString.range.upperBound == AddressV6("fe80:fe80:fe80:fe80:ffff:ffff:ffff:ffff"))
		}
	}
}