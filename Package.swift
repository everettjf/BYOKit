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
        // Optional adapter adding on-device Apple Foundation Models via AnyLanguageModel.
        .library(name: "BYOKitClientAnyLanguageModel", targets: ["BYOKitClientAnyLanguageModel"]),
    ],
    dependencies: [
        // Only pulled in if you depend on BYOKitClientAnyLanguageModel.
        // Default traits are empty (light); enable MLX/Llama/CoreML traits in your
        // own app's dependency edge to extend local-model support.
        .package(url: "https://github.com/huggingface/AnyLanguageModel.git", from: "0.8.0"),
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
        .target(
            name: "BYOKitClientAnyLanguageModel",
            dependencies: [
                "BYOKitCore",
                "BYOKitClient",
                .product(name: "AnyLanguageModel", package: "AnyLanguageModel"),
            ]
        ),
        .testTarget(
            name: "BYOKitTests",
            dependencies: ["BYOKit", "BYOKitClientAnyLanguageModel"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
