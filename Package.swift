// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "ParseCareKit",
    platforms: [.iOS(.v16), .macOS(.v14), .watchOS(.v10)],
    products: [
        .library(
            name: "ParseCareKit",
            targets: ["ParseCareKit"]
		)
    ],
    dependencies: [
        .package(
			url: "https://github.com/cbaker6/CareKit.git",
            .upToNextMajor(from: "3.1.3")
		),
        .package(
			url: "https://github.com/netreconlab/Parse-Swift.git",
            .upToNextMajor(from: "5.12.3")
		),
		.package(
			url: "https://github.com/netreconlab/CareKitEssentials.git",
			.upToNextMajor(from: "1.1.4")
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
