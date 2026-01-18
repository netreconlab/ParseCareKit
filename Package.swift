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
			url: "https://github.com/netreconlab/Parse-Swift.git",
            .upToNextMajor(from: "6.0.0")
		),
		.package(
			url: "https://github.com/netreconlab/CareKitEssentials.git",
			.upToNextMajor(from: "2.0.4")
		)
    ],
    targets: [
        .target(
            name: "ParseCareKit",
            dependencies: [
                .product(name: "ParseSwift", package: "Parse-Swift"),
				.product(name: "CareKitEssentials", package: "CareKitEssentials")
			]
		),
        .testTarget(
            name: "ParseCareKitTests",
            dependencies: ["ParseCareKit"]
		)
    ]
)
