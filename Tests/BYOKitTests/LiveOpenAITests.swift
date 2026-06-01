import XCTest
@testable import BYOKitCore
@testable import BYOKitClient

/// Live smoke tests against the real OpenAI API. They run only when
/// `ROCKY_OPENAI_APIKEY` is present, and skip otherwise so CI stays hermetic.
final class LiveOpenAITests: XCTestCase {

    private var apiKey: String? {
        let key = ProcessInfo.processInfo.environment["ROCKY_OPENAI_APIKEY"]
        return (key?.isEmpty == false) ? key : nil
    }

    private func resolvedOpenAI(_ key: String, model: String? = nil) async throws -> ResolvedConfiguration {
        let maybeProvider = await ProviderRegistry().provider(.openAI)
        let provider = try XCTUnwrap(maybeProvider)
        return ResolvedConfiguration(
            provider: provider,
            configuration: LLMConfiguration(providerID: .openAI, displayName: "live", selectedModelID: model),
            apiKey: key
        )
    }

    func testLiveValidateAndListModels() async throws {
        guard let apiKey else { throw XCTSkip("ROCKY_OPENAI_APIKEY not set") }
        let client = DefaultLLMClient(timeout: 30)
        let resolved = try await resolvedOpenAI(apiKey)

        let result = try await client.validate(resolved)
        XCTAssertTrue(result.ok, "validate failed: \(result.message ?? "nil")")
        let count = result.detectedModels?.count ?? 0
        XCTAssertGreaterThan(count, 0, "Expected the live API to return models")
        print("✅ Live OpenAI: \(count) models, \(Int((result.latency ?? 0) * 1000)) ms")
    }

    func testLiveCompletion() async throws {
        guard let apiKey else { throw XCTSkip("ROCKY_OPENAI_APIKEY not set") }
        let client = DefaultLLMClient(timeout: 30)
        let resolved = try await resolvedOpenAI(apiKey, model: "gpt-4o-mini")

        let request = CompletionRequest(
            messages: [.system("Reply with exactly one word."), .user("Say the word: pong")],
            maxTokens: 10,
            temperature: 0
        )
        let response = try await client.complete(request, with: resolved)
        XCTAssertFalse(response.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        print("✅ Live OpenAI completion (\(response.modelID ?? "?")): \(response.text)")
    }
}
