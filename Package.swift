// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "ParseCareKit",
    platforms: [.iOS(.v13), .watchOS(.v6)],
    products: [
        .library(
            name: "ParseCareKit",
            targets: ["ParseCareKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/cbaker6/CareKit.git",
                 .upToNextMajor(from: "2.1.8")),
        .package(url: "https://github.com/netreconlab/Parse-Swift.git", revision: "912c978112dca63922b35cb8aa07f2e23df5e589")
            //.upToNextMajor(from: "5.0.0"))
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
