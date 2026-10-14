// swift-tools-version:6.3
import PackageDescription

let package = Package(
	name: "bedrock",
	platforms:[
		.macOS(.v15)
	],
	products: [
		.library(name:"bedrock", targets:["bedrock"]),
		.library(name:"bedrock_ip", targets:["bedrock_ip"]),
		.library(name:"bedrock_future", targets:["bedrock_future"]),
		.library(name:"bedrock_fifo", targets:["bedrock_fifo"]),
		.library(name:"bedrock_pthread", targets:["bedrock_pthread"]),
		.library(name:"bedrock_pathwatch", targets:["bedrock_pathwatch"])
	],
	dependencies:[
		.package(url:"https://github.com/tannerdsilva/rawdog.git", "22.0.0"..<"23.0.0"),
		.package(url:"https://github.com/apple/swift-log.git", "1.0.0"..<"2.0.0")
	],
	targets:[
		.target(
			name:"bedrock",
			dependencies: [
				.product(name:"RAW", package:"rawdog"),
				.product(name:"Logging", package:"swift-log"),
			]
		),
		.target(
			name:"bedrock_ip",
			dependencies: [
				.product(name:"RAW", package:"rawdog"),
				"__cbedrock_ip"
			]
		),
		.target(
			name:"__cbedrock_ip",
			dependencies: [],
			publicHeadersPath:"."
		),
		.target(
			name:"bedrock_fifo",
			dependencies:[
				"bedrock_oneshot_latch"
			]
		),
		.target(
			name:"bedrock_oneshot_latch",
			dependencies:[]
		),
		.target(
			name:"bedrock_future",
			dependencies:[
				"bedrock_oneshot_latch"
			]
		),
		.target(
			name:"bedrock_pthread",
			dependencies:[
				"bedrock_future",
				"__cbedrock_threads"
			]
		),
		.target(
			name:"bedrock_pathwatch",
			dependencies:[
				"bedrock",
				"bedrock_fifo",
				"bedrock_future",
				"bedrock_pthread",
				"__cbedrock_pathwatch"
			]
		),
		.target(
			name:"__cbedrock_types",
			publicHeadersPath:"."
		),
		.target(
			name:"__cbedrock_threads",
			dependencies:[
				"__cbedrock_types"
			],
			publicHeadersPath:"."
		),
		.target(
			name:"__cbedrock_pathwatch",
			dependencies:[
				"__cbedrock_types"
			],
			publicHeadersPath:"."
		),
		.testTarget(
			name: "BedrockTestSuite",
			dependencies:[
				"bedrock",
				"bedrock_ip",
				"bedrock_fifo",
				"bedrock_future",
				"bedrock_oneshot_latch",
				"bedrock_pthread",
				"bedrock_pathwatch",
				"__cbedrock_threads",
				"__cbedrock_pathwatch"
			]
		)
	]
)
