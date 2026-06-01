import SwiftUI
import AnyLLMCore
import AnyLLMClient

// MARK: - Environment keys

private struct ClientKey: EnvironmentKey {
    static let defaultValue: any LLMClient = DefaultLLMClient()
}
private struct ThemeKey: EnvironmentKey {
    static let defaultValue = AnyLLMTheme.default
}
private struct RegistryKey: EnvironmentKey {
    static let defaultValue = ProviderRegistry.shared
}
private struct ProvidersOverrideKey: EnvironmentKey {
    static let defaultValue: [Provider]? = nil
}
private struct ProviderFilterKey: EnvironmentKey {
    static let defaultValue: ProviderFilter = .all
}
private struct ShowsOnboardingKey: EnvironmentKey {
    static let defaultValue = true
}

public extension EnvironmentValues {
    var anyLLMClient: any LLMClient {
        get { self[ClientKey.self] }
        set { self[ClientKey.self] = newValue }
    }
    var anyLLMTheme: AnyLLMTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
    var anyLLMRegistry: ProviderRegistry {
        get { self[RegistryKey.self] }
        set { self[RegistryKey.self] = newValue }
    }
    var anyLLMProvidersOverride: [Provider]? {
        get { self[ProvidersOverrideKey.self] }
        set { self[ProvidersOverrideKey.self] = newValue }
    }
    var anyLLMProviderFilter: ProviderFilter {
        get { self[ProviderFilterKey.self] }
        set { self[ProviderFilterKey.self] = newValue }
    }
    var anyLLMShowsOnboarding: Bool {
        get { self[ShowsOnboardingKey.self] }
        set { self[ShowsOnboardingKey.self] = newValue }
    }
}

// MARK: - Public modifiers

public extension View {
    /// Inject the LLM client used for connection tests and model listing.
    func anyLLMClient(_ client: any LLMClient) -> some View {
        environment(\.anyLLMClient, client)
    }
    /// Theme the configuration UI to match the host app.
    func anyLLMTheme(_ theme: AnyLLMTheme) -> some View {
        environment(\.anyLLMTheme, theme)
    }
    /// Restrict which providers are offered (by filter).
    func anyLLMProviders(_ filter: ProviderFilter) -> some View {
        environment(\.anyLLMProviderFilter, filter)
    }
    /// Provide an explicit provider list (overrides the registry).
    func anyLLMProviders(_ providers: [Provider]) -> some View {
        environment(\.anyLLMProvidersOverride, providers)
    }
    /// Use a custom provider registry (e.g. one loaded from a remote OTA URL).
    func anyLLMRegistry(_ registry: ProviderRegistry) -> some View {
        environment(\.anyLLMRegistry, registry)
    }
    /// Show or hide the "where to get a key" onboarding affordances.
    func anyLLMShowsOnboarding(_ shows: Bool) -> some View {
        environment(\.anyLLMShowsOnboarding, shows)
    }
}
