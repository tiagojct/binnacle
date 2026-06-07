// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Binnacle",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Binnacle", targets: ["Binnacle"])
    ],
    targets: [
        .executableTarget(
            name: "Binnacle",
            path: "Sources/Binnacle",
            resources: [
                .process("Theme/Fonts")
            ]
        ),
        .testTarget(
            name: "BinnacleTests",
            dependencies: ["Binnacle"],
            path: "Tests/BinnacleTests"
        )
    ]
)
