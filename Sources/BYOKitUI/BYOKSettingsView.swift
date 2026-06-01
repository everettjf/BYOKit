import SwiftUI
import BYOKitCore
import BYOKitStore
import BYOKitClient

/// The drop-in configuration center. Lists configured providers, supports adding
/// (with onboarding), editing, reordering, deleting, and choosing the active one.
///
/// Provide a `ConfigurationStore` via `.environmentObject(_:)` once at the app
/// root, then this is a one-liner:
/// ```swift
/// BYOKSettingsView()
///     .byokClient(DefaultLLMClient())
/// ```
public struct BYOKSettingsView: View {
    @EnvironmentObject private var store: ConfigurationStore
    @Environment(\.byokProvidersOverride) private var providersOverride
    @Environment(\.byokProviderFilter) private var providerFilter
    @Environment(\.byokRegistry) private var registry
    @Environment(\.byokTheme) private var theme

    @State private var providers: [Provider] = []
    @State private var addFlowPresented = false

    public init() {}

    public var body: some View {
        NavigationStack {
            content
                .navigationTitle("AI Providers")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            addFlowPresented = true
                        } label: {
                            Label("Add", systemImage: "plus")
                        }
                        .disabled(providers.isEmpty)
                    }
                }
                .navigationDestination(for: UUID.self) { id in
                    editDestination(for: id)
                }
                .sheet(isPresented: $addFlowPresented) {
                    AddConfigurationFlow(providers: providers) { config, key in
                        try? store.add(config, apiKey: key)
                        addFlowPresented = false
                    }
                }
        }
        .task { await loadProviders() }
    }

    @ViewBuilder
    private var content: some View {
        if store.configurations.isEmpty {
            emptyState
        } else {
            configurationList
        }
    }

    private var configurationList: some View {
        List {
            Section {
                ForEach(store.configurations) { config in
                    NavigationLink(value: config.id) {
                        ConfigurationRow(
                            config: config,
                            provider: provider(for: config.providerID),
                            isActive: store.activeConfigurationID == config.id
                        )
                    }
                    .contextMenu {
                        Button {
                            store.activeConfigurationID = config.id
                        } label: {
                            Label("Set as Active", systemImage: "checkmark.circle")
                        }
                        .disabled(store.activeConfigurationID == config.id || !config.isEnabled)

                        Button(role: .destructive) {
                            store.remove(config.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            store.remove(config.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onMove { store.move(fromOffsets: $0, toOffset: $1) }
            } footer: {
                Text("Tap to edit. The active provider is used by the app.")
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Providers Yet", systemImage: "key.horizontal")
        } description: {
            Text("Add an AI provider and your own API key to get started.")
        } actions: {
            Button {
                addFlowPresented = true
            } label: {
                Label("Add Provider", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(providers.isEmpty)
        }
    }

    @ViewBuilder
    private func editDestination(for id: UUID) -> some View {
        if let config = store.configuration(id), let provider = provider(for: config.providerID) {
            ProviderConfigForm(
                provider: provider,
                existing: config,
                apiKey: store.apiKey(for: id)
            ) { updated, key in
                store.update(updated)
                try? store.setAPIKey(key, for: updated.id)
            }
        } else {
            ContentUnavailableView("Unavailable", systemImage: "exclamationmark.triangle",
                                   description: Text("This provider is no longer available."))
        }
    }

    private func provider(for id: ProviderID) -> Provider? {
        providers.first { $0.id == id }
    }

    private func loadProviders() async {
        if let providersOverride {
            providers = providersOverride
        } else {
            providers = await registry.providers(providerFilter)
        }
    }
}

// MARK: - Row

private struct ConfigurationRow: View {
    let config: LLMConfiguration
    let provider: Provider?
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let provider {
                ProviderBadge(provider: provider, size: 36)
            } else {
                ProviderBadge(appearance: .init(symbolName: "questionmark"), size: 36)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(config.displayName).font(.body)
                    if isActive {
                        Text("Active")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.tint.opacity(0.15), in: Capsule())
                            .foregroundStyle(.tint)
                    }
                }
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !config.isEnabled {
                Image(systemName: "pause.circle").foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        let model = config.selectedModelID ?? "Default model"
        if let name = provider?.displayName, name != config.displayName {
            return "\(name) · \(model)"
        }
        return model
    }
}

// MARK: - Add flow

private struct AddConfigurationFlow: View {
    let providers: [Provider]
    let onAdd: (LLMConfiguration, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ProviderPickerView(providers: providers) { provider in
                path.append(provider)
            }
            .navigationDestination(for: Provider.self) { provider in
                ProviderConfigForm(provider: provider) { config, key in
                    onAdd(config, key)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
