import Testing

extension Tag {
	@Tag internal static var __cbedrock:Self
	@Tag internal static var bedrock:Self
}

// cbedrock test suite
@Suite("__cbedrock_test_suite",
	.serialized,
	.tags(.__cbedrock)
)
internal struct __cbedrock_test_suite {}

// bedrock test suite
@Suite("bedrock_test_suite",
	.serialized,
	.tags(.bedrock)
)
internal struct BedrockTestSuite {}