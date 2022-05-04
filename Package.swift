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
        .package(name: "CareKit", url: "https://github.com/cbaker6/CareKit.git",
                 .revision("ebffa9a52fc03c368399344d2931600892795fa2")),
        .package(url: "https://github.com/parse-community/Parse-Swift.git",
                 .upToNextMajor(from: "4.3.1"))
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
