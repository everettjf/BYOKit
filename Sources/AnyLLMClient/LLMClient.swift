import Foundation
import AnyLLMCore

/// A provider + a user configuration + its resolved secret — everything needed
/// to actually talk to an endpoint.
public struct ResolvedConfiguration: Sendable {
    public var provider: Provider
    public var configuration: LLMConfiguration
    public var apiKey: String?
    public var secrets: [String: String]

    public init(
        provider: Provider,
        configuration: LLMConfiguration,
        apiKey: String? = nil,
        secrets: [String: String] = [:]
    ) {
        self.provider = provider
        self.configuration = configuration
        self.apiKey = apiKey
        self.secrets = secrets
    }

    /// Effective base URL (config override → provider default).
    public var baseURL: URL? { configuration.resolvedBaseURL(for: provider) }

    /// Effective model id (selected → first preset).
    public var modelID: String? {
        configuration.selectedModelID ?? provider.models.presets.first?.id
    }
}

/// The result of probing a configuration for validity.
public struct ValidationResult: Sendable {
    public var ok: Bool
    public var latency: TimeInterval?
    public var detectedModels: [ModelInfo]?
    public var message: String?

    public init(ok: Bool, latency: TimeInterval? = nil, detectedModels: [ModelInfo]? = nil, message: String? = nil) {
        self.ok = ok
        self.latency = latency
        self.detectedModels = detectedModels
        self.message = message
    }
}

public enum ChatRole: String, Sendable, Codable {
    case system, user, assistant
}

public struct ChatMessage: Sendable, Codable {
    public var role: ChatRole
    public var content: String
    public init(role: ChatRole, content: String) {
        self.role = role
        self.content = content
    }
    public static func system(_ s: String) -> ChatMessage { .init(role: .system, content: s) }
    public static func user(_ s: String) -> ChatMessage { .init(role: .user, content: s) }
    public static func assistant(_ s: String) -> ChatMessage { .init(role: .assistant, content: s) }
}

public struct CompletionRequest: Sendable {
    public var messages: [ChatMessage]
    /// Overrides the configuration's selected model when set.
    public var model: String?
    public var maxTokens: Int?
    public var temperature: Double?

    public init(messages: [ChatMessage], model: String? = nil, maxTokens: Int? = nil, temperature: Double? = nil) {
        self.messages = messages
        self.model = model
        self.maxTokens = maxTokens
        self.temperature = temperature
    }

    public static func text(_ prompt: String) -> CompletionRequest {
        .init(messages: [.user(prompt)])
    }
}

public struct CompletionResponse: Sendable {
    public var text: String
    public var modelID: String?
    public init(text: String, modelID: String? = nil) {
        self.text = text
        self.modelID = modelID
    }
}

public enum LLMClientError: Error, Sendable, LocalizedError, Equatable {
    case missingAPIKey
    case missingBaseURL
    case missingModel
    case invalidURL
    case http(status: Int, body: String?)
    case decoding(String)
    case transport(String)
    case unsupported(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "An API key is required."
        case .missingBaseURL: return "A base URL is required."
        case .missingModel: return "No model selected."
        case .invalidURL: return "The endpoint URL is invalid."
        case let .http(status, body):
            let detail = (body?.isEmpty == false) ? ": \(body!)" : ""
            return "Request failed (HTTP \(status))\(detail)"
        case let .decoding(msg): return "Unexpected response from the server. \(msg)"
        case let .transport(msg): return "Couldn't reach the server. \(msg)"
        case let .unsupported(msg): return msg
        }
    }
}

/// Abstraction over "talking to an LLM provider". The default implementation is
/// `DefaultLLMClient` (URLSession). Swap in another (e.g. an AnyLanguageModel
/// adapter) without touching the UI.
public protocol LLMClient: Sendable {
    /// Probe credentials/endpoint. Should be cheap and side-effect free.
    func validate(_ resolved: ResolvedConfiguration) async throws -> ValidationResult
    /// Live list of available models, when the provider supports it.
    func listModels(_ resolved: ResolvedConfiguration) async throws -> [ModelInfo]
    /// Send a completion request.
    func complete(_ request: CompletionRequest, with resolved: ResolvedConfiguration) async throws -> CompletionResponse
}
