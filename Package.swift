// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ParseCareKit",
    platforms: [.iOS(.v13), .macOS(.v10_15), .tvOS(.v13), .watchOS(.v6)],
    products: [
        .library(
            name: "ParseCareKit",
            targets: ["ParseCareKit"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(name: "CareKit", url: "https://github.com/carekit-apple/CareKit.git",
                 .revision("a612482e4ba4f28d4c75129c0a9b70ca23098bd6")),
        .package(name: "ParseSwift", url: "https://github.com/parse-community/Parse-Swift", .revision("a828f829517b6cc480561b3f693fe71ee8f7bdb0x"))
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
