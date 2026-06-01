import SwiftUI
import BYOKitClient

/// A self-contained "Test Connection" control: tap → spinner → inline ✅/❌ with
/// latency and message. Drive it with any async probe returning `ValidationResult`.
public struct ConnectionTestButton: View {
    public var title: String
    public var tint: Color
    public var action: () async throws -> ValidationResult
    /// Called with the result so the host (e.g. the form) can react, such as
    /// adopting the detected model list.
    public var onResult: (ValidationResult) -> Void

    @State private var phase: Phase = .idle

    private enum Phase {
        case idle, testing
        case done(ValidationResult)
    }

    public init(
        title: String = "Test Connection",
        tint: Color = .accentColor,
        action: @escaping () async throws -> ValidationResult,
        onResult: @escaping (ValidationResult) -> Void = { _ in }
    ) {
        self.title = title
        self.tint = tint
        self.action = action
        self.onResult = onResult
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Task { await run() }
            } label: {
                HStack(spacing: 8) {
                    if isTesting {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "bolt.horizontal.circle")
                    }
                    Text(title)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(tint)
            .disabled(isTesting)

            resultView
        }
    }

    private var isTesting: Bool {
        if case .testing = phase { return true }
        return false
    }

    @ViewBuilder
    private var resultView: some View {
        if case let .done(result) = phase {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: result.ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    .foregroundStyle(result.ok ? Color.green : Color.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.message ?? (result.ok ? "Connected." : "Failed."))
                        .font(.callout)
                        .foregroundStyle(result.ok ? Color.primary : Color.red)
                    if let latency = result.latency {
                        Text(String(format: "%.0f ms", latency * 1000))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .transition(.opacity)
        }
    }

    private func run() async {
        withAnimation { phase = .testing }
        let result: ValidationResult
        do {
            result = try await action()
        } catch let error as LLMClientError {
            result = ValidationResult(ok: false, message: error.errorDescription)
        } catch {
            result = ValidationResult(ok: false, message: error.localizedDescription)
        }
        withAnimation { phase = .done(result) }
        onResult(result)
    }
}
