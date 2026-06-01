import Foundation
import BYOKitCore

/// Zero-dependency `LLMClient` built on `URLSession`. Speaks the OpenAI,
/// Anthropic, Gemini, and Ollama wire formats.
public struct DefaultLLMClient: LLMClient {
    public let session: URLSession
    public let timeout: TimeInterval

    public init(session: URLSession = .shared, timeout: TimeInterval = 30) {
        self.session = session
        self.timeout = timeout
    }

    // MARK: - validate

    public func validate(_ resolved: ResolvedConfiguration) async throws -> ValidationResult {
        try ensureCredentials(resolved)
        let start = Date()
        do {
            let models = try await listModels(resolved)
            let latency = Date().timeIntervalSince(start)
            let msg: String
            if models.isEmpty {
                msg = L("Connected. The endpoint returned no models.")
            } else if models.count == 1 {
                msg = L("Connected. Found 1 model.")
            } else {
                msg = L("Connected. Found \(models.count) models.")
            }
            return ValidationResult(ok: true, latency: latency, detectedModels: models, message: msg)
        } catch let error as LLMClientError {
            return ValidationResult(ok: false, latency: Date().timeIntervalSince(start), message: error.errorDescription)
        }
    }

    // MARK: - listModels

    public func listModels(_ resolved: ResolvedConfiguration) async throws -> [ModelInfo] {
        try ensureCredentials(resolved)
        switch resolved.provider.apiFormat {
        case .openAI, .custom: return try await listOpenAIModels(resolved)
        case .anthropic:       return try await listAnthropicModels(resolved)
        case .gemini:          return try await listGeminiModels(resolved)
        case .ollama:          return try await listOllamaModels(resolved)
        }
    }

    // MARK: - complete

    public func complete(_ request: CompletionRequest, with resolved: ResolvedConfiguration) async throws -> CompletionResponse {
        try ensureCredentials(resolved)
        guard let model = request.model ?? resolved.modelID else { throw LLMClientError.missingModel }
        switch resolved.provider.apiFormat {
        case .openAI, .custom: return try await completeOpenAI(request, model: model, resolved)
        case .anthropic:       return try await completeAnthropic(request, model: model, resolved)
        case .gemini:          return try await completeGemini(request, model: model, resolved)
        case .ollama:          return try await completeOllama(request, model: model, resolved)
        }
    }

    // MARK: - Credential / URL helpers

    private func ensureCredentials(_ resolved: ResolvedConfiguration) throws {
        if resolved.provider.credential.requiresAPIKey, (resolved.apiKey ?? "").isEmpty {
            throw LLMClientError.missingAPIKey
        }
        if resolved.baseURL == nil { throw LLMClientError.missingBaseURL }
    }

    private func base(_ resolved: ResolvedConfiguration) throws -> URL {
        guard let url = resolved.baseURL else { throw LLMClientError.missingBaseURL }
        return url
    }

    /// Joins a path onto the base URL, tolerating a trailing slash on the base.
    private func endpoint(_ base: URL, _ path: String) -> URL {
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return base.appendingPathComponent(trimmed)
    }

