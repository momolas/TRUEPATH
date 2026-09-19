// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BallisticsKit",
    platforms: [.iOS(.v18), .macOS(.v15), .watchOS(.v11)],
    products: [
        .library(
            name: "BallisticsKit",
            targets: ["Ballistics"]
        ),
        .library(
            name: "Ballistics",
            targets: ["Ballistics"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Ballistics",
            dependencies: []
        ),
        .testTarget(
            name: "BallisticsTests",
            dependencies: [
                "Ballistics"
            ]
        ),
    ]
)
