// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "AnyLLM",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        // One-line umbrella: re-exports everything.
        .library(name: "AnyLLM", targets: ["AnyLLM"]),
        // Pure data layer, zero dependencies & zero UI.
        .library(name: "AnyLLMCore", targets: ["AnyLLMCore"]),
        // SwiftUI configuration components.
        .library(name: "AnyLLMUI", targets: ["AnyLLMUI"]),
    ],
    targets: [
        .target(
            name: "AnyLLMCore",
            resources: [.process("Resources")]
        ),
        .target(
            name: "AnyLLMStore",
            dependencies: ["AnyLLMCore"]
        ),
        .target(
            name: "AnyLLMClient",
            dependencies: ["AnyLLMCore"]
        ),
        .target(
            name: "AnyLLMUI",
            dependencies: ["AnyLLMCore", "AnyLLMStore", "AnyLLMClient"]
        ),
        .target(
            name: "AnyLLM",
            dependencies: ["AnyLLMCore", "AnyLLMStore", "AnyLLMClient", "AnyLLMUI"]
        ),
        .testTarget(
            name: "AnyLLMTests",
            dependencies: ["AnyLLM"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
