// swift-tools-version:5.3
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
        .package(name: "CareKit", url: "https://github.com/carekit-apple/CareKit.git",
                 .revision("7dfcdef4de7e91449e86ac963043b44188a6ba31")),
        .package(name: "ParseSwift", url: "https://github.com/parse-community/Parse-Swift", from: "1.1.2")
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
