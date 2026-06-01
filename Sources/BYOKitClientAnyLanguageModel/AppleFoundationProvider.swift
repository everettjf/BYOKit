import Foundation
import BYOKitCore

public extension ProviderID {
    /// On-device Apple Foundation Models ("Apple Intelligence").
    static let appleFoundation: ProviderID = "apple-foundation"
}

public extension Provider {
    /// The on-device Apple Foundation Models provider. Serviced only by
    /// `AnyLanguageModelClient` (no API key, no network). Add it to the catalog
    /// you pass to the UI, e.g. `.byokProviders(builtins + [.appleFoundationModels])`.
    static var appleFoundationModels: Provider {
        Provider(
            id: .appleFoundation,
            displayName: "Apple Intelligence",
            kind: .local,
            apiFormat: .custom,
            appearance: .init(symbolName: "apple.logo", monogram: "AI", tintHex: "#1D1D1F"),
            defaultBaseURL: nil,
            allowsCustomBaseURL: false,
            credential: .init(requiresAPIKey: false, keyDisplayName: "API Key"),
            onboarding: .init(
                docsURL: URL(string: "https://developer.apple.com/documentation/foundationmodels"),
                steps: [
                    .init(id: 1, text: "Runs entirely on-device — no API key, no cost.", symbolName: "lock.shield"),
                    .init(id: 2, text: "Requires a device with Apple Intelligence enabled.", symbolName: "iphone"),
                    .init(id: 3, text: "Test the connection to confirm availability.", symbolName: "bolt.horizontal.circle"),
                ],
                notes: ["Available on Apple Intelligence-capable devices running a recent OS."]
            ),
            models: .init(
                presets: [ModelInfo(id: "default", displayName: "On-device", capabilities: [.tools])],
                supportsDynamicListing: false
            )
        )
    }
}
