// swift-tools-version: 6.0
import PackageDescription

let package = Package(
	name: "AppstroCore",
	platforms: [
		.macOS(.v15)
	],
	products: [
		.library(
			name: "AppstroCore",
			targets: ["AppstroCore"]),
	],
	dependencies: [],
	targets: [
		.target(
			name: "AppstroCore",
			dependencies: []
		),
		.testTarget(
			name: "AppstroCoreTests",
			dependencies: ["AppstroCore"]),
	]
)