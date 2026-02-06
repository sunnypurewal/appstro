// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "appstro",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "appstro", targets: ["appstro"]),
        .library(name: "AppstroCore", targets: ["AppstroCore"]),
        .library(name: "AppstroAI", targets: ["AppstroAI"]),
        .library(name: "AppstroASC", targets: ["AppstroASC"]),
        .library(name: "AppstroServices", targets: ["AppstroServices"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/teunlao/swift-ai-sdk", from: "0.1.0"),
        .package(url: "https://github.com/AvdLee/appstoreconnect-swift-sdk.git", from: "4.0.0"),
        .package(url: "https://github.com/yonaskolb/XcodeGen.git", from: "2.44.1"),
        .package(url: "https://github.com/tuist/XcodeProj.git", from: "8.27.7"),
        .package(url: "https://github.com/kylef/PathKit.git", from: "1.0.1"),
    ],
    targets: [
        // CLI
        .executableTarget(
            name: "appstro",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "AppstroCore",
                "AppstroASC",
                "AppstroAI",
                "AppstroServices",
            ]
        ),
        .testTarget(
            name: "appstroTests",
            dependencies: ["appstro"]
        ),

        // Core
        .target(
            name: "AppstroCore",
            dependencies: []
        ),
        .testTarget(
            name: "AppstroCoreTests",
            dependencies: ["AppstroCore"]
        ),

        // AI
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
            dependencies: ["AppstroAI"]
        ),

        // App Store Connect
        .target(
            name: "AppstroASC",
            dependencies: [
                "AppstroCore",
                .product(name: "AppStoreConnect-Swift-SDK", package: "appstoreconnect-swift-sdk"),
            ]
        ),
        .testTarget(
            name: "AppstroASCTests",
            dependencies: ["AppstroASC"]
        ),

        // Services
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
            dependencies: ["AppstroServices"]
        ),
    ]
)
