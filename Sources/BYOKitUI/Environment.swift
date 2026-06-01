import SwiftUI
import BYOKitCore
import BYOKitClient

// MARK: - Environment keys

private struct ClientKey: EnvironmentKey {
    static let defaultValue: any LLMClient = DefaultLLMClient()
}
private struct ThemeKey: EnvironmentKey {
    static let defaultValue = BYOKTheme.default
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
    var byokClient: any LLMClient {
        get { self[ClientKey.self] }
        set { self[ClientKey.self] = newValue }
    }
    var byokTheme: BYOKTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
    var byokRegistry: ProviderRegistry {
        get { self[RegistryKey.self] }
        set { self[RegistryKey.self] = newValue }
    }
    var byokProvidersOverride: [Provider]? {
        get { self[ProvidersOverrideKey.self] }
        set { self[ProvidersOverrideKey.self] = newValue }
    }
    var byokProviderFilter: ProviderFilter {
        get { self[ProviderFilterKey.self] }
        set { self[ProviderFilterKey.self] = newValue }
    }
    var byokShowsOnboarding: Bool {
        get { self[ShowsOnboardingKey.self] }
        set { self[ShowsOnboardingKey.self] = newValue }
    }
}

// MARK: - Public modifiers

public extension View {
    /// Inject the LLM client used for connection tests and model listing.
    func byokClient(_ client: any LLMClient) -> some View {
        environment(\.byokClient, client)
    }
    /// Theme the configuration UI to match the host app.
    func byokTheme(_ theme: BYOKTheme) -> some View {
        environment(\.byokTheme, theme)
    }
    /// Restrict which providers are offered (by filter).
    func byokProviders(_ filter: ProviderFilter) -> some View {
        environment(\.byokProviderFilter, filter)
    }
    /// Provide an explicit provider list (overrides the registry).
    func byokProviders(_ providers: [Provider]) -> some View {
        environment(\.byokProvidersOverride, providers)
    }
    /// Use a custom provider registry (e.g. one loaded from a remote OTA URL).
    func byokRegistry(_ registry: ProviderRegistry) -> some View {
        environment(\.byokRegistry, registry)
    }
    /// Show or hide the "where to get a key" onboarding affordances.
    func byokShowsOnboarding(_ shows: Bool) -> some View {
        environment(\.byokShowsOnboarding, shows)
    }
}
