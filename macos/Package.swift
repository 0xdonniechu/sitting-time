// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SittingTime",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "SittingTime", targets: ["SittingTime"]),
    ],
    targets: [
        .target(name: "SittingCore"),
        .executableTarget(
            name: "SittingTime",
            dependencies: ["SittingCore"]
        ),
        .testTarget(
            name: "SittingTimeTests",
            dependencies: ["SittingCore"]
        ),
    ]
)
