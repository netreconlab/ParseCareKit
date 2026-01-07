// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "ParseCareKit",
    platforms: [.iOS("18.0"), .macOS("15.0"), .watchOS("11.0")],
    products: [
        .library(
            name: "ParseCareKit",
            targets: ["ParseCareKit"]
		)
    ],
    dependencies: [
        .package(
			url: "https://github.com/cbaker6/CareKit.git",
            .upToNextMajor(from: "4.0.7")
		),
        .package(
			url: "https://github.com/netreconlab/Parse-Swift.git",
            .upToNextMajor(from: "6.0.0-beta.1")
		),
		.package(
			url: "https://github.com/netreconlab/CareKitEssentials.git",
			.upToNextMajor(from: "2.0.0")
		)
    ],
    targets: [
        .target(
            name: "ParseCareKit",
            dependencies: [
                .product(name: "ParseSwift", package: "Parse-Swift"),
                .product(name: "CareKitStore", package: "CareKit"),
				.product(name: "CareKitEssentials", package: "CareKitEssentials")
			]
		),
        .testTarget(
            name: "ParseCareKitTests",
            dependencies: ["ParseCareKit"]
		)
    ]
)
