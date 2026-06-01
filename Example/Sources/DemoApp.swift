import SwiftUI
import AnyLLM

/// Minimal host app demonstrating AnyLLM. The entire BYOK configuration
/// experience is `AnyLLMSettingsView()` — everything else here is host chrome.
///
/// `ANYLLM_DEMO` env var selects a screen for demos/screenshots:
/// `list` (default), `list-seeded`, `picker`, `form`, `onboarding`.
@main
struct AnyLLMDemoApp: App {
    @StateObject private var store: ConfigurationStore

    init() {
        let store = ConfigurationStore(
            credentials: InMemoryCredentialStore(),
            persistence: InMemoryConfigurationPersistence()
        )
        if ProcessInfo.processInfo.environment["ANYLLM_DEMO"] == "list-seeded" {
            try? store.add(LLMConfiguration(providerID: .openAI, displayName: "OpenAI · Work", selectedModelID: "gpt-4o"), apiKey: "sk-demo123456789")
            try? store.add(LLMConfiguration(providerID: .anthropic, displayName: "Claude", selectedModelID: "claude-sonnet-4-5"), apiKey: "sk-ant-demo")
            try? store.add(LLMConfiguration(providerID: .ollama, displayName: "Local Ollama", selectedModelID: "llama3.2"))
        }
        _store = StateObject(wrappedValue: store)
    }

    var body: some Scene {
        WindowGroup {
            DemoRootView()
                .environmentObject(store)
                .anyLLMClient(DefaultLLMClient())
                .anyLLMTheme(AnyLLMTheme(cornerRadius: 14))
        }
        #if os(macOS)
        .defaultSize(width: 760, height: 680)
        #endif
    }
}

struct DemoRootView: View {
    @State private var providers: [Provider] = []
    private var screen: String { ProcessInfo.processInfo.environment["ANYLLM_DEMO"] ?? "list" }

    var body: some View {
        Group {
            switch screen {
            case "picker":
                NavigationStack { ProviderPickerView(providers: providers) { _ in } }
            case "form":
                if let openai = providers.first(where: { $0.id == .openAI }) {
                    NavigationStack { ProviderConfigForm(provider: openai) { _, _ in } }
                }
            case "onboarding":
                if let openai = providers.first(where: { $0.id == .openAI }) {
                    OnboardingGuideView(provider: openai)
                }
            default:
                AnyLLMSettingsView()
            }
        }
        .task {
            providers = await ProviderRegistry.shared.all()
        }
    }
}
