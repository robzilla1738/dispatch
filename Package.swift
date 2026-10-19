// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Dispatch",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Dispatch", targets: ["DispatchApp"]),
        .executable(name: "DispatchTests", targets: ["DispatchTests"]),
        .library(name: "DispatchCore", targets: ["DispatchCore"]),
    ],
    targets: [
        .target(name: "DispatchCore"),
        .target(name: "DispatchServices", dependencies: ["DispatchCore"]),
        .executableTarget(
            name: "DispatchApp",
            dependencies: ["DispatchCore", "DispatchServices"],
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "DispatchTests",
            dependencies: ["DispatchCore", "DispatchServices"]
        ),
    ]
)
