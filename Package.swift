// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ParseCareKit",
    platforms: [.iOS(.v13), .watchOS(.v6), .macOS(.v10_13), .tvOS(.v13)],
    products: [
        .library(
            name: "ParseCareKit",
            targets: ["ParseCareKit"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(name: "CareKit", url: "https://github.com/carekit-apple/CareKit.git",
                 .revision("4d9200e0b2ad68e6d2c8502f10971200bccf8863")),
        .package(name: "ParseSwift", url: "https://github.com/parse-community/Parse-Swift", from: "1.1.3")
    ],
    targets: [
        .target(
            name: "ParseCareKit",
            dependencies: ["ParseSwift", .product(name: "CareKitStore", package: "CareKit")]),
        .testTarget(
            name: "ParseCareKitTests",
            dependencies: ["ParseCareKit"])
    ]
)
