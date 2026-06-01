import XCTest
@testable import BYOKitCore
@testable import BYOKitClient

final class ClientTests: XCTestCase {

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func client() -> DefaultLLMClient {
        DefaultLLMClient(session: MockURLProtocol.session(), timeout: 5)
    }

    private func provider(_ id: ProviderID, format: APIFormat, base: String, requiresKey: Bool = true) -> Provider {
        Provider(
            id: id, displayName: id.rawValue, kind: .cloud, apiFormat: format,
            appearance: .init(), defaultBaseURL: URL(string: base)!,
            allowsCustomBaseURL: true,
            credential: .init(requiresAPIKey: requiresKey),
            models: .init(presets: [ModelInfo(id: "preset-model")], supportsDynamicListing: true)
        )
    }

    private func resolved(_ provider: Provider, key: String? = "sk-test", model: String? = nil) -> ResolvedConfiguration {
        ResolvedConfiguration(
            provider: provider,
            configuration: LLMConfiguration(providerID: provider.id, displayName: "t", selectedModelID: model),
            apiKey: key
        )
    }

    // MARK: - OpenAI format

    func testOpenAIListModels() async throws {
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/v1/models")
            XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test")
            return .init(data: Data(json: #"{"data":[{"id":"gpt-4o"},{"id":"gpt-3.5"}]}"#))
        }
        let models = try await client().listModels(resolved(provider(.openAI, format: .openAI, base: "https://api.openai.com/v1")))
        XCTAssertEqual(Set(models.map(\.id)), ["gpt-4o", "gpt-3.5"])
    }

    func testOpenAIValidateReportsModelCount() async throws {
        MockURLProtocol.handler = { _ in .init(data: Data(json: #"{"data":[{"id":"a"},{"id":"b"},{"id":"c"}]}"#)) }
        let result = try await client().validate(resolved(provider(.openAI, format: .openAI, base: "https://api.openai.com/v1")))
        XCTAssertTrue(result.ok)
        XCTAssertEqual(result.detectedModels?.count, 3)
        XCTAssertNotNil(result.latency)
    }

    func testOpenAIComplete() async throws {
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/v1/chat/completions")
            XCTAssertEqual(req.httpMethod, "POST")
            return .init(data: Data(json: #"{"model":"gpt-4o","choices":[{"message":{"content":"hello there"}}]}"#))
        }
        let p = provider(.openAI, format: .openAI, base: "https://api.openai.com/v1")
        let resp = try await client().complete(.text("hi"), with: resolved(p, model: "gpt-4o"))
        XCTAssertEqual(resp.text, "hello there")
        XCTAssertEqual(resp.modelID, "gpt-4o")
    }

    // MARK: - Anthropic format

    func testAnthropicListModelsUsesApiKeyHeaderAndVersion() async throws {
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/v1/models")
            XCTAssertEqual(req.value(forHTTPHeaderField: "x-api-key"), "sk-ant-x")
            XCTAssertEqual(req.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
            return .init(data: Data(json: #"{"data":[{"id":"claude-x","display_name":"Claude X"}]}"#))
        }
        let p = provider(.anthropic, format: .anthropic, base: "https://api.anthropic.com")
        let models = try await client().listModels(resolved(p, key: "sk-ant-x"))
        XCTAssertEqual(models.first?.id, "claude-x")
        XCTAssertEqual(models.first?.displayName, "Claude X")
    }

    func testAnthropicCompleteParsesContentBlocks() async throws {
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/v1/messages")
            return .init(data: Data(json: #"{"model":"claude","content":[{"type":"text","text":"Hi "},{"type":"text","text":"world"}]}"#))
        }
        let p = provider(.anthropic, format: .anthropic, base: "https://api.anthropic.com")
        let resp = try await client().complete(.init(messages: [.system("be nice"), .user("hi")], model: "claude"), with: resolved(p, key: "sk-ant-x"))
        XCTAssertEqual(resp.text, "Hi world")
    }

    // MARK: - Gemini format

    func testGeminiListModelsStripsPrefixAndPassesKey() async throws {
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/v1beta/models")
            XCTAssertTrue(req.url?.query?.contains("key=gkey") ?? false)
            return .init(data: Data(json: #"{"models":[{"name":"models/gemini-2.0-flash","displayName":"Gemini 2.0 Flash"}]}"#))
        }
        let p = provider(.gemini, format: .gemini, base: "https://generativelanguage.googleapis.com/v1beta")
        let models = try await client().listModels(resolved(p, key: "gkey"))
        XCTAssertEqual(models.first?.id, "gemini-2.0-flash")
    }

    func testGeminiCompleteParsesCandidates() async throws {
        MockURLProtocol.handler = { req in
            XCTAssertTrue(req.url?.path.contains("generateContent") ?? false)
            return .init(data: Data(json: #"{"candidates":[{"content":{"parts":[{"text":"answer"}]}}]}"#))
        }
        let p = provider(.gemini, format: .gemini, base: "https://generativelanguage.googleapis.com/v1beta")
        let resp = try await client().complete(.text("q"), with: resolved(p, key: "gkey", model: "gemini-2.0-flash"))
        XCTAssertEqual(resp.text, "answer")
    }

    // MARK: - Ollama format

    func testOllamaListModelsNeedsNoKey() async throws {
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/api/tags")
            return .init(data: Data(json: #"{"models":[{"name":"llama3.2"},{"name":"qwen2.5"}]}"#))
        }
        let p = provider(.ollama, format: .ollama, base: "http://localhost:11434", requiresKey: false)
        let models = try await client().listModels(resolved(p, key: nil))
        XCTAssertEqual(models.map(\.id), ["llama3.2", "qwen2.5"])
    }

    func testOllamaComplete() async throws {
        MockURLProtocol.handler = { _ in
            .init(data: Data(json: #"{"model":"llama3.2","message":{"role":"assistant","content":"local reply"}}"#))
        }
        let p = provider(.ollama, format: .ollama, base: "http://localhost:11434", requiresKey: false)
        let resp = try await client().complete(.text("hi"), with: resolved(p, key: nil, model: "llama3.2"))
        XCTAssertEqual(resp.text, "local reply")
    }

    // MARK: - Errors

    func testMissingAPIKeyThrows() async {
        let p = provider(.openAI, format: .openAI, base: "https://api.openai.com/v1")
        do {
            _ = try await client().validate(resolved(p, key: ""))
            XCTFail("Expected missingAPIKey")
        } catch let error as LLMClientError {
            XCTAssertEqual(error, .missingAPIKey)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testHTTPErrorIsMappedAndValidateReportsFailure() async throws {
        MockURLProtocol.handler = { _ in .init(status: 401, data: Data(json: #"{"error":"invalid key"}"#)) }
        let p = provider(.openAI, format: .openAI, base: "https://api.openai.com/v1")

        // listModels surfaces the HTTP error.
        do {
            _ = try await client().listModels(resolved(p))
            XCTFail("Expected http error")
        } catch let LLMClientError.http(status, _) {
            XCTAssertEqual(status, 401)
        }

        // validate() turns it into a friendly failure result, not a throw.
        let result = try await client().validate(resolved(p))
        XCTAssertFalse(result.ok)
        XCTAssertTrue(result.message?.contains("401") ?? false)
    }

    func testMissingModelThrowsOnComplete() async {
        // Provider with no presets and no selected model.
        let p = Provider(
            id: .custom, displayName: "C", kind: .compatible, apiFormat: .openAI,
            appearance: .init(), defaultBaseURL: URL(string: "https://x.local"),
            credential: .init(requiresAPIKey: false)
        )
        let r = ResolvedConfiguration(provider: p, configuration: LLMConfiguration(providerID: .custom, displayName: "c"))
        do {
            _ = try await client().complete(.text("hi"), with: r)
            XCTFail("Expected missingModel")
        } catch let error as LLMClientError {
            XCTAssertEqual(error, .missingModel)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
}
