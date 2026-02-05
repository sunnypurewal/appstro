// swift-tools-version: 6.0
import PackageDescription

let package = Package(
	name: "AppstroServices",
	platforms: [
		.macOS(.v15)
	],
	products: [
		.library(
			name: "AppstroServices",
			targets: ["AppstroServices"]),
	],
	dependencies: [
		.package(path: "../AppstroCore"),
		.package(url: "https://github.com/yonaskolb/XcodeGen.git", from: "2.44.1"),
		.package(url: "https://github.com/tuist/XcodeProj.git", from: "8.27.7"),
		.package(url: "https://github.com/kylef/PathKit.git", from: "1.0.1"),
	],
	targets: [
		.target(
			name: "AppstroServices",
			dependencies: [
				"AppstroCore",
				.product(name: "XcodeGenKit", package: "XcodeGen"),
				.product(name: "ProjectSpec", package: "XcodeGen"),
				.product(name: "XcodeProj", package: "XcodeProj"),
				.product(name: "PathKit", package: "PathKit"),
			],
			resources: [
				.process("Resources")
			]
		),
		.testTarget(
			name: "AppstroServicesTests",
			dependencies: ["AppstroServices"]),
	]
)