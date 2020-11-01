// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ParseCareKit",
    platforms: [.iOS(.v13), .watchOS(.v6), .macOS(.v10_13), .tvOS(.v11)],
    products: [
        .library(
            name: "ParseCareKit",
            targets: ["ParseCareKit"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/carekit-apple/CareKit.git", .branch("main")),
        .package(url: "https://github.com/parse-community/Parse-Swift.git", .branch("main")),
    ],
    targets: [
        .target(
            name: "ParseCareKit",
            dependencies: ["ParseSwift", "CareKitStore"]),
        .testTarget(
            name: "ParseCareKitTests",
            dependencies: ["ParseCareKit"]),
    ]
)

#if os(watchOS)
//if ProcessInfo.processInfo.environment["TARGETING_WATCHOS"] == "true" {
  package.targets.removeAll(where: { $0.isTest })
//}
#endif
