import Foundation

/// Stable identifier for a provider, e.g. `"openai"`, `"anthropic"`.
public struct ProviderID: RawRepresentable, Hashable, Sendable, Codable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
    public var description: String { rawValue }

    public static let openAI: ProviderID = "openai"
    public static let anthropic: ProviderID = "anthropic"
    public static let gemini: ProviderID = "gemini"
    public static let deepSeek: ProviderID = "deepseek"
    public static let openRouter: ProviderID = "openrouter"
    public static let groq: ProviderID = "groq"
    public static let mistral: ProviderID = "mistral"
    public static let xAI: ProviderID = "xai"
    public static let ollama: ProviderID = "ollama"
    public static let custom: ProviderID = "custom"
}

/// Whether a provider runs in the cloud, locally, or is a generic OpenAI-compatible endpoint.
public enum ProviderKind: String, Hashable, Sendable, Codable, CaseIterable {
    case cloud
    case local
    case compatible
}

/// The wire format a provider speaks. Drives request building & response parsing.
public enum APIFormat: String, Hashable, Sendable, Codable {
    case openAI = "openai"
    case anthropic
    case gemini
    case ollama
    case custom
}

/// A provider definition. This is *data* — adding a provider means adding one of
/// these (typically via `providers.json`), not writing code.
public struct Provider: Identifiable, Hashable, Sendable, Codable {
    public var id: ProviderID
    public var displayName: String
    public var kind: ProviderKind
    public var apiFormat: APIFormat
    public var appearance: ProviderAppearance
    public var defaultBaseURL: URL?
    public var allowsCustomBaseURL: Bool
    public var credential: CredentialSpec
    public var onboarding: Onboarding
    public var models: ModelCatalog

    public init(
        id: ProviderID,
        displayName: String,
        kind: ProviderKind,
        apiFormat: APIFormat,
        appearance: ProviderAppearance,
        defaultBaseURL: URL? = nil,
        allowsCustomBaseURL: Bool = false,
        credential: CredentialSpec,
        onboarding: Onboarding = .init(),
        models: ModelCatalog = .init()
    ) {
        self.id = id
        self.displayName = displayName
        self.kind = kind
        self.apiFormat = apiFormat
        self.appearance = appearance
        self.defaultBaseURL = defaultBaseURL
        self.allowsCustomBaseURL = allowsCustomBaseURL
        self.credential = credential
        self.onboarding = onboarding
        self.models = models
    }
}

/// Visual identity for a provider. We ship no binary logos; a tinted rounded
/// badge with a monogram (or SF Symbol) renders cleanly across platforms.
public struct ProviderAppearance: Hashable, Sendable, Codable {
    /// Optional SF Symbol name shown inside the badge.
    public var symbolName: String?
    /// 1–3 letter monogram used when no symbol is set, e.g. "AI", "GPT".
    public var monogram: String?
    /// Brand tint as a hex string, e.g. "#10A37F".
    public var tintHex: String

    public init(symbolName: String? = nil, monogram: String? = nil, tintHex: String = "#5B5BD6") {
        self.symbolName = symbolName
        self.monogram = monogram
        self.tintHex = tintHex
    }
}
