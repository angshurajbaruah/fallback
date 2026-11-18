// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FallbackCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "FallbackCore", targets: ["FallbackCore"])],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.11.1"), // pinned (PRD 11.4)
    ],
    targets: [
        .target(name: "FallbackCore", dependencies: [.product(name: "GRDB", package: "GRDB.swift")]),
        .testTarget(name: "FallbackCoreTests", dependencies: ["FallbackCore"]),
    ]
)
