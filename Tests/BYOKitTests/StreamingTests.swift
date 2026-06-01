import XCTest
@testable import BYOKitCore
@testable import BYOKitClient

final class StreamingTests: XCTestCase {

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

    private func resolved(_ provider: Provider, key: String? = "sk-test", model: String? = "m") -> ResolvedConfiguration {
        ResolvedConfiguration(
            provider: provider,
            configuration: LLMConfiguration(providerID: provider.id, displayName: "t", selectedModelID: model),
            apiKey: key
        )
    }

    private func collect(_ stream: AsyncThrowingStream<String, Error>) async throws -> [String] {
        var chunks: [String] = []
        for try await chunk in stream { chunks.append(chunk) }
        return chunks
    }

    func testOpenAIStreamAccumulatesDeltas() async throws {
        let sse = """
        data: {"choices":[{"delta":{"content":"Hel"}}]}

        data: {"choices":[{"delta":{"content":"lo"}}]}

        data: {"choices":[{"delta":{"role":"assistant"}}]}

        data: [DONE]

        """
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/v1/chat/completions")
            return .init(data: Data(json: sse), headers: ["Content-Type": "text/event-stream"])
        }
        let p = provider(.openAI, format: .openAI, base: "https://api.openai.com/v1")
        let chunks = try await collect(client().streamComplete(.text("hi"), with: resolved(p, model: "gpt-4o")))
        XCTAssertEqual(chunks, ["Hel", "lo"])
        XCTAssertEqual(chunks.joined(), "Hello")
    }

    func testAnthropicStreamParsesContentBlockDeltas() async throws {
        let sse = """
        event: message_start
        data: {"type":"message_start"}

        event: content_block_delta
        data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"Hi "}}

        event: content_block_delta
        data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"there"}}

        event: message_stop
        data: {"type":"message_stop"}

        """
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/v1/messages")
            return .init(data: Data(json: sse), headers: ["Content-Type": "text/event-stream"])
        }
        let p = provider(.anthropic, format: .anthropic, base: "https://api.anthropic.com")
        let chunks = try await collect(client().streamComplete(.text("hi"), with: resolved(p, key: "sk-ant-x")))
        XCTAssertEqual(chunks.joined(), "Hi there")
    }

    func testGeminiStreamUsesSSEAndParsesParts() async throws {
        let sse = """
        data: {"candidates":[{"content":{"parts":[{"text":"ans"}]}}]}

        data: {"candidates":[{"content":{"parts":[{"text":"wer"}]}}]}

        """
        MockURLProtocol.handler = { req in
            XCTAssertTrue(req.url?.path.contains("streamGenerateContent") ?? false)
            XCTAssertTrue(req.url?.query?.contains("alt=sse") ?? false)
            return .init(data: Data(json: sse), headers: ["Content-Type": "text/event-stream"])
        }
        let p = provider(.gemini, format: .gemini, base: "https://generativelanguage.googleapis.com/v1beta")
        let chunks = try await collect(client().streamComplete(.text("q"), with: resolved(p, key: "gkey", model: "gemini-2.0-flash")))
        XCTAssertEqual(chunks.joined(), "answer")
    }

    func testOllamaStreamParsesNDJSON() async throws {
        let ndjson = """
        {"message":{"role":"assistant","content":"local "},"done":false}
        {"message":{"role":"assistant","content":"reply"},"done":false}
        {"done":true}
        """
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/api/chat")
            return .init(data: Data(json: ndjson))
        }
        let p = provider(.ollama, format: .ollama, base: "http://localhost:11434", requiresKey: false)
        let chunks = try await collect(client().streamComplete(.text("hi"), with: resolved(p, key: nil, model: "llama3.2")))
        XCTAssertEqual(chunks.joined(), "local reply")
    }

    func testStreamSurfacesHTTPError() async {
        MockURLProtocol.handler = { _ in .init(status: 401, data: Data(json: #"{"error":"bad key"}"#)) }
        let p = provider(.openAI, format: .openAI, base: "https://api.openai.com/v1")
        do {
            _ = try await collect(client().streamComplete(.text("hi"), with: resolved(p, model: "gpt-4o")))
            XCTFail("Expected http error")
        } catch let LLMClientError.http(status, _) {
            XCTAssertEqual(status, 401)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testStreamMissingKeyThrows() async {
        let p = provider(.openAI, format: .openAI, base: "https://api.openai.com/v1")
        do {
            _ = try await collect(client().streamComplete(.text("hi"), with: resolved(p, key: "")))
            XCTFail("Expected missingAPIKey")
        } catch let error as LLMClientError {
            XCTAssertEqual(error, .missingAPIKey)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    /// The protocol's default streaming falls back to a single `complete` call.
    func testDefaultStreamFallbackYieldsWholeText() async throws {
        struct OneShotClient: LLMClient {
            func validate(_ r: ResolvedConfiguration) async throws -> ValidationResult { ValidationResult(ok: true) }
            func listModels(_ r: ResolvedConfiguration) async throws -> [ModelInfo] { [] }
            func complete(_ req: CompletionRequest, with r: ResolvedConfiguration) async throws -> CompletionResponse {
                CompletionResponse(text: "whole answer", modelID: "m")
            }
        }
        let p = provider(.openAI, format: .openAI, base: "https://api.openai.com/v1")
        let chunks = try await collect(OneShotClient().streamComplete(.text("hi"), with: resolved(p)))
        XCTAssertEqual(chunks, ["whole answer"])
    }
}
