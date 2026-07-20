// swift-tools-version: 5.10

import PackageDescription

let package = Package(
  name: "GreekKeyboardViewer",
  defaultLocalization: "en",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(name: "GreekKeyboardCore", targets: ["GreekKeyboardCore"]),
    .executable(name: "GreekKeyboardViewer", targets: ["GreekKeyboardViewer"])
  ],
  targets: [
    .target(
      name: "GreekKeyboardCore",
      resources: [.process("Resources")]
    ),
    .executableTarget(
      name: "GreekKeyboardViewer",
      dependencies: ["GreekKeyboardCore"]
    ),
    .testTarget(
      name: "GreekKeyboardCoreTests",
      dependencies: ["GreekKeyboardCore"]
    )
  ],
  swiftLanguageVersions: [.v5]
)
