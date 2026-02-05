// swift-tools-version: 6.0
import PackageDescription

let package = Package(
	name: "AppstroASC",
	platforms: [
		.macOS(.v15)
	],
	products: [
		.library(
			name: "AppstroASC",
			targets: ["AppstroASC"]),
	],
	dependencies: [
		.package(path: "../AppstroCore"),
		.package(url: "https://github.com/AvdLee/appstoreconnect-swift-sdk.git", from: "4.0.0"),
	],
	targets: [
		.target(
			name: "AppstroASC",
			dependencies: [
				"AppstroCore",
				.product(name: "AppStoreConnect-Swift-SDK", package: "appstoreconnect-swift-sdk"),
			]
		),
		.testTarget(
			name: "AppstroASCTests",
			dependencies: ["AppstroASC"]),
	]
)
