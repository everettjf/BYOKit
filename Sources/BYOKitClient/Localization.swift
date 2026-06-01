import Foundation

/// Resolves a localized string from BYOKitClient's own bundle. Covers the
/// user-facing error and connection-test messages this layer produces (surfaced
/// e.g. by `ConnectionTestButton`), so they match the host UI's language.
func L(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}

#if DEBUG
/// Test seam: resolve a key against a specific `.lproj` of BYOKitClient's bundle.
public func _byokClientLocalized(_ key: String, language: String) -> String {
    let match = Bundle.module.localizations.first { $0.caseInsensitiveCompare(language) == .orderedSame } ?? language
    guard let path = Bundle.module.path(forResource: match, ofType: "lproj"),
          let bundle = Bundle(path: path) else { return key }
    return bundle.localizedString(forKey: key, value: "\u{0}", table: nil)
}
#endif
