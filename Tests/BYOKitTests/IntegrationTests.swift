import XCTest
@testable import BYOKitCore
@testable import BYOKitStore
@testable import BYOKitClient

/// Exercises the full path the UI relies on: pick a provider from the registry,
/// persist a configuration + key, resolve it, and validate it against a mocked
/// endpoint — without any SwiftUI.
@MainActor
final class IntegrationTests: XCTestCase {

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testEndToEndAddResolveValidate() async throws {
        // 1. Discover a provider exactly like the picker does.
        let registry = ProviderRegistry()
        guard let openai = await registry.provider(.openAI) else {
            return XCTFail("OpenAI should exist in the built-in catalog")
        }

        // 2. Create + persist a configuration with its key, like the form's Save.
        let store = ConfigurationStore(
            credentials: InMemoryCredentialStore(),
            persistence: InMemoryConfigurationPersistence(),
            activeIDDefaults: UserDefaults(suiteName: "byokit.it.\(UUID().uuidString)")!
        )
        let config = LLMConfiguration(
            providerID: openai.id,
            displayName: "My OpenAI",
            selectedModelID: openai.models.presets.first?.id
        )
        try store.add(config, apiKey: "sk-integration")
        XCTAssertEqual(store.activeConfigurationID, config.id)

        // 3. Resolve (provider + stored config + stored key) like the form does.
        let resolved = ResolvedConfiguration(
            provider: openai,
            configuration: store.configuration(config.id)!,
            apiKey: store.apiKey(for: config.id)
        )
        XCTAssertEqual(resolved.baseURL?.absoluteString, "https://api.openai.com/v1")
        XCTAssertEqual(resolved.modelID, openai.models.presets.first?.id)

        // 4. Validate against a mocked OpenAI /models endpoint.
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer sk-integration")
            return .init(data: Data(json: #"{"data":[{"id":"gpt-4o"},{"id":"o3"}]}"#))
        }
        let client = DefaultLLMClient(session: MockURLProtocol.session(), timeout: 5)
        let result = try await client.validate(resolved)
        XCTAssertTrue(result.ok)
        XCTAssertEqual(result.detectedModels?.count, 2)

        // 5. Send a completion through the same resolved config.
        MockURLProtocol.handler = { _ in
            .init(data: Data(json: #"{"model":"gpt-4o","choices":[{"message":{"content":"pong"}}]}"#))
        }
        let response = try await client.complete(.text("ping"), with: resolved)
        XCTAssertEqual(response.text, "pong")
    }
}
