import SwiftUI
import BYOKitCore

/// The "where do I get a key?" walkthrough — the piece most BYOK apps re-build
/// by hand. Renders a provider's structured `Onboarding` as a polished guide.
public struct OnboardingGuideView: View {
    public let provider: Provider
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    public init(provider: Provider) {
        self.provider = provider
    }

    private var onboarding: Onboarding { provider.onboarding }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if !onboarding.steps.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(onboarding.steps) { step in
                                stepRow(step)
                            }
                        }
                    }

                    if !onboarding.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(onboarding.notes.enumerated()), id: \.offset) { _, note in
                                Label(note, systemImage: "info.circle")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    linkButtons
                }
                .padding()
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(L("Get a Key"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Done")) { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ProviderBadge(provider: provider, size: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.displayName).font(.title2.bold())
                Text(L("Follow these steps to create your \(provider.credential.keyDisplayName)."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func stepRow(_ step: OnboardingStep) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(Color(hex: provider.appearance.tintHex).opacity(0.15))
                    .frame(width: 28, height: 28)
                if let symbol = step.symbolName {
                    Image(systemName: symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: provider.appearance.tintHex))
                } else {
                    Text(verbatim: "\(step.id)")
                        .font(.footnote.bold())
                        .foregroundStyle(Color(hex: provider.appearance.tintHex))
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(step.text).font(.body)
                if let url = step.actionURL {
                    Button {
                        openURL(url)
                    } label: {
                        Label(L("Open"), systemImage: "arrow.up.right.square")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderless)
                }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var linkButtons: some View {
        VStack(spacing: 10) {
            if let console = onboarding.consoleURL {
                Button {
                    openURL(console)
                } label: {
                    Label(L("Open \(provider.displayName) Console"), systemImage: "safari")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: provider.appearance.tintHex))
            }
            HStack(spacing: 10) {
                if let signUp = onboarding.signUpURL {
                    Button(L("Sign Up")) { openURL(signUp) }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                }
                if let docs = onboarding.docsURL {
                    Button(L("Docs")) { openURL(docs) }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                }
                if let pricing = onboarding.pricingURL {
                    Button(L("Pricing")) { openURL(pricing) }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
