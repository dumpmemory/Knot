// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SwiftLsquic",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "SwiftLsquic", targets: ["SwiftLsquic"]),
    ],
    targets: [
        .binaryTarget(
            name: "CLsquic",
            path: "../../Frameworks/CLsquic.xcframework"
        ),
        .target(
            name: "SwiftLsquic",
            dependencies: ["CLsquic"]
        ),
    ]
)
