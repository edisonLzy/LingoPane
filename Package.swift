// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LingoPane",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "LingoPane", targets: ["LingoPane"])
    ],
    targets: [
        .executableTarget(
            name: "LingoPane",
            path: "Sources/LingoPane"
        ),
        .testTarget(
            name: "LingoPaneTests",
            dependencies: ["LingoPane"],
            path: "Tests/LingoPaneTests"
        )
    ]
)
