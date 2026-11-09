// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MarqueeGlow",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MarqueeGlow", targets: ["MarqueeGlow"]),
    ],
    targets: [
        .target(name: "MarqueeGlow"),
        .testTarget(name: "MarqueeGlowTests", dependencies: ["MarqueeGlow"]),
    ]
)
