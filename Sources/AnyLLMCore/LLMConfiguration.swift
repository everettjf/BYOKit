import Foundation

/// A user-created configuration instance: "my OpenAI work key", "my home Ollama".
///
/// Secrets are **not** stored here — they live in the Keychain, keyed by `id`.
public struct LLMConfiguration: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    public var providerID: ProviderID
    /// User-editable alias, supports multiple configs for the same provider.
    public var displayName: String
    /// Overrides the provider's default base URL when set.
    public var baseURL: URL?
    public var selectedModelID: String?
    /// Non-secret extra field values (secret ones go to the Keychain).
    public var extraValues: [String: String]
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        providerID: ProviderID,
        displayName: String,
        baseURL: URL? = nil,
        selectedModelID: String? = nil,
        extraValues: [String: String] = [:],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.providerID = providerID
        self.displayName = displayName
        self.baseURL = baseURL
        self.selectedModelID = selectedModelID
        self.extraValues = extraValues
        self.isEnabled = isEnabled
    }

    /// The base URL to actually use: explicit override, else the provider default.
    public func resolvedBaseURL(for provider: Provider) -> URL? {
        baseURL ?? provider.defaultBaseURL
    }
}
