import XCTest
@testable import AnyLLMCore

final class CoreTests: XCTestCase {

    func testBuiltinProvidersDecodeAndLoad() async {
        let registry = ProviderRegistry()
        let all = await registry.all()
        XCTAssertGreaterThanOrEqual(all.count, 8, "Expected the built-in catalog to ship many providers")

        // Spot-check a few well-known ones.
        let openai = await registry.provider(.openAI)
        XCTAssertNotNil(openai)
        XCTAssertEqual(openai?.apiFormat, .openAI)
        XCTAssertEqual(openai?.defaultBaseURL?.absoluteString, "https://api.openai.com/v1")
        XCTAssertTrue(openai?.onboarding.hasContent ?? false)
        XCTAssertNotNil(openai?.onboarding.consoleURL)

        let ollama = await registry.provider(.ollama)
        XCTAssertEqual(ollama?.kind, .local)
        XCTAssertEqual(ollama?.credential.requiresAPIKey, false)
    }

    func testEveryProviderHasModelsOrDynamicListing() async {
        let registry = ProviderRegistry()
        for provider in await registry.all() {
            let hasSomething = !provider.models.presets.isEmpty || provider.models.supportsDynamicListing
            XCTAssertTrue(hasSomething, "\(provider.id) should offer presets or dynamic listing")
        }
    }

    func testProviderFilter() async {
        let registry = ProviderRegistry()
        let cloud = await registry.providers(.kinds(.cloud))
        XCTAssertTrue(cloud.allSatisfy { $0.kind == .cloud })
        XCTAssertFalse(cloud.isEmpty)

        let onlyOpenAI = await registry.providers(.only(.openAI))
        XCTAssertEqual(onlyOpenAI.map(\.id), [.openAI])
    }

    func testRegistryRejectsOlderRemoteVersion() throws {
        let registry = ProviderRegistry(providers: [], version: 5)
        let older = Data(json: #"{"version":4,"providers":[]}"#)
        XCTAssertThrowsError(try syncApply(registry, older))
    }

    func testRegistryAcceptsNewerRemoteVersion() async throws {
        let registry = ProviderRegistry(providers: [], version: 1)
        let newer = Data(json: #"""
        {"version":2,"providers":[
          {"id":"x","displayName":"X","kind":"cloud","apiFormat":"openai",
           "appearance":{"tintHex":"#111111"},
           "allowsCustomBaseURL":false,
           "credential":{"requiresAPIKey":true,"keyDisplayName":"API Key","extraFields":[]},
           "onboarding":{"steps":[],"notes":[]},
           "models":{"presets":[],"supportsDynamicListing":true}}
        ]}
        """#)
        let v = try await registry.apply(data: newer)
        XCTAssertEqual(v, 2)
        let count = await registry.all().count
        XCTAssertEqual(count, 1)
    }

    func testKeyValidation() {
        let v = KeyValidation(prefix: "sk-", minLength: 10)
        XCTAssertNil(v.reasonInvalid(for: "sk-abcdefghijklmnop"))
        XCTAssertNotNil(v.reasonInvalid(for: "abc"))          // wrong prefix
        XCTAssertNotNil(v.reasonInvalid(for: "sk-1"))         // too short
        XCTAssertNotNil(v.reasonInvalid(for: ""))             // empty
        // Whitespace is tolerated.
        XCTAssertNil(v.reasonInvalid(for: "  sk-abcdefghijklmnop  "))
    }

    func testConfigurationCodableRoundTrip() throws {
        let config = LLMConfiguration(
            providerID: .anthropic,
            displayName: "Work",
            baseURL: URL(string: "https://example.com"),
            selectedModelID: "claude",
            extraValues: ["region": "us"],
            isEnabled: false
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(LLMConfiguration.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    func testResolvedBaseURLFallsBackToProviderDefault() {
        let provider = Provider(
            id: .openAI, displayName: "OpenAI", kind: .cloud, apiFormat: .openAI,
            appearance: .init(), defaultBaseURL: URL(string: "https://api.openai.com/v1"),
            credential: .init()
        )
        let withoutOverride = LLMConfiguration(providerID: .openAI, displayName: "x")
        XCTAssertEqual(withoutOverride.resolvedBaseURL(for: provider), provider.defaultBaseURL)

        let withOverride = LLMConfiguration(providerID: .openAI, displayName: "x", baseURL: URL(string: "https://proxy.local"))
        XCTAssertEqual(withOverride.resolvedBaseURL(for: provider)?.absoluteString, "https://proxy.local")
    }

    // Helper: call the actor's apply synchronously for a throwing assertion.
    private func syncApply(_ registry: ProviderRegistry, _ data: Data) throws {
        let expectation = expectation(description: "apply")
        nonisolated(unsafe) var caught: Error?
        Task {
            do { _ = try await registry.apply(data: data) }
            catch { caught = error }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
        if let caught { throw caught }
    }
}
