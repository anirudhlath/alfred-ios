// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AlfredKit",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "AlfredKit", targets: ["AlfredKit"]),
    ],
    targets: [
        .target(
            name: "AlfredKit",
            path: "Sources/AlfredKit"
        ),
        .testTarget(
            name: "AlfredKitTests",
            dependencies: ["AlfredKit"],
            path: "Tests/AlfredKitTests"
        ),
    ]
)
