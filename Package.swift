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
        .package(name: "CareKit", url: "https://github.com/cbaker6/CareKit.git",
                 .revision("52f6b4e6734d49124db54c83f552a6a1c3e26469")),
        .package(name: "ParseSwift", url: "https://github.com/parse-community/Parse-Swift.git", 
                 .revision("a828f829517b6cc480561b3f693fe71ee8f7bdb0"))
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
