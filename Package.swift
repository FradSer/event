// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "event",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "event", targets: ["event"]),
    .executable(name: "event-sync", targets: ["event-sync"]),
    .library(name: "EventModels", targets: ["EventModels"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    .package(url: "https://github.com/swift-server/async-http-client", from: "1.21.0"),
  ],
  targets: [
    .target(
      name: "EventModels",
      path: "Sources/EventModels"
    ),
    .target(
      name: "EventSync",
      dependencies: [
        "EventModels",
        .product(name: "AsyncHTTPClient", package: "async-http-client"),
      ],
      path: "Sources/EventSync"
    ),
    .target(
      name: "EventCommands",
      dependencies: [
        "EventModels",
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
    .executableTarget(
      name: "event-sync",
      dependencies: [
        "EventModels",
        "EventSync",
        "EventCommands",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      path: "Sources/event-sync",
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
  ]
)
