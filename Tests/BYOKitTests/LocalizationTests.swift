import XCTest
@testable import BYOKitUI
import BYOKitCore
import BYOKitClient

/// Verifies the shipped `Localizable.strings` tables resolve against BYOKitUI's
/// own bundle for both languages — guarding against missing/typo'd keys and the
/// SwiftPM-vs-Xcode catalog-compilation pitfall.
final class LocalizationTests: XCTestCase {

    func testEnglishResolvesToSource() {
        XCTAssertEqual(_localized("Test Connection", language: "en"), "Test Connection")
        XCTAssertEqual(_localized("AI Providers", language: "en"), "AI Providers")
    }

    func testChineseTranslationsArePresent() {
        XCTAssertEqual(_localized("Test Connection", language: "zh-Hans"), "测试连接")
        XCTAssertEqual(_localized("AI Providers", language: "zh-Hans"), "AI 服务商")
        XCTAssertEqual(_localized("Save", language: "zh-Hans"), "保存")
        XCTAssertEqual(_localized("Get a Key", language: "zh-Hans"), "获取 Key")
        XCTAssertEqual(_localized("Connected.", language: "zh-Hans"), "连接成功。")
    }

    func testInterpolatedKeysTranslate() {
        XCTAssertEqual(_localized("Add %@", language: "zh-Hans"), "添加 %@")
        XCTAssertEqual(_localized("Open %@ Console", language: "zh-Hans"), "打开 %@ 控制台")
        XCTAssertEqual(_localized("Follow these steps to create your %@.", language: "zh-Hans"),
                       "按以下步骤创建你的 %@。")
    }

    /// Every key the UI resolves must have a zh-Hans translation that differs
    /// from the English source (i.e. it isn't falling back).
    func testNoMissingChineseTranslations() {
        let keys = [
            "Active", "Add", "Set as Active", "Delete", "No Providers Yet", "Add Provider",
            "Display name", "Endpoint", "Model", "Enabled", "Cancel", "Done",
            "Cloud", "Local", "Cloud provider", "Compatible / Aggregators",
            "OpenAI-compatible endpoint", "Local — runs on your machine",
            "Search providers", "Choose a Provider", "Refresh model list",
            "Fetching models…", "Enter model ID manually", "Model ID",
            "Hide key", "Show key", "Paste", "Key looks valid",
            "Sign Up", "Docs", "Pricing", "Don't have a key? Get one",
            "No API key required", "Custom endpoint", "Default model",
            "Tap to edit. The active provider is used by the app.",
            "Add an AI provider and your own API key to get started.",
            "This provider is no longer available.", "Unavailable",
            "Enter the base URL of an OpenAI-compatible endpoint.",
            "Connected.", "Failed.", "Test Connection",
        ]
        for key in keys {
            let zh = _localized(key, language: "zh-Hans")
            XCTAssertNotEqual(zh, key, "Key '\(key)' has no zh-Hans translation")
            XCTAssertFalse(zh.isEmpty, "Key '\(key)' resolved empty")
        }
    }

    // MARK: - Core (validation messages)

    func testCoreValidationMessagesAreLocalized() {
        XCTAssertEqual(_byokCoreLocalized("The key is empty.", language: "zh-Hans"), "Key 为空。")
        XCTAssertEqual(_byokCoreLocalized("The key looks too short.", language: "zh-Hans"), "Key 看起来太短了。")
        XCTAssertEqual(_byokCoreLocalized("The key format doesn't look right.", language: "zh-Hans"), "Key 格式看起来不对。")
        XCTAssertEqual(_byokCoreLocalized("The key is empty.", language: "en"), "The key is empty.")
    }

    /// `reasonInvalid` produces a translated message end-to-end (host locale is en).
    func testCredentialReasonInvalidUsesCatalog() {
        let v = KeyValidation(prefix: "sk-")
        XCTAssertEqual(v.reasonInvalid(for: "xx-bad"), "Expected the key to start with \"sk-\".")
        XCTAssertNil(v.reasonInvalid(for: "sk-good"))
    }

    // MARK: - Client (error & connection messages)

    func testClientMessagesAreLocalized() {
        XCTAssertEqual(_byokClientLocalized("No model selected.", language: "zh-Hans"), "未选择模型。")
        XCTAssertEqual(_byokClientLocalized("Connected. Found %lld models.", language: "zh-Hans"), "连接成功,发现 %lld 个模型。")
        XCTAssertEqual(_byokClientLocalized("An API key is required.", language: "zh-Hans"), "需要 API Key。")
    }

    func testClientErrorDescriptionUsesCatalog() {
        XCTAssertEqual(LLMClientError.missingModel.errorDescription, "No model selected.")
        XCTAssertEqual(LLMClientError.missingAPIKey.errorDescription, "An API key is required.")
    }
}
