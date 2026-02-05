// swift-tools-version: 6.0
import PackageDescription

let package = Package(
	name: "appstro",
	platforms: [
		.macOS(.v15)
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
		.package(path: "../Packages/AppstroCore"),
		.package(path: "../Packages/AppstroASC"),
		.package(path: "../Packages/AppstroAI"),
		.package(path: "../Packages/AppstroServices"),
	],
	targets: [
		.executableTarget(
			name: "appstro",
			dependencies: [
				.product(name: "ArgumentParser", package: "swift-argument-parser"),
				"AppstroCore",
				"AppstroASC",
				"AppstroAI",
				"AppstroServices",
			],
			path: "Sources"
		),
	]
)
