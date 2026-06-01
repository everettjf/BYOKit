import Foundation
import AnyLLMCore

/// Stores and retrieves secret values (API keys, secret extra fields) for a
/// configuration. The default implementation is the Keychain.
public protocol CredentialStore: Sendable {
    func saveSecret(_ value: String?, for configID: UUID, field: String) throws
    func secret(for configID: UUID, field: String) throws -> String?
    func deleteSecrets(for configID: UUID) throws
}

public extension CredentialStore {
    /// Convenience for the primary API key field.
    static var apiKeyField: String { "apiKey" }

    func saveAPIKey(_ value: String?, for configID: UUID) throws {
        try saveSecret(value, for: configID, field: Self.apiKeyField)
    }
    func apiKey(for configID: UUID) throws -> String? {
        try secret(for: configID, field: Self.apiKeyField)
    }
}

public enum CredentialStoreError: Error, Sendable {
    case unexpectedStatus(OSStatus)
    case dataEncoding
}
