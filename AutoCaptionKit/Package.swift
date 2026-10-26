// swift-tools-version:5.9
import PackageDescription

// SubtitleCore è puro Foundation (compila e si testa anche su Linux).
// SubtitleEngine (WhisperKit + AVFoundation) e SubtitleUI (SwiftUI) esistono solo su macOS.

#if os(macOS)
let package = Package(
    name: "AutoCaptionKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SubtitleCore", targets: ["SubtitleCore"]),
        .library(name: "SubtitleEngine", targets: ["SubtitleEngine"]),
        .library(name: "SubtitleUI", targets: ["SubtitleUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "1.0.0"),
    ],
    targets: [
        .target(name: "SubtitleCore"),
        .target(
            name: "SubtitleEngine",
            dependencies: ["SubtitleCore", .product(name: "WhisperKit", package: "WhisperKit")]
        ),
        .target(name: "SubtitleUI", dependencies: ["SubtitleCore", "SubtitleEngine"]),
        .testTarget(name: "SubtitleCoreTests", dependencies: ["SubtitleCore"]),
    ]
)
#else
let package = Package(
    name: "AutoCaptionKit",
    products: [
        .library(name: "SubtitleCore", targets: ["SubtitleCore"]),
    ],
    targets: [
        .target(name: "SubtitleCore"),
        .testTarget(name: "SubtitleCoreTests", dependencies: ["SubtitleCore"]),
    ]
)
#endif