    private func send(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw LLMClientError.transport("No HTTP response.")
            }
            guard (200..<300).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8)
                throw LLMClientError.http(status: http.statusCode, body: body?.prefixForError())
            }
            return data
        } catch let error as LLMClientError {
            throw error
        } catch {
            throw LLMClientError.transport(error.localizedDescription)
        }
    }

    private func makeRequest(_ url: URL, method: String = "GET", body: Data? = nil, headers: [String: String] = [:]) -> URLRequest {
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = method
        req.httpBody = body
        if body != nil { req.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        return req
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw LLMClientError.decoding(error.localizedDescription) }
    }

    // MARK: - OpenAI

    private func openAIHeaders(_ resolved: ResolvedConfiguration) -> [String: String] {
        var h: [String: String] = [:]
        if let key = resolved.apiKey, !key.isEmpty { h["Authorization"] = "Bearer \(key)" }
        return h
    }

    private func listOpenAIModels(_ resolved: ResolvedConfiguration) async throws -> [ModelInfo] {
        let url = endpoint(try base(resolved), "models")
        let data = try await send(makeRequest(url, headers: openAIHeaders(resolved)))
        struct Response: Decodable { struct Model: Decodable { let id: String }; let data: [Model] }
        let decoded = try decode(Response.self, from: data)
        return decoded.data.map { ModelInfo(id: $0.id) }.sorted { $0.id < $1.id }
    }

    private func completeOpenAI(_ request: CompletionRequest, model: String, _ resolved: ResolvedConfiguration) async throws -> CompletionResponse {
        let url = endpoint(try base(resolved), "chat/completions")
        struct Message: Encodable { let role: String; let content: String }
        struct Body: Encodable {
            let model: String
            let messages: [Message]
            let max_tokens: Int?
            let temperature: Double?
        }
        let body = Body(
            model: model,
            messages: request.messages.map { Message(role: $0.role.rawValue, content: $0.content) },
            max_tokens: request.maxTokens,
            temperature: request.temperature
        )
        let data = try await send(makeRequest(url, method: "POST", body: try JSONEncoder().encode(body), headers: openAIHeaders(resolved)))
        struct Response: Decodable {
            struct Choice: Decodable { struct Msg: Decodable { let content: String? }; let message: Msg }
            let choices: [Choice]
            let model: String?
        }
        let decoded = try decode(Response.self, from: data)
        return CompletionResponse(text: decoded.choices.first?.message.content ?? "", modelID: decoded.model ?? model)
    }

    // MARK: - Anthropic

    private func anthropicHeaders(_ resolved: ResolvedConfiguration) -> [String: String] {
        var h: [String: String] = ["anthropic-version": "2023-06-01"]
        if let key = resolved.apiKey, !key.isEmpty { h["x-api-key"] = key }
        return h
    }

    private func listAnthropicModels(_ resolved: ResolvedConfiguration) async throws -> [ModelInfo] {
        let url = endpoint(try base(resolved), "v1/models")
        let data = try await send(makeRequest(url, headers: anthropicHeaders(resolved)))
        struct Response: Decodable { struct Model: Decodable { let id: String; let display_name: String? }; let data: [Model] }
        let decoded = try decode(Response.self, from: data)
        return decoded.data.map { ModelInfo(id: $0.id, displayName: $0.display_name) }
    }

    private func completeAnthropic(_ request: CompletionRequest, model: String, _ resolved: ResolvedConfiguration) async throws -> CompletionResponse {
        let url = endpoint(try base(resolved), "v1/messages")
        // Anthropic takes `system` at the top level; everything else is a turn.
        let system = request.messages.filter { $0.role == .system }.map(\.content).joined(separator: "\n\n")
        let turns = request.messages.filter { $0.role != .system }
        struct Message: Encodable { let role: String; let content: String }
        struct Body: Encodable {
            let model: String
            let max_tokens: Int
            let system: String?
            let messages: [Message]
            let temperature: Double?
        }
        let body = Body(
            model: model,
            max_tokens: request.maxTokens ?? 1024,
            system: system.isEmpty ? nil : system,
            messages: turns.map { Message(role: $0.role.rawValue, content: $0.content) },
            temperature: request.temperature
        )
        let data = try await send(makeRequest(url, method: "POST", body: try JSONEncoder().encode(body), headers: anthropicHeaders(resolved)))
        struct Response: Decodable {
            struct Block: Decodable { let type: String; let text: String? }
            let content: [Block]
            let model: String?
        }
        let decoded = try decode(Response.self, from: data)
        let text = decoded.content.compactMap { $0.type == "text" ? $0.text : nil }.joined()
        return CompletionResponse(text: text, modelID: decoded.model ?? model)
    }

    // MARK: - Gemini

    private func listGeminiModels(_ resolved: ResolvedConfiguration) async throws -> [ModelInfo] {
        var comps = URLComponents(url: endpoint(try base(resolved), "models"), resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "key", value: resolved.apiKey ?? "")]
        guard let url = comps?.url else { throw LLMClientError.invalidURL }
        let data = try await send(makeRequest(url))
        struct Response: Decodable { struct Model: Decodable { let name: String; let displayName: String? }; let models: [Model] }
        let decoded = try decode(Response.self, from: data)
        return decoded.models.map { m in
            let id = m.name.hasPrefix("models/") ? String(m.name.dropFirst("models/".count)) : m.name
            return ModelInfo(id: id, displayName: m.displayName)
        }
    }

    private func completeGemini(_ request: CompletionRequest, model: String, _ resolved: ResolvedConfiguration) async throws -> CompletionResponse {
        var comps = URLComponents(url: endpoint(try base(resolved), "models/\(model):generateContent"), resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "key", value: resolved.apiKey ?? "")]
        guard let url = comps?.url else { throw LLMClientError.invalidURL }

        struct Part: Codable { let text: String }
        struct Content: Encodable { let role: String; let parts: [Part] }
        struct SystemInstruction: Encodable { let parts: [Part] }
        struct Body: Encodable { let contents: [Content]; let systemInstruction: SystemInstruction? }

        let system = request.messages.filter { $0.role == .system }.map(\.content).joined(separator: "\n\n")
        let contents: [Content] = request.messages.filter { $0.role != .system }.map { msg in
            Content(role: msg.role == .assistant ? "model" : "user", parts: [Part(text: msg.content)])
        }
        let body = Body(
            contents: contents,
            systemInstruction: system.isEmpty ? nil : SystemInstruction(parts: [Part(text: system)])
        )
        let data = try await send(makeRequest(url, method: "POST", body: try JSONEncoder().encode(body)))
        struct Response: Decodable {
            struct Candidate: Decodable { struct C: Decodable { let parts: [Part]? }; let content: C? }
            let candidates: [Candidate]?
        }
        let decoded = try decode(Response.self, from: data)
        let text = decoded.candidates?.first?.content?.parts?.compactMap(\.text).joined() ?? ""
        return CompletionResponse(text: text, modelID: model)
    }

    // MARK: - Ollama

    private func listOllamaModels(_ resolved: ResolvedConfiguration) async throws -> [ModelInfo] {
        let url = endpoint(try base(resolved), "api/tags")
        let data = try await send(makeRequest(url))
        struct Response: Decodable { struct Model: Decodable { let name: String }; let models: [Model] }
        let decoded = try decode(Response.self, from: data)
        return decoded.models.map { ModelInfo(id: $0.name) }
    }

    private func completeOllama(_ request: CompletionRequest, model: String, _ resolved: ResolvedConfiguration) async throws -> CompletionResponse {
        let url = endpoint(try base(resolved), "api/chat")
        struct Message: Encodable { let role: String; let content: String }
        struct Body: Encodable { let model: String; let messages: [Message]; let stream: Bool }
        let body = Body(model: model, messages: request.messages.map { Message(role: $0.role.rawValue, content: $0.content) }, stream: false)
        let data = try await send(makeRequest(url, method: "POST", body: try JSONEncoder().encode(body)))
        struct Response: Decodable { struct Msg: Decodable { let content: String }; let message: Msg?; let model: String? }
        let decoded = try decode(Response.self, from: data)
        return CompletionResponse(text: decoded.message?.content ?? "", modelID: decoded.model ?? model)
    }
}

