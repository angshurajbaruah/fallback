// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FallbackCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "FallbackCore", targets: ["FallbackCore"])],
    targets: [
        .target(name: "FallbackCore"),
        .testTarget(name: "FallbackCoreTests", dependencies: ["FallbackCore"]),
    ]
)
