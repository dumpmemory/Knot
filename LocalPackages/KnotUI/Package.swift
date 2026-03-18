// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KnotUI",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "KnotUI", targets: ["KnotUI"]),
    ],
    dependencies: [
        .package(path: "../KnotCore"),
    ],
    targets: [
        .target(
            name: "KnotUI",
            dependencies: ["KnotCore"]
        ),
        .testTarget(
            name: "KnotUITests",
            dependencies: ["KnotUI"]
        ),
    ]
)
