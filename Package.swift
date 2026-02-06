// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "CoreDataKit",
  platforms: [
    .iOS(.v15),
    .macOS(.v12),
    .tvOS(.v15),
    .watchOS(.v8),
  ],
  products: [
    .library(
      name: "CoreDataKit",
      targets: ["CoreDataKit"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/nts-sixblack/SwiftInjected.git", from: "1.0.0")
  ],
  targets: [
    .target(
      name: "CoreDataKit",
      dependencies: ["SwiftInjected"],
      path: "Sources"
    )
  ]
)
