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

    /// Providers this adapter services natively (everything else delegates).
    private func isNative(_ provider: Provider) -> Bool {
        switch provider.id {
        case .appleFoundation, .mlx, .llama: return true
        default: return false
        }
    }

    // MARK: - LLMClient

    public func validate(_ resolved: ResolvedConfiguration) async throws -> ValidationResult {
        guard isNative(resolved.provider) else { return try await fallback.validate(resolved) }
        let start = Date()
        let (ok, message) = nativeReadiness(resolved)
        return ValidationResult(
            ok: ok,
            latency: Date().timeIntervalSince(start),
            detectedModels: ok ? nativeModels(resolved) : nil,
            message: message
        )
    }

    public func listModels(_ resolved: ResolvedConfiguration) async throws -> [ModelInfo] {
        guard isNative(resolved.provider) else { return try await fallback.listModels(resolved) }
        return nativeModels(resolved)
    }

    public func complete(_ request: CompletionRequest, with resolved: ResolvedConfiguration) async throws -> CompletionResponse {
        switch resolved.provider.id {
        case .appleFoundation: return try await completeWithAppleFoundationModels(request)
        case .mlx:             return try await completeWithMLX(request, resolved)
        case .llama:           return try await completeWithLlama(request, resolved)
        default:               return try await fallback.complete(request, with: resolved)
        }
    }

    public func streamComplete(_ request: CompletionRequest, with resolved: ResolvedConfiguration) -> AsyncThrowingStream<String, Error> {
        switch resolved.provider.id {
        case .appleFoundation:
            return streamAppleFoundationModels(request)
        case .mlx:
            #if MLX
            guard let id = resolved.modelID, !id.isEmpty else { return errorStream(.missingModel) }
            return streamRun(request, on: MLXLanguageModel(modelId: id))
            #else
            return errorStream(.unsupported("MLX support is not enabled. Add the \"MLX\" trait to your BYOKit dependency."))
            #endif
        case .llama:
            #if Llama
            let path = resolved.configuration.extraValues[byokLlamaModelPathField] ?? ""
            guard !path.isEmpty else { return errorStream(.missingModel) }
            return streamRun(request, on: LlamaLanguageModel(modelPath: path))
            #else
            return errorStream(.unsupported("llama.cpp support is not enabled. Add the \"Llama\" trait to your BYOKit dependency."))
            #endif
        default:
            return fallback.streamComplete(request, with: resolved)
        }
    }

    /// A stream that immediately fails with the given error.
    private func errorStream(_ error: LLMClientError) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish(throwing: error) }
    }

    private func streamAppleFoundationModels(_ request: CompletionRequest) -> AsyncThrowingStream<String, Error> {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard case .available = model.availability else {
                return errorStream(.unsupported("Apple Intelligence is not available on this device."))
            }
            return streamSession(request, makeSession: { system in
                system.isEmpty ? LanguageModelSession(model: model) : LanguageModelSession(model: model, instructions: system)
            })
        } else {
            return errorStream(.unsupported("Apple Foundation Models require a newer OS version."))
        }
        #else
        return errorStream(.unsupported("This build was compiled without Foundation Models support."))
        #endif
    }

    /// Streams a prompt through any AnyLanguageModel model, converting the SDK's
    /// cumulative snapshots into incremental deltas.
    private func streamRun<M: LanguageModel>(_ request: CompletionRequest, on model: M) -> AsyncThrowingStream<String, Error> {
        streamSession(request, makeSession: { system in
            system.isEmpty ? LanguageModelSession(model: model) : LanguageModelSession(model: model, instructions: system)
        })
    }

    private func streamSession(_ request: CompletionRequest, makeSession: @escaping @Sendable (String) -> LanguageModelSession) -> AsyncThrowingStream<String, Error> {
        let system = request.messages.filter { $0.role == .system }.map(\.content).joined(separator: "\n\n")
        let userText = request.messages.filter { $0.role != .system }.map(\.content).joined(separator: "\n\n")
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let session = makeSession(system)
                    // The SDK's String streaming requires `String: Generable`, which
                    // is macOS/iOS 26+ only. On older OSes, fall back to one shot.
                    if #available(iOS 26.0, macOS 26.0, *) {
                        var previous = ""
                        for try await snapshot in session.streamResponse(to: userText) {
                            // Snapshots are cumulative; emit only the new suffix.
                            let current = snapshot.content
                            if current.hasPrefix(previous) {
                                let delta = String(current.dropFirst(previous.count))
                                if !delta.isEmpty { continuation.yield(delta) }
                            } else if !current.isEmpty {
                                continuation.yield(current)
                            }
                            previous = current
                        }
                    } else {
                        let response = try await session.respond(to: userText)
                        if !response.content.isEmpty { continuation.yield(response.content) }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Native readiness / models

    private func nativeReadiness(_ resolved: ResolvedConfiguration) -> (ok: Bool, message: String) {
        switch resolved.provider.id {
        case .appleFoundation: return appleAvailability()
        case .mlx:             return mlxReadiness(resolved)
        case .llama:           return llamaReadiness(resolved)
        default:               return (false, "Unsupported provider.")
        }
    }

    private func nativeModels(_ resolved: ResolvedConfiguration) -> [ModelInfo] {
        switch resolved.provider.id {
        case .appleFoundation:
            return appleModels()
        case .mlx:
            if let id = resolved.modelID, !id.isEmpty { return [ModelInfo(id: id)] }
            return resolved.provider.models.presets
        case .llama:
            let path = resolved.configuration.extraValues[byokLlamaModelPathField] ?? ""
            let name = (path as NSString).lastPathComponent
            return path.isEmpty ? [] : [ModelInfo(id: path, displayName: name)]
        default:
            return []
        }
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

    // MARK: - MLX (Apple Silicon, gated by the `MLX` trait)

    private func mlxReadiness(_ resolved: ResolvedConfiguration) -> (ok: Bool, message: String) {
        #if MLX
        guard let id = resolved.modelID, !id.isEmpty else {
            return (false, "Enter a Hugging Face MLX model id (e.g. mlx-community/Qwen3-0.6B-4bit).")
        }
        return (true, "MLX backend ready. \"\(id)\" downloads/loads on first use.")
        #else
        return (false, "Rebuild with BYOKit's \"MLX\" trait enabled to use on-device MLX models.")
        #endif
    }

    private func completeWithMLX(_ request: CompletionRequest, _ resolved: ResolvedConfiguration) async throws -> CompletionResponse {
        #if MLX
        guard let id = resolved.modelID, !id.isEmpty else { throw LLMClientError.missingModel }
        let model = MLXLanguageModel(modelId: id)
        return try await run(request, on: model, modelID: id)
        #else
        throw LLMClientError.unsupported("MLX support is not enabled. Add the \"MLX\" trait to your BYOKit dependency.")
        #endif
    }

    // MARK: - llama.cpp / GGUF (gated by the `Llama` trait)

    private func llamaReadiness(_ resolved: ResolvedConfiguration) -> (ok: Bool, message: String) {
        let path = resolved.configuration.extraValues[byokLlamaModelPathField] ?? ""
        #if Llama
        guard !path.isEmpty else { return (false, "Enter the path to a .gguf model file.") }
        guard FileManager.default.fileExists(atPath: path) else {
            return (false, "No file found at \"\(path)\".")
        }
        return (true, "llama.cpp backend ready. Model loads on first use.")
        #else
        return (false, "Rebuild with BYOKit's \"Llama\" trait enabled to use GGUF models.")
        #endif
    }

    private func completeWithLlama(_ request: CompletionRequest, _ resolved: ResolvedConfiguration) async throws -> CompletionResponse {
        let path = resolved.configuration.extraValues[byokLlamaModelPathField] ?? ""
        #if Llama
        guard !path.isEmpty else { throw LLMClientError.missingModel }
        let model = LlamaLanguageModel(modelPath: path)
        let name = (path as NSString).lastPathComponent
        return try await run(request, on: model, modelID: name)
        #else
        throw LLMClientError.unsupported("llama.cpp support is not enabled. Add the \"Llama\" trait to your BYOKit dependency.")
        #endif
    }

    // MARK: - Shared session runner

    /// Runs a prompt through any AnyLanguageModel model and returns the text.
    private func run<M: LanguageModel>(_ request: CompletionRequest, on model: M, modelID: String) async throws -> CompletionResponse {
        let system = request.messages.filter { $0.role == .system }.map(\.content).joined(separator: "\n\n")
        let userText = request.messages.filter { $0.role != .system }.map(\.content).joined(separator: "\n\n")
        let session = system.isEmpty
            ? LanguageModelSession(model: model)
            : LanguageModelSession(model: model, instructions: system)
        let response = try await session.respond(to: userText)
        return CompletionResponse(text: response.content, modelID: modelID)
    }
}
