// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MCUDisplay",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MCUDisplay", targets: ["MCUDisplayApp"])
    ],
    targets: [
        .target(name: "MCUDisplayCore"),
        .executableTarget(name: "MCUDisplayApp", dependencies: ["MCUDisplayCore"]),
        .testTarget(name: "MCUDisplayCoreTests", dependencies: ["MCUDisplayCore"])
    ]
)
