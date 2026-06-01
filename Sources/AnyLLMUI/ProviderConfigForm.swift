import SwiftUI
import AnyLLMCore
import AnyLLMClient

/// The per-provider configuration form: name, key (with onboarding), base URL,
/// model, connection test. Used for both adding and editing.
public struct ProviderConfigForm: View {
    @StateObject private var model: ProviderConfigModel
    let onSave: (LLMConfiguration, _ apiKey: String) -> Void

    @Environment(\.anyLLMClient) private var client
    @Environment(\.anyLLMShowsOnboarding) private var showsOnboarding
    @Environment(\.anyLLMTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var showingOnboarding = false

    public init(
        provider: Provider,
        existing: LLMConfiguration? = nil,
        apiKey: String? = nil,
        onSave: @escaping (LLMConfiguration, String) -> Void
    ) {
        _model = StateObject(wrappedValue: ProviderConfigModel(provider: provider, existing: existing, apiKey: apiKey))
        self.onSave = onSave
    }

    private var tint: Color { theme.accent ?? Color(hex: model.provider.appearance.tintHex) }

    public var body: some View {
        Form {
            headerSection
            if model.provider.credential.requiresAPIKey || !model.provider.credential.extraFields.isEmpty {
                credentialSection
            }
            if model.provider.allowsCustomBaseURL || model.provider.defaultBaseURL != nil {
                endpointSection
            }
            modelSection
            testSection
            if model.isEditing { generalSection }
        }
        .anyLLMFormStyle()
        .navigationTitle(model.isEditing ? model.displayName : "Add \(model.provider.displayName)")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(model.makeConfiguration(), model.apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
                    dismiss()
                }
                .disabled(!model.canSave)
            }
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingGuideView(provider: model.provider)
        }
    }

    // MARK: Sections

    private var headerSection: some View {
        Section {
            HStack(spacing: 14) {
                ProviderBadge(provider: model.provider, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.provider.displayName).font(.headline)
                    Text(kindLabel).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)

            TextField("Display name", text: $model.displayName)
        }
    }

    private var credentialSection: some View {
        Section {
            if model.provider.credential.requiresAPIKey {
                KeyField(
                    title: model.provider.credential.keyDisplayName,
                    text: $model.apiKey,
                    placeholder: model.provider.credential.keyDisplayName,
                    validation: model.provider.credential.validation
                )
            }
            ForEach(model.provider.credential.extraFields) { field in
                extraFieldRow(field)
            }
        } header: {
            Text(model.provider.credential.keyDisplayName)
        } footer: {
            if showsOnboarding, model.provider.onboarding.hasContent {
                Button {
                    showingOnboarding = true
                } label: {
                    Label("Don't have a key? Get one", systemImage: "questionmark.circle")
                        .font(.callout)
                }
                .buttonStyle(.borderless)
                .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private func extraFieldRow(_ field: CredentialField) -> some View {
        let binding = Binding(
            get: { model.extraValues[field.id] ?? "" },
            set: { model.extraValues[field.id] = $0 }
        )
        if field.isSecret {
            KeyField(title: field.label, text: binding, placeholder: field.placeholder ?? field.label)
        } else {
            TextField(field.placeholder ?? field.label, text: binding)
        }
    }

    private var endpointSection: some View {
        Section {
            if model.provider.allowsCustomBaseURL {
                TextField("Base URL", text: $model.baseURLString)
                    .font(.body.monospaced())
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.URL)
                    #endif
            } else if let url = model.provider.defaultBaseURL {
                LabeledContent("Endpoint", value: url.absoluteString)
                    .font(.callout)
            }
        } header: {
            Text("Endpoint")
        } footer: {
            if model.requiresBaseURLEntry {
                Text("Enter the base URL of an OpenAI-compatible endpoint.")
            }
        }
    }

    private var modelSection: some View {
        Section("Model") {
            ModelPickerView(
                models: model.availableModels,
                selectedModelID: $model.selectedModelID,
                useCustomModel: $model.useCustomModel,
                customModelID: $model.customModelID,
                supportsRefresh: model.provider.models.supportsDynamicListing,
                isRefreshing: model.isRefreshingModels,
                onRefresh: refreshModels,
                tint: tint
            )
        }
    }

    private var testSection: some View {
        Section {
            ConnectionTestButton(tint: tint) {
                try await client.validate(model.makeResolved())
            } onResult: { result in
                if let detected = result.detectedModels { model.adopt(detectedModels: detected) }
            }
        }
    }

    private var generalSection: some View {
        Section {
            Toggle("Enabled", isOn: $model.isEnabled)
        }
    }

    private var kindLabel: String {
        switch model.provider.kind {
        case .cloud: return "Cloud provider"
        case .local: return "Local — runs on your machine"
        case .compatible: return "OpenAI-compatible endpoint"
        }
    }

    private func refreshModels() {
        model.isRefreshingModels = true
        Task {
            let resolved = model.makeResolved()
            let fetched = (try? await client.listModels(resolved)) ?? []
            await MainActor.run {
                model.adopt(detectedModels: fetched)
                model.isRefreshingModels = false
            }
        }
    }
}
