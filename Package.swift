// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "bedrock",
    platforms: [
    	.macOS(.v11)
    ],
    products: [
        .library(name:"bedrock", targets:["bedrock"]),
		.library(name:"bedrock_ip", targets:["bedrock_ip"]),
		.library(name:"bedrock_scheduler_service", targets:["bedrock_scheduler_service"])
    ],
    dependencies: [
        .package(url:"https://github.com/tannerdsilva/QuickLMDB.git", "5.0.0"..<"6.0.0"),
        .package(url:"https://github.com/tannerdsilva/rawdog.git", "11.0.0"..<"13.0.0"),
  		.package(url:"https://github.com/apple/swift-log.git", "1.0.0"..<"2.0.0"),
  		.package(url:"https://github.com/swift-server/swift-service-lifecycle.git", "2.4.0"..<"3.0.0")
    ],
    targets: [
		.target(name:"bedrock_ip", dependencies:[
			.product(name:"RAW", package:"rawdog"),
			.product(name:"QuickLMDB", package:"QuickLMDB")
		]),
		.target(name:"bedrock_scheduler_service", dependencies: [
			.product(name:"QuickLMDB", package:"QuickLMDB"),
			.product(name:"Logging", package:"swift-log"),
			.product(name:"ServiceLifecycle", package:"swift-service-lifecycle"),
			.product(name:"RAW", package:"rawdog"),
			"bedrock"
		]),
        .target(
            name: "bedrock",
            dependencies: [
            	.product(name:"RAW", package:"rawdog"),
            	.product(name:"Logging", package:"swift-log"),
            	"cbedrock"
            ]),
        .target(
        	name: "cbedrock"
        ),
        .testTarget(
            name: "bedrockTests",
            dependencies: ["bedrock", "cbedrock", "bedrock_ip"]),
    ]
)
