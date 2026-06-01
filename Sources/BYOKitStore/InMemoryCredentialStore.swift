import Foundation
import BYOKitCore

/// Non-persistent credential store for tests, SwiftUI previews, and demos.
public final class InMemoryCredentialStore: CredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: String] = [:]

    public init() {}

    private func key(_ configID: UUID, _ field: String) -> String {
        "\(configID.uuidString)/\(field)"
    }

    public func saveSecret(_ value: String?, for configID: UUID, field: String) throws {
        lock.lock(); defer { lock.unlock() }
        let k = key(configID, field)
        if let value, !value.isEmpty { storage[k] = value } else { storage[k] = nil }
    }

    public func secret(for configID: UUID, field: String) throws -> String? {
        lock.lock(); defer { lock.unlock() }
        return storage[key(configID, field)]
    }

    public func deleteSecrets(for configID: UUID) throws {
        lock.lock(); defer { lock.unlock() }
        let prefix = "\(configID.uuidString)/"
        for k in storage.keys where k.hasPrefix(prefix) { storage[k] = nil }
    }
}
