// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "BYOKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        // One-line umbrella: re-exports everything.
        .library(name: "BYOKit", targets: ["BYOKit"]),
        // Pure data layer, zero dependencies & zero UI.
        .library(name: "BYOKitCore", targets: ["BYOKitCore"]),
        // SwiftUI configuration components.
        .library(name: "BYOKitUI", targets: ["BYOKitUI"]),
    ],
    targets: [
        .target(
            name: "BYOKitCore",
            resources: [.process("Resources")]
        ),
        .target(
            name: "BYOKitStore",
            dependencies: ["BYOKitCore"]
        ),
        .target(
            name: "BYOKitClient",
            dependencies: ["BYOKitCore"]
        ),
        .target(
            name: "BYOKitUI",
            dependencies: ["BYOKitCore", "BYOKitStore", "BYOKitClient"]
        ),
        .target(
            name: "BYOKit",
            dependencies: ["BYOKitCore", "BYOKitStore", "BYOKitClient", "BYOKitUI"]
        ),
        .testTarget(
            name: "BYOKitTests",
            dependencies: ["BYOKit"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
