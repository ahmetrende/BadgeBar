// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BadgeBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "BadgeBar",
            path: "Sources/BadgeBar"
        )
    ],
    swiftLanguageModes: [.v5]
)
