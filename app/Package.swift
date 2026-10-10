// swift-tools-version:5.9
import PackageDescription

var products: [Product] = [
    .library(name: "GecitCore", targets: ["GecitCore"]),
]

var targets: [Target] = [
    .target(
        name: "GecitCore",
        path: "Sources/GecitCore"
    ),
    .testTarget(
        name: "GecitCoreTests",
        dependencies: ["GecitCore"],
        path: "Tests/GecitCoreTests"
    ),
]

// Arayüz (SwiftUI) yalnızca macOS'ta derlenir.
#if os(macOS)
products.append(.executable(name: "Gecit", targets: ["Gecit"]))
targets.append(
    .executableTarget(
        name: "Gecit",
        dependencies: ["GecitCore"],
        path: "Sources/Gecit"
    )
)
#endif

let package = Package(
    name: "Gecit",
    platforms: [.macOS(.v13)],
    products: products,
    targets: targets
)
