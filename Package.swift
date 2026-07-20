// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Spotlight",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Spotlight", targets: ["Spotlight"])],
    targets: [
        .executableTarget(name: "Spotlight"),
        .testTarget(name: "SpotlightTests", dependencies: ["Spotlight"]),
    ],
    swiftLanguageModes: [.v5]
)
