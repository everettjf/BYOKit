import SwiftUI
import AnyLLMCore

/// A polished secret-entry field: masked by default, with reveal, paste, and
/// inline structural validation. Reusable on its own.
public struct KeyField: View {
    public let title: String
    @Binding public var text: String
    public var placeholder: String
    public var validation: KeyValidation?
    public var showsValidation: Bool

    @State private var isRevealed = false
    @FocusState private var focused: Bool

    public init(
        title: String,
        text: Binding<String>,
        placeholder: String = "",
        validation: KeyValidation? = nil,
        showsValidation: Bool = true
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.validation = validation
        self.showsValidation = showsValidation
    }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var invalidReason: String? {
        guard showsValidation, !trimmed.isEmpty, let validation else { return nil }
        return validation.reasonInvalid(for: trimmed)
    }
    private var looksValid: Bool {
        guard !trimmed.isEmpty else { return false }
        return validation?.reasonInvalid(for: trimmed) == nil
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Group {
                    if isRevealed {
                        TextField(placeholder, text: $text)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                .textFieldStyle(.plain)
                .focused($focused)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                #endif
                .font(.body.monospaced())

                if looksValid {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .transition(.opacity)
                        .accessibilityLabel("Key looks valid")
                }

                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(isRevealed ? "Hide key" : "Show key")

                if Platform.supportsPasteboardReads {
                    Button {
                        if let s = Platform.pasteboardString {
                            text = s.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Paste")
                }
            }

            if let reason = invalidReason {
                Label(reason, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: looksValid)
        .animation(.easeInOut(duration: 0.15), value: invalidReason)
    }
}
