// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Odometer",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "OdometerCore", swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(
            name: "Odometer",
            dependencies: ["OdometerCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "OdometerTests",
            dependencies: ["OdometerCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
