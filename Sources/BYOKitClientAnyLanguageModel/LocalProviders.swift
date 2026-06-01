import Foundation
import BYOKitCore

public extension ProviderID {
    /// On-device MLX models (Apple Silicon). Requires the `MLX` trait.
    static let mlx: ProviderID = "mlx"
    /// On-device llama.cpp / GGUF models. Requires the `Llama` trait.
    static let llama: ProviderID = "llama"
}

/// Key under which the llama provider stores the local `.gguf` file path.
public let byokLlamaModelPathField = "modelPath"

public extension Provider {
    /// On-device MLX provider. The selected model id is a Hugging Face repo id
    /// (e.g. `mlx-community/Qwen3-0.6B-4bit`), downloaded on first use.
    /// Serviced by `AnyLanguageModelClient` only when built with the `MLX` trait.
    static var mlx: Provider {
        Provider(
            id: .mlx,
            displayName: "MLX (on-device)",
            kind: .local,
            apiFormat: .custom,
            appearance: .init(symbolName: "cpu", monogram: "MLX", tintHex: "#0B84FF"),
            defaultBaseURL: nil,
            allowsCustomBaseURL: false,
            credential: .init(requiresAPIKey: false, keyDisplayName: "API Key"),
            onboarding: .init(
                docsURL: URL(string: "https://github.com/ml-explore/mlx-swift"),
                steps: [
                    .init(id: 1, text: "Runs on-device on Apple Silicon — no API key, no cost.", symbolName: "lock.shield"),
                    .init(id: 2, text: "Pick or type a Hugging Face MLX model id; it downloads on first use.", symbolName: "arrow.down.circle"),
                    .init(id: 3, text: "Requires your app to enable the MLX trait on BYOKit.", symbolName: "gearshape"),
                ],
                notes: ["Enable BYOKit's \"MLX\" trait in your app to activate this backend."]
            ),
            models: .init(
                presets: [
                    ModelInfo(id: "mlx-community/Qwen3-0.6B-4bit", displayName: "Qwen3 0.6B (4-bit)"),
                    ModelInfo(id: "mlx-community/Llama-3.2-3B-Instruct-4bit", displayName: "Llama 3.2 3B Instruct (4-bit)"),
                    ModelInfo(id: "mlx-community/Mistral-7B-Instruct-v0.3-4bit", displayName: "Mistral 7B Instruct (4-bit)"),
                ],
                supportsDynamicListing: false
            )
        )
    }

    /// On-device llama.cpp provider. The model is a local `.gguf` file path,
    /// entered via the `modelPath` field. Serviced by `AnyLanguageModelClient`
    /// only when built with the `Llama` trait.
    static var llama: Provider {
        Provider(
            id: .llama,
            displayName: "llama.cpp (GGUF)",
            kind: .local,
            apiFormat: .custom,
            appearance: .init(symbolName: "shippingbox", monogram: "GGUF", tintHex: "#7A4DFF"),
            defaultBaseURL: nil,
            allowsCustomBaseURL: false,
            credential: .init(
                requiresAPIKey: false,
                keyDisplayName: "API Key",
                extraFields: [
                    CredentialField(id: byokLlamaModelPathField, label: "GGUF file path",
                                    isSecret: false, placeholder: "/path/to/model.gguf")
                ]
            ),
            onboarding: .init(
                docsURL: URL(string: "https://github.com/ggml-org/llama.cpp"),
                steps: [
                    .init(id: 1, text: "Runs on-device from a local GGUF file — no API key, no cost.", symbolName: "lock.shield"),
                    .init(id: 2, text: "Enter the full path to a .gguf model file.", symbolName: "doc"),
                    .init(id: 3, text: "Requires your app to enable the Llama trait on BYOKit.", symbolName: "gearshape"),
                ],
                notes: ["Enable BYOKit's \"Llama\" trait in your app to activate this backend."]
            ),
            models: .init(presets: [], supportsDynamicListing: false)
        )
    }
}
