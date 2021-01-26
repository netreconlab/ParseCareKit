// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ParseCareKit",
    platforms: [.iOS(.v13), .watchOS(.v6), .macOS(.v10_13), .tvOS(.v11)],
    products: [
        .library(
            name: "ParseCareKit",
            targets: ["ParseCareKit"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/carekit-apple/CareKit.git",
                 .revision("56796e8c7915b5813a47f54d746219a29685cb81")),
        .package(url: "https://github.com/parse-community/Parse-Swift", from: "1.1.1")
    ],
    targets: [
        .target(
            name: "ParseCareKit",
            dependencies: ["ParseSwift", "CareKitStore"]),
        .testTarget(
            name: "ParseCareKitTests",
            dependencies: ["ParseCareKit"])
    ]
)
