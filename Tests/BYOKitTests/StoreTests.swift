import XCTest
@testable import BYOKitCore
@testable import BYOKitStore

@MainActor
final class StoreTests: XCTestCase {

    private func makeStore() -> ConfigurationStore {
        let defaults = UserDefaults(suiteName: "byokit.tests.\(UUID().uuidString)")!
        return ConfigurationStore(
            credentials: InMemoryCredentialStore(),
            persistence: InMemoryConfigurationPersistence(),
            activeIDDefaults: defaults
        )
    }

    func testAddStoresSecretAndBecomesActive() throws {
        let store = makeStore()
        let config = LLMConfiguration(providerID: .openAI, displayName: "Mine")
        try store.add(config, apiKey: "sk-secret")

        XCTAssertEqual(store.configurations.count, 1)
        XCTAssertEqual(store.activeConfigurationID, config.id, "First config should become active")
        XCTAssertEqual(store.apiKey(for: config.id), "sk-secret")
    }

    func testUpdateChangesFields() throws {
        let store = makeStore()
        var config = LLMConfiguration(providerID: .openAI, displayName: "A")
        try store.add(config)
        config.displayName = "B"
        config.selectedModelID = "gpt-4o"
        store.update(config)
        XCTAssertEqual(store.configuration(config.id)?.displayName, "B")
        XCTAssertEqual(store.configuration(config.id)?.selectedModelID, "gpt-4o")
    }

    func testRemoveDeletesSecretsAndReassignsActive() throws {
        let store = makeStore()
        let a = LLMConfiguration(providerID: .openAI, displayName: "A")
        let b = LLMConfiguration(providerID: .anthropic, displayName: "B")
        try store.add(a, apiKey: "sk-a")
        try store.add(b, apiKey: "sk-ant-b")
        XCTAssertEqual(store.activeConfigurationID, a.id)

        store.remove(a.id)
        XCTAssertNil(store.apiKey(for: a.id))
        XCTAssertEqual(store.configurations.count, 1)
        XCTAssertEqual(store.activeConfigurationID, b.id, "Active should move to the remaining config")
    }

    func testSetAPIKeyUpdatesSecret() throws {
        let store = makeStore()
        let config = LLMConfiguration(providerID: .openAI, displayName: "A")
        try store.add(config, apiKey: "old")
        try store.setAPIKey("new", for: config.id)
        XCTAssertEqual(store.apiKey(for: config.id), "new")
        // Clearing removes it.
        try store.setAPIKey(nil, for: config.id)
        XCTAssertNil(store.apiKey(for: config.id))
    }

    func testPersistenceReloads() throws {
        let defaults = UserDefaults(suiteName: "byokit.tests.\(UUID().uuidString)")!
        let persistence = InMemoryConfigurationPersistence()
        let creds = InMemoryCredentialStore()
        let store1 = ConfigurationStore(credentials: creds, persistence: persistence, activeIDDefaults: defaults)
        let config = LLMConfiguration(providerID: .openAI, displayName: "Persisted")
        try store1.add(config, apiKey: "k")

        // A fresh store over the same persistence should see the config.
        let store2 = ConfigurationStore(credentials: creds, persistence: persistence, activeIDDefaults: defaults)
        XCTAssertEqual(store2.configurations.map(\.displayName), ["Persisted"])
        XCTAssertEqual(store2.activeConfigurationID, config.id)
    }

    func testMoveReordersConfigurations() throws {
        let store = makeStore()
        let a = LLMConfiguration(providerID: .openAI, displayName: "A")
        let b = LLMConfiguration(providerID: .anthropic, displayName: "B")
        let c = LLMConfiguration(providerID: .gemini, displayName: "C")
        try store.add(a); try store.add(b); try store.add(c)
        store.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        XCTAssertEqual(store.configurations.map(\.displayName), ["B", "C", "A"])
    }

    func testInMemoryCredentialStoreIsolatesByConfig() throws {
        let store = InMemoryCredentialStore()
        let id1 = UUID(); let id2 = UUID()
        try store.saveAPIKey("one", for: id1)
        try store.saveAPIKey("two", for: id2)
        XCTAssertEqual(try store.apiKey(for: id1), "one")
        XCTAssertEqual(try store.apiKey(for: id2), "two")
        try store.deleteSecrets(for: id1)
        XCTAssertNil(try store.apiKey(for: id1))
        XCTAssertEqual(try store.apiKey(for: id2), "two")
    }
}
