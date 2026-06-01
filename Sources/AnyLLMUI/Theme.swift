import SwiftUI

/// Visual styling for AnyLLM's components. Inject via `.anyLLMTheme(_:)` to make
/// the configuration UI match the host app.
public struct AnyLLMTheme: Sendable {
    /// Optional accent override. When nil, each provider's brand tint is used.
    public var accent: Color?
    public var cornerRadius: CGFloat

    public init(accent: Color? = nil, cornerRadius: CGFloat = 12) {
        self.accent = accent
        self.cornerRadius = cornerRadius
    }

    public static let `default` = AnyLLMTheme()
}

public extension Color {
    /// Initialize from a hex string like `"#10A37F"` or `"10A37F"`.
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")).uppercased()
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r, g, b, a: Double
        switch s.count {
        case 8: // RRGGBBAA
            r = Double((value & 0xFF000000) >> 24) / 255
            g = Double((value & 0x00FF0000) >> 16) / 255
            b = Double((value & 0x0000FF00) >> 8) / 255
            a = Double(value & 0x000000FF) / 255
        case 6: // RRGGBB
            r = Double((value & 0xFF0000) >> 16) / 255
            g = Double((value & 0x00FF00) >> 8) / 255
            b = Double(value & 0x0000FF) / 255
            a = 1
        default:
            r = 0.36; g = 0.36; b = 0.84; a = 1 // fallback indigo
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
