import Foundation
import BYOKitCore
import BYOKitClient
import AnyLanguageModel

/// An `LLMClient` that adds **on-device Apple Foundation Models** support via the
/// [AnyLanguageModel](https://github.com/huggingface/AnyLanguageModel) package,
/// and delegates everything else (cloud / HTTP providers) to a wrapped fallback
/// client — `DefaultLLMClient` by default, which handles custom BYOK endpoints
/// better than routing them through a third-party SDK.
///
/// ```swift
/// AnyLLMSettingsView... // or BYOKSettingsView()
/// BYOKSettingsView()
///     .byokClient(AnyLanguageModelClient())
///     .byokProviders(builtins + [.appleFoundationModels])
/// ```
///
/// To extend with MLX / llama.cpp local models, enable the matching trait on the
/// `AnyLanguageModel` dependency in your app and add provider entries for them.
public struct AnyLanguageModelClient: LLMClient {
    /// Client used for every provider this adapter doesn't service natively.
    public let fallback: any LLMClient

    public init(fallback: any LLMClient = DefaultLLMClient()) {
        self.fallback = fallback
    }

    private func isApple(_ provider: Provider) -> Bool {
        provider.id == .appleFoundation
    }

    // MARK: - LLMClient

    public func validate(_ resolved: ResolvedConfiguration) async throws -> ValidationResult {
        guard isApple(resolved.provider) else { return try await fallback.validate(resolved) }
        let start = Date()
        let (ok, message) = appleAvailability()
        return ValidationResult(
            ok: ok,
            latency: Date().timeIntervalSince(start),
            detectedModels: ok ? appleModels() : nil,
            message: message
        )
    }

    public func listModels(_ resolved: ResolvedConfiguration) async throws -> [ModelInfo] {
        guard isApple(resolved.provider) else { return try await fallback.listModels(resolved) }
        return appleModels()
    }

    public func complete(_ request: CompletionRequest, with resolved: ResolvedConfiguration) async throws -> CompletionResponse {
        guard isApple(resolved.provider) else { return try await fallback.complete(request, with: resolved) }
        return try await completeWithAppleFoundationModels(request)
    }

    // MARK: - Apple Foundation Models

    private func appleModels() -> [ModelInfo] {
        [ModelInfo(id: "default", displayName: "On-device (Apple Intelligence)", capabilities: [.tools])]
    }

    private func appleAvailability() -> (ok: Bool, message: String) {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return (true, "Apple Intelligence is available on this device.")
            case .unavailable(let reason):
                return (false, "Apple Intelligence is unavailable: \(String(describing: reason)).")
            }
        } else {
            return (false, "Apple Foundation Models require a newer OS version.")
        }
        #else
        return (false, "This build was compiled without Foundation Models support.")
        #endif
    }

    private func completeWithAppleFoundationModels(_ request: CompletionRequest) async throws -> CompletionResponse {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard case .available = model.availability else {
                throw LLMClientError.unsupported("Apple Intelligence is not available on this device.")
            }
            let system = request.messages.filter { $0.role == .system }.map(\.content).joined(separator: "\n\n")
            let userText = request.messages.filter { $0.role != .system }.map(\.content).joined(separator: "\n\n")

            let session = system.isEmpty
                ? LanguageModelSession(model: model)
                : LanguageModelSession(model: model, instructions: system)
            let response = try await session.respond(to: userText)
            return CompletionResponse(text: response.content, modelID: "apple-foundation")
        } else {
            throw LLMClientError.unsupported("Apple Foundation Models require a newer OS version.")
        }
        #else
        throw LLMClientError.unsupported("This build was compiled without Foundation Models support.")
        #endif
    }
}