// MARK: - Streaming

extension DefaultLLMClient {
    public func streamComplete(_ request: CompletionRequest, with resolved: ResolvedConfiguration) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try ensureCredentials(resolved)
                    guard let model = request.model ?? resolved.modelID else { throw LLMClientError.missingModel }
                    switch resolved.provider.apiFormat {
                    case .openAI, .custom: try await streamOpenAI(request, model: model, resolved, into: continuation)
                    case .anthropic:       try await streamAnthropic(request, model: model, resolved, into: continuation)
                    case .gemini:          try await streamGemini(request, model: model, resolved, into: continuation)
                    case .ollama:          try await streamOllama(request, model: model, resolved, into: continuation)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Opens a streaming request and returns its line sequence, mapping a
    /// non-2xx status onto `LLMClientError.http` after draining the body.
    private func openStream(_ request: URLRequest) async throws -> URLSession.AsyncBytes {
        do {
            let (bytes, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw LLMClientError.transport("No HTTP response.")
            }
            guard (200..<300).contains(http.statusCode) else {
                var body = ""
                for try await line in bytes.lines { body += line; if body.count > 600 { break } }
                throw LLMClientError.http(status: http.statusCode, body: body.prefixForError())
            }
            return bytes
        } catch let error as LLMClientError {
            throw error
        } catch {
            throw LLMClientError.transport(error.localizedDescription)
        }
    }

    /// Strips the `data: ` prefix from an SSE line, returning nil for blank
    /// lines, comments, event-type lines, and the `[DONE]` sentinel.
    private func sseData(_ line: String) -> String? {
        guard line.hasPrefix("data:") else { return nil }
        let payload = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
        return (payload.isEmpty || payload == "[DONE]") ? nil : payload
    }

    private func streamOpenAI(_ request: CompletionRequest, model: String, _ resolved: ResolvedConfiguration, into continuation: AsyncThrowingStream<String, Error>.Continuation) async throws {
        let url = endpoint(try base(resolved), "chat/completions")
        struct Message: Encodable { let role: String; let content: String }
        struct Body: Encodable { let model: String; let messages: [Message]; let max_tokens: Int?; let temperature: Double?; let stream: Bool }
        let body = Body(
            model: model,
            messages: request.messages.map { Message(role: $0.role.rawValue, content: $0.content) },
            max_tokens: request.maxTokens, temperature: request.temperature, stream: true
        )
        let req = makeRequest(url, method: "POST", body: try JSONEncoder().encode(body), headers: openAIHeaders(resolved))
        struct Chunk: Decodable { struct Choice: Decodable { struct Delta: Decodable { let content: String? }; let delta: Delta }; let choices: [Choice] }
        for try await line in try await openStream(req).lines {
            guard let payload = sseData(line), let data = payload.data(using: .utf8) else { continue }
            guard let chunk = try? JSONDecoder().decode(Chunk.self, from: data) else { continue }
            if let text = chunk.choices.first?.delta.content, !text.isEmpty { continuation.yield(text) }
        }
    }

    private func streamAnthropic(_ request: CompletionRequest, model: String, _ resolved: ResolvedConfiguration, into continuation: AsyncThrowingStream<String, Error>.Continuation) async throws {
        let url = endpoint(try base(resolved), "v1/messages")
        let system = request.messages.filter { $0.role == .system }.map(\.content).joined(separator: "\n\n")
        let turns = request.messages.filter { $0.role != .system }
        struct Message: Encodable { let role: String; let content: String }
        struct Body: Encodable { let model: String; let max_tokens: Int; let system: String?; let messages: [Message]; let temperature: Double?; let stream: Bool }
        let body = Body(
            model: model, max_tokens: request.maxTokens ?? 1024,
            system: system.isEmpty ? nil : system,
            messages: turns.map { Message(role: $0.role.rawValue, content: $0.content) },
            temperature: request.temperature, stream: true
        )
        let req = makeRequest(url, method: "POST", body: try JSONEncoder().encode(body), headers: anthropicHeaders(resolved))
        struct Event: Decodable { struct Delta: Decodable { let type: String?; let text: String? }; let type: String; let delta: Delta? }
        for try await line in try await openStream(req).lines {
            guard let payload = sseData(line), let data = payload.data(using: .utf8) else { continue }
            guard let event = try? JSONDecoder().decode(Event.self, from: data) else { continue }
            if event.type == "content_block_delta", let text = event.delta?.text, !text.isEmpty { continuation.yield(text) }
        }
    }

    private func streamGemini(_ request: CompletionRequest, model: String, _ resolved: ResolvedConfiguration, into continuation: AsyncThrowingStream<String, Error>.Continuation) async throws {
        var comps = URLComponents(url: endpoint(try base(resolved), "models/\(model):streamGenerateContent"), resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "alt", value: "sse"), URLQueryItem(name: "key", value: resolved.apiKey ?? "")]
        guard let url = comps?.url else { throw LLMClientError.invalidURL }
        struct Part: Codable { let text: String }
        struct Content: Encodable { let role: String; let parts: [Part] }
        struct SystemInstruction: Encodable { let parts: [Part] }
        struct Body: Encodable { let contents: [Content]; let systemInstruction: SystemInstruction? }
        let system = request.messages.filter { $0.role == .system }.map(\.content).joined(separator: "\n\n")
        let contents: [Content] = request.messages.filter { $0.role != .system }.map { msg in
            Content(role: msg.role == .assistant ? "model" : "user", parts: [Part(text: msg.content)])
        }
        let body = Body(contents: contents, systemInstruction: system.isEmpty ? nil : SystemInstruction(parts: [Part(text: system)]))
        let req = makeRequest(url, method: "POST", body: try JSONEncoder().encode(body))
        struct Chunk: Decodable { struct Candidate: Decodable { struct C: Decodable { let parts: [Part]? }; let content: C? }; let candidates: [Candidate]? }
        for try await line in try await openStream(req).lines {
            guard let payload = sseData(line), let data = payload.data(using: .utf8) else { continue }
            guard let chunk = try? JSONDecoder().decode(Chunk.self, from: data) else { continue }
            let text = chunk.candidates?.first?.content?.parts?.compactMap(\.text).joined() ?? ""
            if !text.isEmpty { continuation.yield(text) }
        }
    }

    private func streamOllama(_ request: CompletionRequest, model: String, _ resolved: ResolvedConfiguration, into continuation: AsyncThrowingStream<String, Error>.Continuation) async throws {
        let url = endpoint(try base(resolved), "api/chat")
        struct Message: Encodable { let role: String; let content: String }
        struct Body: Encodable { let model: String; let messages: [Message]; let stream: Bool }
        let body = Body(model: model, messages: request.messages.map { Message(role: $0.role.rawValue, content: $0.content) }, stream: true)
        let req = makeRequest(url, method: "POST", body: try JSONEncoder().encode(body))
        // Ollama streams newline-delimited JSON, not SSE.
        struct Chunk: Decodable { struct Msg: Decodable { let content: String }; let message: Msg? }
        for try await line in try await openStream(req).lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { continue }
            guard let chunk = try? JSONDecoder().decode(Chunk.self, from: data) else { continue }
            if let text = chunk.message?.content, !text.isEmpty { continuation.yield(text) }
        }
    }
}

private extension String {
    /// Trim noisy error bodies to a readable length.
    func prefixForError(_ max: Int = 300) -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count > max ? String(trimmed.prefix(max)) + "…" : trimmed
    }
}
