import XCTest
@testable import BYOKitCore
@testable import BYOKitClient
@testable import BYOKitClientAnyLanguageModel

/// Records calls so we can assert the adapter delegates non-Apple providers.
private final class StubClient: LLMClient, @unchecked Sendable {
    var validated = 0, listed = 0, completed = 0

    func validate(_ resolved: ResolvedConfiguration) async throws -> ValidationResult {
        validated += 1
        return ValidationResult(ok: true, message: "stub")
    }
    func listModels(_ resolved: ResolvedConfiguration) async throws -> [ModelInfo] {
        listed += 1
        return [ModelInfo(id: "stub-model")]
    }
    func complete(_ request: CompletionRequest, with resolved: ResolvedConfiguration) async throws -> CompletionResponse {
        completed += 1
        return CompletionResponse(text: "stub-reply", modelID: "stub-model")
    }
}

final class AdapterTests: XCTestCase {

    private func resolved(_ provider: Provider) -> ResolvedConfiguration {
        ResolvedConfiguration(
            provider: provider,
            configuration: LLMConfiguration(providerID: provider.id, displayName: "t"),
            apiKey: "sk-x"
        )
    }

    private func openAIProvider() -> Provider {
        Provider(id: .openAI, displayName: "OpenAI", kind: .cloud, apiFormat: .openAI,
                 appearance: .init(), defaultBaseURL: URL(string: "https://api.openai.com/v1"),
                 credential: .init(requiresAPIKey: true))
    }

    func testDelegatesNonAppleProvidersToFallback() async throws {
        let stub = StubClient()
        let client = AnyLanguageModelClient(fallback: stub)
        let r = resolved(openAIProvider())

        _ = try await client.validate(r)
        _ = try await client.listModels(r)
        _ = try await client.complete(.text("hi"), with: r)

        XCTAssertEqual(stub.validated, 1)
        XCTAssertEqual(stub.listed, 1)
        XCTAssertEqual(stub.completed, 1)
    }

    func testAppleProviderDefinition() {
        let p = Provider.appleFoundationModels
        XCTAssertEqual(p.id, .appleFoundation)
        XCTAssertEqual(p.kind, .local)
        XCTAssertFalse(p.credential.requiresAPIKey)
        XCTAssertFalse(p.models.presets.isEmpty)
    }

    func testAppleValidateDoesNotDelegateAndReturnsResult() async throws {
        let stub = StubClient()
        let client = AnyLanguageModelClient(fallback: stub)

        // Apple is serviced natively — fallback must not be touched.
        let result = try await client.validate(resolved(.appleFoundationModels))
        XCTAssertEqual(stub.validated, 0, "Apple provider must not delegate to fallback")
        // On a host without Apple Intelligence this is ok:false; we only assert it
        // produced a result with a message rather than throwing.
        XCTAssertNotNil(result.message)

        // listModels for Apple returns the on-device model without delegating.
        let models = try await client.listModels(resolved(.appleFoundationModels))
        XCTAssertEqual(stub.listed, 0)
        XCTAssertEqual(models.first?.id, "default")
    }
}
