// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SwiftQuiche",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SwiftQuiche", targets: ["SwiftQuiche"]),
    ],
    targets: [
        .binaryTarget(
            name: "CQuiche",
            path: "../../Frameworks/CQuiche.xcframework"
        ),
        .target(
            name: "SwiftQuiche",
            dependencies: ["CQuiche"]
        ),
    ]
)
