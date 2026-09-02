// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Translator",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Translator",
            targets: ["Translator"]
        )
    ],
    dependencies: [
        // Zero external third-party dependencies!
        // Pure Swift standard library + Foundation + SwiftUI + AVFoundation + AppKit.
    ],
    targets: [
        .executableTarget(
            name: "Translator",
            dependencies: [],
            path: "Sources/Translator"
        ),
        .testTarget(
            name: "TranslatorTests",
            dependencies: ["Translator"],
            path: "Tests/TranslatorTests"
        )
    ]
)
