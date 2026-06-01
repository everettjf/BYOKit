import Foundation
import Combine
import AnyLLMCore

/// The app-facing source of truth for BYOK configurations.
///
/// Owns the list of `LLMConfiguration`s, the active selection, and brokers
/// secret access through a `CredentialStore`. Observable for SwiftUI.
@MainActor
public final class ConfigurationStore: ObservableObject {
    @Published public private(set) var configurations: [LLMConfiguration]
    @Published public var activeConfigurationID: UUID? {
        didSet { persistActiveID() }
    }

    public let credentials: CredentialStore
    private let persistence: ConfigurationPersistence
    private let activeIDDefaults: UserDefaults
    private let activeIDKey: String

    public init(
        credentials: CredentialStore = KeychainCredentialStore(),
        persistence: ConfigurationPersistence = UserDefaultsConfigurationPersistence(),
        activeIDDefaults: UserDefaults = .standard,
        activeIDKey: String = "com.anyllm.activeConfigurationID"
    ) {
        self.credentials = credentials
        self.persistence = persistence
        self.activeIDDefaults = activeIDDefaults
        self.activeIDKey = activeIDKey
        self.configurations = persistence.load()
        if let raw = activeIDDefaults.string(forKey: activeIDKey) {
            self.activeConfigurationID = UUID(uuidString: raw)
        }
        normalizeActiveSelection()
    }

    // MARK: - Queries

    public var activeConfiguration: LLMConfiguration? {
        guard let id = activeConfigurationID else { return nil }
        return configurations.first { $0.id == id }
    }

    public func configuration(_ id: UUID) -> LLMConfiguration? {
        configurations.first { $0.id == id }
    }

    public func apiKey(for id: UUID) -> String? {
        try? credentials.apiKey(for: id)
    }

    // MARK: - Mutations

    /// Adds a configuration and stores its secret. Becomes active if it's the first.
    public func add(_ config: LLMConfiguration, apiKey: String? = nil, secrets: [String: String] = [:]) throws {
        try credentials.saveAPIKey(apiKey, for: config.id)
        for (field, value) in secrets {
            try credentials.saveSecret(value, for: config.id, field: field)
        }
        configurations.append(config)
        persist()
        if activeConfigurationID == nil { activeConfigurationID = config.id }
    }

    /// Updates an existing configuration's non-secret fields.
    public func update(_ config: LLMConfiguration) {
        guard let idx = configurations.firstIndex(where: { $0.id == config.id }) else { return }
        configurations[idx] = config
        persist()
    }

    /// Updates the API key for a configuration (pass nil/empty to clear).
    public func setAPIKey(_ key: String?, for id: UUID) throws {
        try credentials.saveAPIKey(key, for: id)
    }

    public func setSecret(_ value: String?, field: String, for id: UUID) throws {
        try credentials.saveSecret(value, for: id, field: field)
    }

    /// Removes a configuration and all of its secrets.
    public func remove(_ id: UUID) {
        try? credentials.deleteSecrets(for: id)
        configurations.removeAll { $0.id == id }
        persist()
        if activeConfigurationID == id { normalizeActiveSelection() }
    }

    public func remove(atOffsets offsets: IndexSet) {
        for index in offsets { remove(configurations[index].id) }
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        // Manual reorder so this layer stays free of SwiftUI.
        let moving = source.sorted().map { configurations[$0] }
        var remaining = configurations
        for index in source.sorted(by: >) { remaining.remove(at: index) }
        let insertionIndex = destination - source.filter { $0 < destination }.count
        remaining.insert(contentsOf: moving, at: max(0, min(insertionIndex, remaining.count)))
        configurations = remaining
        persist()
    }

    // MARK: - Internals

    private func persist() { persistence.save(configurations) }

    private func persistActiveID() {
        if let id = activeConfigurationID {
            activeIDDefaults.set(id.uuidString, forKey: activeIDKey)
        } else {
            activeIDDefaults.removeObject(forKey: activeIDKey)
        }
    }

    /// Ensures the active selection points at an existing, enabled config.
    private func normalizeActiveSelection() {
        if let id = activeConfigurationID, configurations.contains(where: { $0.id == id }) {
            return
        }
        activeConfigurationID = configurations.first(where: { $0.isEnabled })?.id ?? configurations.first?.id
    }
}
