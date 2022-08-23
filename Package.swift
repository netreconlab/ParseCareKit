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
                 revision: "adca4ac261b265e4fb7ded5a88e14deaed39592c"),
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
