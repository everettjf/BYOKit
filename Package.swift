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
    traits: [
        // Opt-in heavy local backends. Enabling one propagates the matching
        // trait to AnyLanguageModel. Default enables none, so the base library
        // and CI stay light.
        .trait(name: "MLX", description: "On-device MLX models (Apple Silicon) via AnyLanguageModel."),
        .trait(name: "Llama", description: "On-device llama.cpp / GGUF models via AnyLanguageModel."),
        .default(enabledTraits: []),
    ],
    dependencies: [
        // Only pulled in if you depend on BYOKitClientAnyLanguageModel.
        // BYOKit's MLX/Llama traits propagate to AnyLanguageModel's; with neither
        // enabled the dependency stays light (no MLX / llama.cpp).
        .package(
            url: "https://github.com/huggingface/AnyLanguageModel.git",
            from: "0.8.0",
            traits: [
                .trait(name: "MLX", condition: .when(traits: ["MLX"])),
                .trait(name: "Llama", condition: .when(traits: ["Llama"])),
            ]
        ),
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
            dependencies: ["BYOKitCore"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "BYOKitUI",
            dependencies: ["BYOKitCore", "BYOKitStore", "BYOKitClient"],
            resources: [.process("Resources")]
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
