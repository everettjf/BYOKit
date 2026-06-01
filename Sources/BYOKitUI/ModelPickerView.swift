import SwiftUI
import BYOKitCore

/// Selects a model: a picker over presets + fetched models, an optional refresh
/// to fetch live, and a manual "custom model id" escape hatch.
struct ModelPickerView: View {
    let models: [ModelInfo]
    @Binding var selectedModelID: String?
    @Binding var useCustomModel: Bool
    @Binding var customModelID: String
    let supportsRefresh: Bool
    let isRefreshing: Bool
    let onRefresh: () -> Void
    let tint: Color

    var body: some View {
        if !models.isEmpty && !useCustomModel {
            Picker(L("Model"), selection: Binding(
                get: { selectedModelID ?? models.first?.id },
                set: { selectedModelID = $0 }
            )) {
                ForEach(models) { model in
                    ModelRow(model: model).tag(Optional(model.id))
                }
            }
            #if os(iOS)
            .pickerStyle(.navigationLink)
            #endif
        }

        if useCustomModel {
            TextField(L("Model ID"), text: $customModelID)
                .font(.body.monospaced())
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                #endif
        }

        Toggle(L("Enter model ID manually"), isOn: $useCustomModel.animation())
            .font(.callout)

        if supportsRefresh {
            Button {
                onRefresh()
            } label: {
                HStack {
                    if isRefreshing {
                        ProgressView().controlSize(.small)
                        Text(L("Fetching models…"))
                    } else {
                        Image(systemName: "arrow.clockwise")
                        Text(L("Refresh model list"))
                    }
                }
            }
            .disabled(isRefreshing)
            .tint(tint)
        }
    }
}

private struct ModelRow: View {
    let model: ModelInfo
    var body: some View {
        HStack {
            Text(model.displayName)
            if !model.capabilities.isEmpty {
                Spacer()
                ForEach(Array(model.capabilities).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { cap in
                    Image(systemName: symbol(for: cap))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func symbol(for capability: ModelCapability) -> String {
        switch capability {
        case .vision: return "eye"
        case .tools: return "wrench.and.screwdriver"
        case .reasoning: return "brain"
        case .audio: return "waveform"
        }
    }
}
