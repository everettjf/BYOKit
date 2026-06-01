import SwiftUI

/// Small cross-platform shims so the UI reads identically on iOS / iPadOS / macOS.
enum Platform {
    /// Current clipboard string, if any.
    static var pasteboardString: String? {
        #if canImport(UIKit)
        return UIPasteboard.general.string
        #elseif canImport(AppKit)
        return NSPasteboard.general.string(forType: .string)
        #else
        return nil
        #endif
    }

    static var supportsPasteboardReads: Bool {
        #if canImport(UIKit) || canImport(AppKit)
        return true
        #else
        return false
        #endif
    }
}

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension View {
    /// Grouped form styling that looks right on every platform.
    @ViewBuilder
    func anyLLMFormStyle() -> some View {
        #if os(macOS)
        self.formStyle(.grouped)
        #else
        self
        #endif
    }
}
