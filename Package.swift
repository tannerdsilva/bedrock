// swift-tools-version:6.0
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
		.library(name:"bedrock_fifo", targets:["bedrock_fifo"])
    ],
    dependencies:[
        .package(url:"https://github.com/tannerdsilva/QuickLMDB.git", "9.0.0"..<"10.0.0"),
        .package(url:"https://github.com/tannerdsilva/rawdog.git", "16.0.0"..<"18.0.0"),
  		.package(url:"https://github.com/apple/swift-log.git", "1.0.0"..<"2.0.0"),
  		.package(url:"https://github.com/swift-server/swift-service-lifecycle.git", "2.7.0"..<"3.0.0")
    ],
    targets: [
        .target(
            name:"bedrock",
            dependencies:[
            	.product(name:"RAW", package:"rawdog"),
            	.product(name:"Logging", package:"swift-log"),
            ]
        ),
		.target(name:"bedrock_ip", dependencies:[
			.product(name:"RAW", package:"rawdog"),
			.product(name:"QuickLMDB", package:"QuickLMDB")
		]),
		.target(
			name:"bedrock_contained"
		),
		.target(
			name:"bedrock_nasyncstream",
			dependencies:[
				"__cbedrock_fifo",
				"__cbedrock_identified_list",
				"bedrock_fifo"
			]
		),
		.target(
			name:"bedrock_fifo",
			dependencies:[
				"__cbedrock_fifo",
				"bedrock_contained"
			]
		),
		.target(
			name:"bedrock_identified_list",
			dependencies:[
				"__cbedrock_identified_list",
				"bedrock_contained"
			]
		),
		.target(
			name:"bedrock_future",
			dependencies:[
				"__cbedrock_future",
				"bedrock_contained"
			]
		),
		.target(
			name:"bedrock_pthread",
			dependencies:[
				"bedrock_future",
				"__cbedrock_threads",
				"bedrock_contained"
			]
		),
		.target(
			name:"__cbedrock_types",
			publicHeadersPath:"."
		),
		.target(
			name:"__cbedrock_identified_list",
			dependencies:[
				"__cbedrock_types"
			],
			publicHeadersPath:"."
		),
		.target(
			name:"__cbedrock_future",
			dependencies:[
				"__cbedrock_types",
				"__cbedrock_identified_list"
			],
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
			name:"__cbedrock_fifo",
			dependencies:[
				"__cbedrock_types"
			],
			publicHeadersPath:"."
		),
        .testTarget(
            name: "BedrockTestSuite",
            dependencies: [
            	"bedrock",
            	"bedrock_ip",
            	"bedrock_future",
            	"bedrock_contained",
            	"bedrock_pthread",
            	"__cbedrock_identified_list",
            	"__cbedrock_future",
            	"__cbedrock_threads",
            	"__cbedrock_fifo"
            ]
        ),
    ]
)
