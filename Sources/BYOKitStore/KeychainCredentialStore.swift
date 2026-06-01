import Foundation
import BYOKitCore
#if canImport(Security)
import Security
#endif

/// Keychain-backed `CredentialStore` using generic password items.
///
/// Each secret is stored under account `"<configID>/<field>"` within a single
/// service. Optionally shares an access group so app extensions can read keys.
public struct KeychainCredentialStore: CredentialStore {
    /// When a stored key is readable. Mirrors the relevant `kSecAttrAccessible*` classes.
    public enum Accessibility: Sendable {
        case afterFirstUnlock
        case afterFirstUnlockThisDeviceOnly
        case whenUnlocked
        case whenUnlockedThisDeviceOnly

        var cfValue: CFString {
            switch self {
            case .afterFirstUnlock: return kSecAttrAccessibleAfterFirstUnlock
            case .afterFirstUnlockThisDeviceOnly: return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            case .whenUnlocked: return kSecAttrAccessibleWhenUnlocked
            case .whenUnlockedThisDeviceOnly: return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            }
        }
    }

    public let service: String
    public let accessGroup: String?
    /// Accessibility class for stored items. Default keeps keys available after
    /// first unlock (good for background use) without syncing to iCloud.
    public let accessibility: Accessibility

    public init(
        service: String = "com.byokit.credentials",
        accessGroup: String? = nil,
        accessibility: Accessibility = .afterFirstUnlockThisDeviceOnly
    ) {
        self.service = service
        self.accessGroup = accessGroup
        self.accessibility = accessibility
    }

    private func account(_ configID: UUID, _ field: String) -> String {
        "\(configID.uuidString)/\(field)"
    }

    private func baseQuery(account: String) -> [String: Any] {
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if let accessGroup { q[kSecAttrAccessGroup as String] = accessGroup }
        return q
    }

    public func saveSecret(_ value: String?, for configID: UUID, field: String) throws {
        let account = account(configID, field)

        // A nil/empty value clears the item.
        guard let value, !value.isEmpty else {
            try deleteItem(account: account)
            return
        }
        guard let data = value.data(using: .utf8) else {
            throw CredentialStoreError.dataEncoding
        }

        let query = baseQuery(account: account)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility.cfValue,
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        switch status {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var add = query
            add.merge(attributes) { _, new in new }
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw CredentialStoreError.unexpectedStatus(addStatus)
            }
        default:
            throw CredentialStoreError.unexpectedStatus(status)
        }
    }

    public func secret(for configID: UUID, field: String) throws -> String? {
        var query = baseQuery(account: account(configID, field))
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data, let string = String(data: data, encoding: .utf8) else {
                return nil
            }
            return string
        case errSecItemNotFound:
            return nil
        default:
            throw CredentialStoreError.unexpectedStatus(status)
        }
    }

    public func deleteSecrets(for configID: UUID) throws {
        // Delete every item whose account begins with this configID.
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
        query[kSecMatchLimit as String] = kSecMatchLimitAll
        query[kSecReturnAttributes as String] = true

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let items = result as? [[String: Any]] else {
            if status == errSecItemNotFound { return }
            throw CredentialStoreError.unexpectedStatus(status)
        }
        let prefix = "\(configID.uuidString)/"
        for item in items {
            guard let account = item[kSecAttrAccount as String] as? String,
                  account.hasPrefix(prefix) else { continue }
            try deleteItem(account: account)
        }
    }

    private func deleteItem(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialStoreError.unexpectedStatus(status)
        }
    }
}
