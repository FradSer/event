// swift-tools-version: 6.2
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
    .package(
      url: "https://github.com/stephencelis/SQLite.swift", from: "0.15.3",
      traits: ["SQLiteSwiftCSQLite"]),
    .package(path: "../apple-sync-kit"),
  ],
  targets: [
    .target(
      name: "EventModels",
      dependencies: [
        .product(name: "AppleSyncKit", package: "apple-sync-kit")
      ],
      path: "Sources/EventModels"
    ),
    .target(
      name: "EventSync",
      dependencies: [
        "EventModels",
        .product(name: "AppleSyncKit", package: "apple-sync-kit"),
        .product(name: "SQLite", package: "SQLite.swift"),
      ],
      path: "Sources/EventSync"
    ),
    .target(
      name: "EventCommands",
      dependencies: [
        "EventModels",
        "EventSync",
        .product(name: "AppleSyncKit", package: "apple-sync-kit"),
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
        .product(name: "AppleSyncKit", package: "apple-sync-kit"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      path: "Sources/event",
      swiftSettings: [
        .unsafeFlags(["-parse-as-library"])
      ]
    ),
    .testTarget(
      name: "EventSyncTests",
      dependencies: [
        "EventSync",
        .product(name: "AppleSyncKit", package: "apple-sync-kit"),
      ],
      path: "Tests/EventSyncTests"
    ),
    .testTarget(
      name: "eventTests",
      dependencies: ["event"],
      path: "Tests/eventTests"
    ),
  ],
  swiftLanguageModes: [.v6]
)
