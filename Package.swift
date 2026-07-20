// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "ArrowTune",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "ArrowTuneCore", targets: ["ArrowTuneCore"]),
    ],
    targets: [
        .target(
            name: "ArrowTuneCore",
            path: "Sources/ArrowTuneCore"
        ),
        .target(
            name: "ArrowTuneAppLogic",
            dependencies: ["ArrowTuneCore"],
            path: "Sources/ArrowTuneApp",
            sources: ["AppState.swift", "ProStore.swift"]
        ),
        .testTarget(
            name: "ArrowTuneCoreTests",
            dependencies: ["ArrowTuneCore"],
            path: "Tests/ArrowTuneCoreTests"
        ),
        .testTarget(
            name: "ArrowTuneAppTests",
            dependencies: ["ArrowTuneAppLogic", "ArrowTuneCore"],
            path: "Tests/ArrowTuneAppTests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
