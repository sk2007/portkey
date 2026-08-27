// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Portkey",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Portkey",
            targets: ["Portkey"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Portkey",
            path: "Sources/Portkey"
        ),
        .testTarget(
            name: "PortkeyTests",
            dependencies: ["Portkey"],
            path: "Tests/PortkeyTests"
        )
    ]
)
