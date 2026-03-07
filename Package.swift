// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "event",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "event", targets: ["event"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "event",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/event",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"]),
            ]
        ),
    ]
)
