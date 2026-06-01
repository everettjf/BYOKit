import SwiftUI
import AnyLLMCore

/// List of providers to choose from, grouped by kind, with search. Public so it
/// can be embedded directly (e.g. a custom add flow) as well as used internally.
public struct ProviderPickerView: View {
    let providers: [Provider]
    let onSelect: (Provider) -> Void

    @State private var search = ""

    public init(providers: [Provider], onSelect: @escaping (Provider) -> Void) {
        self.providers = providers
        self.onSelect = onSelect
    }

    private var filtered: [Provider] {
        guard !search.isEmpty else { return providers }
        return providers.filter { $0.displayName.localizedCaseInsensitiveContains(search) }
    }

    private var grouped: [(ProviderKind, [Provider])] {
        let order: [ProviderKind] = [.cloud, .compatible, .local]
        return order.compactMap { kind in
            let items = filtered.filter { $0.kind == kind }
            return items.isEmpty ? nil : (kind, items)
        }
    }

    public var body: some View {
        List {
            ForEach(grouped, id: \.0) { kind, items in
                Section(header: Text(sectionTitle(kind))) {
                    ForEach(items) { provider in
                        Button {
                            onSelect(provider)
                        } label: {
                            ProviderRow(provider: provider)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Search providers")
        .navigationTitle("Choose a Provider")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func sectionTitle(_ kind: ProviderKind) -> String {
        switch kind {
        case .cloud: return "Cloud"
        case .compatible: return "Compatible / Aggregators"
        case .local: return "Local"
        }
    }
}

private struct ProviderRow: View {
    let provider: Provider
    var body: some View {
        HStack(spacing: 12) {
            ProviderBadge(provider: provider, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.displayName).font(.body)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        if !provider.credential.requiresAPIKey { return "No API key required" }
        if let host = provider.defaultBaseURL?.host { return host }
        return "Custom endpoint"
    }
}
