import SwiftUI
import AnyLLMCore
import AnyLLMClient

/// Backing state for `ProviderConfigForm`: the editable draft plus dynamically
/// fetched models. Pure state — async work is driven by the view using the
/// injected `LLMClient`.
@MainActor
final class ProviderConfigModel: ObservableObject {
    let provider: Provider
    let existingID: UUID?

    @Published var displayName: String
    @Published var apiKey: String
    @Published var baseURLString: String
    @Published var selectedModelID: String?
    @Published var customModelID: String = ""
    @Published var useCustomModel: Bool = false
    @Published var extraValues: [String: String]
    @Published var isEnabled: Bool
    @Published var dynamicModels: [ModelInfo] = []
    @Published var isRefreshingModels = false

    init(provider: Provider, existing: LLMConfiguration? = nil, apiKey: String? = nil) {
        self.provider = provider
        self.existingID = existing?.id
        self.displayName = existing?.displayName ?? provider.displayName
        self.apiKey = apiKey ?? ""
        self.baseURLString = existing?.baseURL?.absoluteString
            ?? (provider.allowsCustomBaseURL ? (provider.defaultBaseURL?.absoluteString ?? "") : "")
        self.selectedModelID = existing?.selectedModelID ?? provider.models.presets.first?.id
        self.extraValues = existing?.extraValues ?? [:]
        self.isEnabled = existing?.isEnabled ?? true

        // If the saved model isn't in the presets, treat it as a custom entry.
        if let sel = self.selectedModelID, !provider.models.presets.contains(where: { $0.id == sel }) {
            self.useCustomModel = true
            self.customModelID = sel
        }
    }

    var isEditing: Bool { existingID != nil }

    /// Presets + dynamically fetched models, de-duplicated by id (presets win).
    var availableModels: [ModelInfo] {
        var seen = Set(provider.models.presets.map(\.id))
        var result = provider.models.presets
        for m in dynamicModels where !seen.contains(m.id) {
            seen.insert(m.id)
            result.append(m)
        }
        return result
    }

    var parsedBaseURL: URL? {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }

    var effectiveModelID: String? {
        useCustomModel ? customModelID.trimmingCharacters(in: .whitespacesAndNewlines) : selectedModelID
    }

    var requiresBaseURLEntry: Bool {
        provider.defaultBaseURL == nil && provider.allowsCustomBaseURL
    }

    var canSave: Bool {
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if provider.credential.requiresAPIKey, apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        if requiresBaseURLEntry, parsedBaseURL == nil { return false }
        return true
    }

    func makeConfiguration() -> LLMConfiguration {
        LLMConfiguration(
            id: existingID ?? UUID(),
            providerID: provider.id,
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            baseURL: parsedBaseURL,
            selectedModelID: effectiveModelID,
            extraValues: extraValues,
            isEnabled: isEnabled
        )
    }

    func makeResolved() -> ResolvedConfiguration {
        ResolvedConfiguration(
            provider: provider,
            configuration: makeConfiguration(),
            apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            secrets: [:]
        )
    }

    func adopt(detectedModels: [ModelInfo]) {
        guard !detectedModels.isEmpty else { return }
        dynamicModels = detectedModels
    }
}
