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
        .package(url: "https://github.com/carekit-apple/CareKit.git",
            .upToNextMajor(from: "3.0.1-beta.2")),
        .package(url: "https://github.com/netreconlab/Parse-Swift.git",
            .upToNextMajor(from: "5.8.1"))
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
