// swift-tools-version: 5.10

import PackageDescription

let package = Package(
  name: "GreekboardViewer",
  defaultLocalization: "en",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(name: "GreekboardCore", targets: ["GreekboardCore"]),
    .executable(name: "GreekboardViewer", targets: ["GreekboardViewer"])
  ],
  targets: [
    .target(
      name: "GreekboardCore",
      path: "src/GreekboardCore",
      resources: [.process("Resources")]
    ),
    .executableTarget(
      name: "GreekboardViewer",
      dependencies: ["GreekboardCore"],
      path: "src/GreekboardViewer"
    ),
    .testTarget(
      name: "GreekboardCoreTests",
      dependencies: ["GreekboardCore"]
    )
  ],
  swiftLanguageVersions: [.v5]
)
