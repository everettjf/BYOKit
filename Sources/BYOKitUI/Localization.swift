import Foundation

/// Resolves a localized string from BYOKit's own bundle (`Localizable.xcstrings`).
///
/// SwiftUI's `Text`/`Label`/etc. localize against the *main* app bundle by
/// default, not a package's bundle. Resolving here against `Bundle.module` and
/// passing the result as a plain `String` keeps every call site uniform and
/// correct, regardless of which view modifier consumes it.
func L(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}

#if DEBUG
/// Test seam: resolve a key against a specific `.lproj` to verify the shipped
/// `Localizable.strings` tables actually contain the expected translations.
/// (A `locale:` argument only affects formatting, not which table is loaded, so
/// we load the language's sub-bundle directly.)
func _localized(_ key: String, language: String) -> String {
    // SwiftPM lowercases `.lproj` folder names in the built bundle; match
    // case-insensitively the way the system's runtime localization lookup does.
    let match = Bundle.module.localizations.first { $0.caseInsensitiveCompare(language) == .orderedSame } ?? language
    guard let path = Bundle.module.path(forResource: match, ofType: "lproj"),
          let bundle = Bundle(path: path) else { return key }
    return bundle.localizedString(forKey: key, value: "\u{0}", table: nil)
}
#endif
