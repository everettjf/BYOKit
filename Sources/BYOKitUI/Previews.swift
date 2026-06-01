#if DEBUG
import SwiftUI
import BYOKitCore
import BYOKitStore
import BYOKitClient

// MARK: - Sample data

enum BYOKPreview {
    static let openAI = Provider(
        id: .openAI, displayName: "OpenAI", kind: .cloud, apiFormat: .openAI,
        appearance: .init(symbolName: "sparkles", monogram: "AI", tintHex: "#10A37F"),
        defaultBaseURL: URL(string: "https://api.openai.com/v1"),
        allowsCustomBaseURL: true,
        credential: .init(requiresAPIKey: true, validation: .init(prefix: "sk-", minLength: 20)),
        onboarding: .init(
            consoleURL: URL(string: "https://platform.openai.com/api-keys"),
            signUpURL: URL(string: "https://platform.openai.com/signup"),
            docsURL: URL(string: "https://platform.openai.com/docs"),
            pricingURL: URL(string: "https://openai.com/api/pricing"),
            steps: [
                .init(id: 1, text: "Sign in to the OpenAI platform.", symbolName: "person.crop.circle"),
                .init(id: 2, text: "Create a new secret key.", actionURL: URL(string: "https://platform.openai.com/api-keys"), symbolName: "key"),
                .init(id: 3, text: "Copy it and paste it here.", symbolName: "doc.on.clipboard"),
            ],
            notes: ["Requires a paid account with billing set up."]
        ),
        models: .init(presets: [
            ModelInfo(id: "gpt-4o", displayName: "GPT-4o", contextWindow: 128000, capabilities: [.vision, .tools]),
            ModelInfo(id: "o3", displayName: "o3", contextWindow: 200000, capabilities: [.reasoning, .tools]),
        ], supportsDynamicListing: true)
    )

    static let ollama = Provider(
        id: .ollama, displayName: "Ollama", kind: .local, apiFormat: .ollama,
        appearance: .init(symbolName: "desktopcomputer", monogram: "OL", tintHex: "#0A0A0A"),
        defaultBaseURL: URL(string: "http://localhost:11434"),
        allowsCustomBaseURL: true,
        credential: .init(requiresAPIKey: false),
        models: .init(presets: [ModelInfo(id: "llama3.2", displayName: "Llama 3.2")], supportsDynamicListing: true)
    )

    static let providers = [openAI, ollama]

    @MainActor
    static func store() -> ConfigurationStore {
        let store = ConfigurationStore(
            credentials: InMemoryCredentialStore(),
            persistence: InMemoryConfigurationPersistence(),
            activeIDDefaults: UserDefaults(suiteName: "byokit.preview")!
        )
        try? store.add(LLMConfiguration(providerID: .openAI, displayName: "My OpenAI", selectedModelID: "gpt-4o"), apiKey: "sk-demo")
        return store
    }

    /// A client that fakes responses so previews work offline.
    struct Client: LLMClient {
        func validate(_ resolved: ResolvedConfiguration) async throws -> ValidationResult {
            try? await Task.sleep(nanoseconds: 400_000_000)
            return ValidationResult(ok: true, latency: 0.21, detectedModels: resolved.provider.models.presets, message: "Connected. Found \(resolved.provider.models.presets.count) models.")
        }
        func listModels(_ resolved: ResolvedConfiguration) async throws -> [ModelInfo] {
            resolved.provider.models.presets
        }
        func complete(_ request: CompletionRequest, with resolved: ResolvedConfiguration) async throws -> CompletionResponse {
            CompletionResponse(text: "(preview response)", modelID: resolved.modelID)
        }
    }
}

// MARK: - Previews

#Preview("Settings") {
    BYOKSettingsView()
        .environmentObject(BYOKPreview.store())
        .byokProviders(BYOKPreview.providers)
        .byokClient(BYOKPreview.Client())
}

#Preview("Provider Picker") {
    NavigationStack {
        ProviderPickerView(providers: BYOKPreview.providers) { _ in }
    }
}

#Preview("Config Form") {
    NavigationStack {
        ProviderConfigForm(provider: BYOKPreview.openAI) { _, _ in }
    }
    .byokClient(BYOKPreview.Client())
}

#Preview("Onboarding Guide") {
    OnboardingGuideView(provider: BYOKPreview.openAI)
}

#Preview("Badges") {
    HStack(spacing: 12) {
        ProviderBadge(provider: BYOKPreview.openAI, size: 48)
        ProviderBadge(provider: BYOKPreview.ollama, size: 48)
    }
    .padding()
}
#endif
