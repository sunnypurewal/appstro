// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "appstro",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/yonaskolb/XcodeGen.git", from: "2.44.1"),
        .package(url: "https://github.com/kylef/PathKit.git", from: "1.0.1"),
        .package(url: "https://github.com/AvdLee/appstoreconnect-swift-sdk.git", from: "4.0.0"),
        .package(url: "https://github.com/teunlao/swift-ai-sdk", from: "0.1.0"),
    ],
    targets: [
        .executableTarget(
            name: "appstro",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "XcodeGenKit", package: "XcodeGen"),
                .product(name: "ProjectSpec", package: "XcodeGen"),
                .product(name: "PathKit", package: "PathKit"),
                .product(name: "AppStoreConnect-Swift-SDK", package: "appstoreconnect-swift-sdk"),
                .product(name: "SwiftAISDK", package: "swift-ai-sdk"),
                .product(name: "OpenAIProvider", package: "swift-ai-sdk"),
                .product(name: "AnthropicProvider", package: "swift-ai-sdk"),
                .product(name: "GoogleProvider", package: "swift-ai-sdk"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
    ]
)