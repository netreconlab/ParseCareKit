// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "ParseCareKit",
    platforms: [.iOS(.v14), .macOS(.v13), .watchOS(.v7)],
    products: [
        .library(
            name: "ParseCareKit",
            targets: ["ParseCareKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/cbaker6/CareKit.git",
            .upToNextMajor(from: "3.0.0-beta.14")),
        .package(url: "https://github.com/netreconlab/Parse-Swift.git",
            .upToNextMajor(from: "5.10.3"))
    ],
    targets: [
        .target(
            name: "ParseCareKit",
            dependencies: [
                .product(name: "ParseSwift", package: "Parse-Swift"),
                .product(name: "CareKitStore", package: "CareKit")]),
        .testTarget(
            name: "ParseCareKitTests",
            dependencies: ["ParseCareKit"])
    ]
)
