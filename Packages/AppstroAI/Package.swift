// swift-tools-version: 6.0
import PackageDescription

let package = Package(
	name: "AppstroAI",
	platforms: [
		.macOS(.v15)
	],
	products: [
		.library(
			name: "AppstroAI",
			targets: ["AppstroAI"]),
	],
	dependencies: [
		.package(path: "../AppstroCore"),
		.package(url: "https://github.com/teunlao/swift-ai-sdk", from: "0.1.0"),
	],
	targets: [
		.target(
			name: "AppstroAI",
			dependencies: [
				"AppstroCore",
				.product(name: "SwiftAISDK", package: "swift-ai-sdk"),
				.product(name: "OpenAIProvider", package: "swift-ai-sdk"),
				.product(name: "AnthropicProvider", package: "swift-ai-sdk"),
				.product(name: "GoogleProvider", package: "swift-ai-sdk"),
			]
		),
		.testTarget(
			name: "AppstroAITests",
			dependencies: ["AppstroAI"]),
	]
)
