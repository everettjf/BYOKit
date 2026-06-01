import Foundation

/// What a model can do — used for filtering and badges in the model picker.
public enum ModelCapability: String, Hashable, Sendable, Codable, CaseIterable {
    case vision
    case tools
    case reasoning
    case audio
}

/// A single selectable model.
public struct ModelInfo: Identifiable, Hashable, Sendable, Codable {
    public var id: String
    public var displayName: String
    public var contextWindow: Int?
    public var capabilities: Set<ModelCapability>

    public init(
        id: String,
        displayName: String? = nil,
        contextWindow: Int? = nil,
        capabilities: Set<ModelCapability> = []
    ) {
        self.id = id
        self.displayName = displayName ?? id
        self.contextWindow = contextWindow
        self.capabilities = capabilities
    }
}

/// The set of models a provider offers: curated presets + whether we can fetch live.
public struct ModelCatalog: Hashable, Sendable, Codable {
    public var presets: [ModelInfo]
    /// Whether the provider exposes a `/models` (or equivalent) listing endpoint.
    public var supportsDynamicListing: Bool

    public init(presets: [ModelInfo] = [], supportsDynamicListing: Bool = false) {
        self.presets = presets
        self.supportsDynamicListing = supportsDynamicListing
    }
}
