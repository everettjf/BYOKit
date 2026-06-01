import Foundation

/// Resolves a localized string from BYOKitCore's own bundle. Used for the small
/// set of user-facing validation messages this layer produces (e.g. surfaced by
/// `KeyField`), so they match the host UI's language.
func L(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}

#if DEBUG
/// Test seam: resolve a key against a specific `.lproj` of BYOKitCore's bundle.
public func _byokCoreLocalized(_ key: String, language: String) -> String {
    let match = Bundle.module.localizations.first { $0.caseInsensitiveCompare(language) == .orderedSame } ?? language
    guard let path = Bundle.module.path(forResource: match, ofType: "lproj"),
          let bundle = Bundle(path: path) else { return key }
    return bundle.localizedString(forKey: key, value: "\u{0}", table: nil)
}
#endif
