// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "event",
  platforms: [.macOS(.v15)],
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
      dependencies: [
        .product(name: "AsyncHTTPClient", package: "async-http-client")
      ],
      path: "Sources/EventModels",
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .target(
      name: "EventCommands",
      dependencies: [
        "EventModels",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      path: "Sources/EventCommands",
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .executableTarget(
      name: "event",
      dependencies: [
        "EventModels",
        "EventCommands",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      path: "Sources/event",
      swiftSettings: [
        .unsafeFlags(["-parse-as-library"]),
        .swiftLanguageMode(.v5),
      ]
    ),
    .executableTarget(
      name: "event-sync",
      dependencies: [
        "EventModels",
        "EventCommands",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      path: "Sources/event-sync",
      swiftSettings: [
        .unsafeFlags(["-parse-as-library"]),
        .swiftLanguageMode(.v5),
      ]
    ),
    .testTarget(
      name: "EventModelsTests",
      dependencies: ["EventModels"],
      path: "Tests/EventModelsTests",
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .testTarget(
      name: "eventTests",
      dependencies: ["event"],
      path: "Tests/eventTests",
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
  ]
)
