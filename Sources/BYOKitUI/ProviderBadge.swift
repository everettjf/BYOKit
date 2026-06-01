import SwiftUI
import BYOKitCore

/// A tinted rounded badge identifying a provider — SF Symbol or monogram on the
/// brand color. Avoids shipping binary logos while still looking polished.
public struct ProviderBadge: View {
    public let appearance: ProviderAppearance
    public var size: CGFloat

    public init(appearance: ProviderAppearance, size: CGFloat = 36) {
        self.appearance = appearance
        self.size = size
    }

    public init(provider: Provider, size: CGFloat = 36) {
        self.appearance = provider.appearance
        self.size = size
    }

    private var tint: Color { Color(hex: appearance.tintHex) }

    public var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(tint.gradient)
            .frame(width: size, height: size)
            .overlay {
                if let symbol = appearance.symbolName {
                    Image(systemName: symbol)
                        .font(.system(size: size * 0.5, weight: .semibold))
                        .foregroundStyle(.white)
                } else {
                    Text(appearance.monogram ?? "?")
                        .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .padding(size * 0.12)
                        .foregroundStyle(.white)
                }
            }
            .accessibilityHidden(true)
    }
}
