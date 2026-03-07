// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OverlayApp",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "OverlayApp", targets: ["OverlayApp"]),
    ],
    targets: [
        .target(
            name: "OverlayCore",
            path: "Sources/OverlayCore"
        ),
        .executableTarget(
            name: "OverlayApp",
            dependencies: ["OverlayCore"],
            path: "Sources/OverlayApp"
        ),
        .testTarget(
            name: "OverlayAppTests",
            dependencies: ["OverlayCore"],
            path: "Tests/OverlayAppTests"
        ),
    ]
)
