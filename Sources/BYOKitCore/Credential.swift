import Foundation

/// Describes what credentials a provider needs and how to validate them locally.
public struct CredentialSpec: Hashable, Sendable, Codable {
    /// `false` for local providers like Ollama that need no key.
    public var requiresAPIKey: Bool
    /// User-facing label, e.g. "API Key", "Token".
    public var keyDisplayName: String
    /// Optional local validation rules (prefix / regex / length).
    public var validation: KeyValidation?
    /// Extra non-secret (or secret) fields some providers need, e.g. Azure deployment.
    public var extraFields: [CredentialField]

    public init(
        requiresAPIKey: Bool = true,
        keyDisplayName: String = "API Key",
        validation: KeyValidation? = nil,
        extraFields: [CredentialField] = []
    ) {
        self.requiresAPIKey = requiresAPIKey
        self.keyDisplayName = keyDisplayName
        self.validation = validation
        self.extraFields = extraFields
    }
}

/// Cheap, offline validation of a key's *shape* (not its validity on the server).
public struct KeyValidation: Hashable, Sendable, Codable {
    public var prefix: String?
    public var regex: String?
    public var minLength: Int?

    public init(prefix: String? = nil, regex: String? = nil, minLength: Int? = nil) {
        self.prefix = prefix
        self.regex = regex
        self.minLength = minLength
    }

    /// Returns `nil` if the trimmed key looks structurally valid, otherwise a reason.
    public func reasonInvalid(for rawKey: String) -> String? {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.isEmpty { return L("The key is empty.") }
        if let prefix, !prefix.isEmpty, !key.hasPrefix(prefix) {
            return L("Expected the key to start with \"\(prefix)\".")
        }
        if let minLength, key.count < minLength {
            return L("The key looks too short.")
        }
        if let regex, !regex.isEmpty {
            if key.range(of: regex, options: .regularExpression) == nil {
                return L("The key format doesn't look right.")
            }
        }
        return nil
    }
}

/// An additional configuration field (e.g. Azure resource name / deployment id).
public struct CredentialField: Identifiable, Hashable, Sendable, Codable {
    public var id: String
    public var label: String
    public var isSecret: Bool
    public var placeholder: String?
    public var isRequired: Bool

    public init(id: String, label: String, isSecret: Bool = false, placeholder: String? = nil, isRequired: Bool = true) {
        self.id = id
        self.label = label
        self.isSecret = isSecret
        self.placeholder = placeholder
        self.isRequired = isRequired
    }
}
