import XCTest
@testable import BYOKitStore

/// Keychain access from an unsigned SwiftPM test binary can be unavailable on
/// some hosts; these tests skip gracefully rather than fail spuriously.
final class KeychainTests: XCTestCase {

    func testKeychainRoundTrip() throws {
        let store = KeychainCredentialStore(service: "com.byokit.tests.\(UUID().uuidString)")
        let id = UUID()
        do {
            try store.saveAPIKey("sk-keychain", for: id)
        } catch CredentialStoreError.unexpectedStatus(let status) {
            throw XCTSkip("Keychain unavailable in this environment (status \(status))")
        }

        XCTAssertEqual(try store.apiKey(for: id), "sk-keychain")

        // Overwrite.
        try store.saveAPIKey("sk-updated", for: id)
        XCTAssertEqual(try store.apiKey(for: id), "sk-updated")

        // Delete.
        try store.deleteSecrets(for: id)
        XCTAssertNil(try store.apiKey(for: id))
    }

    func testKeychainSeparatesFields() throws {
        let store = KeychainCredentialStore(service: "com.byokit.tests.\(UUID().uuidString)")
        let id = UUID()
        do {
            try store.saveSecret("primary", for: id, field: "apiKey")
        } catch CredentialStoreError.unexpectedStatus(let status) {
            throw XCTSkip("Keychain unavailable in this environment (status \(status))")
        }
        try store.saveSecret("extra", for: id, field: "deployment")
        XCTAssertEqual(try store.secret(for: id, field: "apiKey"), "primary")
        XCTAssertEqual(try store.secret(for: id, field: "deployment"), "extra")
        try store.deleteSecrets(for: id)
        XCTAssertNil(try store.secret(for: id, field: "deployment"))
    }
}
