// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OneDisplay",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "OneDisplayCore", targets: ["OneDisplayCore"]),
        .executable(name: "OneDisplayApp", targets: ["OneDisplayApp"]),
        .executable(name: "onedisplay", targets: ["OneDisplayCLI"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "OneDisplayCore",
            dependencies: [],
            path: "Sources/OneDisplayCore"
        ),
        .executableTarget(
            name: "OneDisplayApp",
            dependencies: ["OneDisplayCore"],
            path: "Sources/OneDisplayApp"
        ),
        .executableTarget(
            name: "OneDisplayCLI",
            dependencies: ["OneDisplayCore"],
            path: "Sources/OneDisplayCLI"
        ),
        .testTarget(
            name: "OneDisplayCoreTests",
            dependencies: ["OneDisplayCore"],
            path: "Tests/OneDisplayCoreTests"
        ),
    ]
)
