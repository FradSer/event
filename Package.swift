// swift-tools-version: 6.1
import PackageDescription

let package = Package(
  name: "event",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "event", targets: ["event"]),
    .library(name: "EventModels", targets: ["EventModels"]),
    .library(name: "EventSync", targets: ["EventSync"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    .package(url: "https://github.com/swift-server/async-http-client", from: "1.21.0"),
    .package(url: "https://github.com/apple/swift-crypto", from: "3.0.0"),
    .package(
      url: "https://github.com/stephencelis/SQLite.swift", from: "0.15.3",
      traits: ["SQLiteSwiftCSQLite"]),
  ],
  targets: [
    .target(
      name: "EventModels",
      dependencies: [
        .product(name: "Crypto", package: "swift-crypto")
      ],
      path: "Sources/EventModels"
    ),
    .target(
      name: "EventSync",
      dependencies: [
        "EventModels",
        .product(name: "AsyncHTTPClient", package: "async-http-client"),
        .product(name: "SQLite", package: "SQLite.swift"),
      ],
      path: "Sources/EventSync"
    ),
    .target(
      name: "EventCommands",
      dependencies: [
        "EventModels",
        "EventSync",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      path: "Sources/EventCommands"
    ),
    .executableTarget(
      name: "event",
      dependencies: [
        "EventModels",
        "EventSync",
        "EventCommands",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      path: "Sources/event",
      swiftSettings: [
        .unsafeFlags(["-parse-as-library"])
      ]
    ),
    .testTarget(
      name: "EventModelsTests",
      dependencies: ["EventModels"],
      path: "Tests/EventModelsTests"
    ),
    .testTarget(
      name: "EventSyncTests",
      dependencies: ["EventSync"],
      path: "Tests/EventSyncTests"
    ),
    .testTarget(
      name: "eventTests",
      dependencies: ["event"],
      path: "Tests/eventTests"
    ),
  ],
  swiftLanguageModes: [.v5]
)
