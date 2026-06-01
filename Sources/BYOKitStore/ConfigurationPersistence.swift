import Foundation
import BYOKitCore

/// Persists the (non-secret) list of `LLMConfiguration`s. Secrets never pass
/// through here — they live in a `CredentialStore`.
public protocol ConfigurationPersistence: Sendable {
    func load() -> [LLMConfiguration]
    func save(_ configurations: [LLMConfiguration])
}

/// Stores configurations as JSON in `UserDefaults`.
public struct UserDefaultsConfigurationPersistence: ConfigurationPersistence {
    public let defaults: UserDefaults
    public let key: String

    public init(defaults: UserDefaults = .standard, key: String = "com.byokit.configurations") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> [LLMConfiguration] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([LLMConfiguration].self, from: data)) ?? []
    }

    public func save(_ configurations: [LLMConfiguration]) {
        guard let data = try? JSONEncoder().encode(configurations) else { return }
        defaults.set(data, forKey: key)
    }
}

/// In-memory persistence for tests and previews.
public final class InMemoryConfigurationPersistence: ConfigurationPersistence, @unchecked Sendable {
    private let lock = NSLock()
    private var configs: [LLMConfiguration]

    public init(_ configs: [LLMConfiguration] = []) { self.configs = configs }

    public func load() -> [LLMConfiguration] {
        lock.lock(); defer { lock.unlock() }
        return configs
    }
    public func save(_ configurations: [LLMConfiguration]) {
        lock.lock(); defer { lock.unlock() }
        configs = configurations
    }
}
