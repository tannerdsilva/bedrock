// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "bedrock",
    platforms: [
    	.macOS(.v11)
    ],
    products: [
        .library(
            name: "bedrock",
            targets: ["bedrock"]),
		.library(name:"bedrock-ipaddress", targets: ["bedrock-ipaddress"])
    ],
    dependencies: [
        .package(url:"https://github.com/tannerdsilva/QuickLMDB.git", from:"2.1.0"),
        .package(url:"https://github.com/tannerdsilva/rawdog.git", from:"8.0.1"),
  		.package(url:"https://github.com/apple/swift-argument-parser.git", from:"1.0.0"),
  		.package(url:"https://github.com/apple/swift-log.git", from:"1.0.0"),
  		.package(url:"https://github.com/swift-server/swift-service-lifecycle.git", from:"2.4.0")
    ],
    targets: [
		.target(name:"bedrock-ipaddress", dependencies: [
			.product(name:"RAW", package:"rawdog")
		]),
		// .target("bedrock-date", dependencies: ["RAW"])
        .target(
            name: "bedrock",
            dependencies: [
            	"QuickLMDB",
            	.product(name:"RAW", package:"rawdog"),
            	.product(name:"ArgumentParser", package:"swift-argument-parser"),
            	.product(name:"Logging", package:"swift-log"),
            	.product(name:"ServiceLifecycle", package:"swift-service-lifecycle"),
            	"cbedrock"
            ]),
        .target(
        	name: "cbedrock"
        ),
        .testTarget(
            name: "bedrockTests",
            dependencies: ["bedrock", "cbedrock", "bedrock-ipaddress"]),
    ]
)
