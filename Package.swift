// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "window-scaling-kit",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "WindowScalingKit",
            targets: ["WindowScalingKit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Akazm/ax-kit", .upToNextMajor(from: "1.2.2")),
        .package(url: "https://github.com/apple/swift-async-algorithms", .upToNextMajor(from: "1.0.4")),
        .package(url: "https://github.com/nicklockwood/SwiftFormat", .upToNextMajor(from: "0.55.0")),
        .package(url: "https://github.com/swhitty/swift-mutex", .upToNextMajor(from: "0.0.5")),
        .package(url: "https://github.com/apple/swift-atomics.git", .upToNextMajor(from: "1.2.0")),
    ],
    targets: [
        .target(
            name: "WindowScalingKit",
            dependencies: [
                .product(
                    name: "AsyncAlgorithms",
                    package: "swift-async-algorithms",
                    condition: .when(platforms: [.macOS])
                ),
                .product(
                    name: "AXKit",
                    package: "ax-kit",
                    condition: .when(platforms: [.macOS])
                ),
                .product(
                    name: "Mutex",
                    package: "swift-mutex",
                    condition: .when(platforms: [.macOS])
                ),
                .product(
                    name: "Atomics",
                    package: "swift-atomics",
                    condition: .when(platforms: [.macOS])
                )
            ]
        )
    ]
)
