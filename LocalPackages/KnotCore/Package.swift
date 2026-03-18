// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KnotCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "KnotCore", targets: ["KnotCore"]),
    ],
    dependencies: [
        .package(path: "../TunnelServices"),
    ],
    targets: [
        .target(
            name: "KnotCore",
            dependencies: ["TunnelServices"]
        ),
        .testTarget(
            name: "KnotCoreTests",
            dependencies: ["KnotCore"]
        ),
    ]
)
