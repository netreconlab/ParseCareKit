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
        .package(url: "https://github.com/carekit-apple/CareKit.git",
                 revision: "a612482e4ba4f28d4c75129c0a9b70ca23098bd6"),
        .package(url: "https://github.com/cbaker6/Parse-Swift.git",
                 revision: "1a0d2352413328ae751f180228b3b5a58f43ecd4")
        // .package(url: "https://github.com/parse-community/Parse-Swift.git",
        //          .upToNextMajor(from: "4.9.0"))
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
