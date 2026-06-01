# BYOKit — Package 设计方案

> **状态（2026-06-01）：M1–M3 已实现，M4 进行中。** 全部 target 落地，10 个内置厂商
> + 本地模型（MLX / llama.cpp / Apple Foundation Models），**流式输出**（SSE / NDJSON，
> 覆盖 OpenAI / Anthropic / Gemini / Ollama，并经 AnyLanguageModel 适配器原生流式），
> **国际化（en + zh-Hans）** 覆盖 UI 文案 + Core 校验提示 + Client 错误/连接消息。
> 52 个测试全绿（含 2 个对真实 OpenAI API 的 live smoke test），已在 iOS / iPadOS 模拟器与
> macOS 上验证运行。Example/ 含可运行的多平台 Demo。详见 [README](README.md)。

---


> 一个专注于 **BYOK（Bring Your Own Key）配置最佳体验** 的 Swift Package。
> 让任何 iOS / macOS App 用几行代码就拥有一套生产级的「大模型厂商配置 + API Key 引导 + 连接测试」界面。

---

## 1. 定位（Positioning）

| | 说明 |
|---|---|
| **解决什么** | 每个支持 BYOK 的 App 都要重写一遍 provider 配置页、Key 输入、引导文案、Keychain 存储、连接测试。BYOKit 把这层封装成可复用组件。 |
| **核心差异化** | 不在「调模型」，而在 **配置 UX**：每个厂商的申请 Key 引导、deep link、Key 校验、一键测活、自定义 baseURL、多 Key 管理。 |
| **不做什么** | 不重新实现一套 LLM SDK。底层调用依赖成熟项目（默认 [AnyLanguageModel](https://github.com/mattt/AnyLanguageModel)），并保持可插拔。 |

### Goals
- 拖进来即用：`BYOKSettingsView()` 一行出一个完整配置页。
- **数据驱动**：新增一个厂商 = 加一份元数据，不改 UI 代码。
- 不绑死底层 SDK：API 调用走 protocol，默认适配 AnyLanguageModel，可换 SwiftOpenAI / 自定义。
- 安全默认：Key 进 Keychain，UI 脱敏显示。
- 端侧 + 云端统一：同一套配置界面覆盖 BYOK 云端 与 本地模型（MLX / Foundation Models）。

### Non-Goals
- 不做 chat UI、不做 prompt 管理、不做对话历史。
- 不做云端代理 / 计费（那是 BackendKit 之类的反面，BYOK 的意义就是不代理）。

---

## 2. 模块拆分（Targets）

分层，让接 UI 的人和只想要数据模型的人都能按需引入。

```
BYOKit (package)
├── BYOKitCore        // 纯 Swift：数据模型 + 内置 provider 注册表 + onboarding 元数据。零依赖、零 UI。
├── BYOKitStore       // Keychain 凭证存储 + 配置持久化。依赖 BYOKitCore。
├── BYOKitClient      // LLM 调用抽象协议 + 「测试连接」。依赖 BYOKitCore。
│   └── BYOKitClientAnyLanguageModel  // 默认适配器（独立 target，可不引入）
├── BYOKitUI          // SwiftUI 组件。依赖 Core / Store / Client。
└── BYOKit            // 伞 target：re-export 全部，提供一行式 API。
```

依赖原则：**Core 不依赖任何第三方包**。只有引入 `BYOKitClientAnyLanguageModel` 时才会拉进 AnyLanguageModel。想用别的 SDK 的人完全不碰它。

`Package.swift` 骨架：

```swift
// swift-tools-version: 6.1   ← 对齐 AnyLanguageModel
let package = Package(
    name: "BYOKit",
    platforms: [.iOS(.v17), .macOS(.v14)],   // 与 AnyLanguageModel 一致
    products: [
        .library(name: "BYOKit", targets: ["BYOKit"]),
        .library(name: "BYOKitCore", targets: ["BYOKitCore"]),
        .library(name: "BYOKitUI", targets: ["BYOKitUI"]),
        .library(name: "BYOKitClientAnyLanguageModel", targets: ["BYOKitClientAnyLanguageModel"]),
    ],
    dependencies: [
        .package(url: "https://github.com/mattt/AnyLanguageModel", from: "0.x.0"),
    ],
    targets: [
        .target(name: "BYOKitCore"),
        .target(name: "BYOKitStore", dependencies: ["BYOKitCore"]),
        .target(name: "BYOKitClient", dependencies: ["BYOKitCore"]),
        .target(name: "BYOKitClientAnyLanguageModel",
                dependencies: ["BYOKitClient",
                               .product(name: "AnyLanguageModel", package: "AnyLanguageModel")]),
        .target(name: "BYOKitUI", dependencies: ["BYOKitCore", "BYOKitStore", "BYOKitClient"]),
        .target(name: "BYOKit",
                dependencies: ["BYOKitCore", "BYOKitStore", "BYOKitClient", "BYOKitUI"]),
        .testTarget(name: "BYOKitTests", dependencies: ["BYOKit"]),
    ]
)
```

---

## 3. 数据模型（BYOKitCore）

### 3.1 Provider — 厂商定义（数据驱动的核心）

```swift
public struct Provider: Identifiable, Hashable, Sendable, Codable {
    public let id: ProviderID            // "openai", "anthropic", "gemini", "openrouter", "ollama", ...
    public let displayName: String       // "OpenAI"
    public let kind: ProviderKind        // .cloud / .local / .compatible
    public let apiFormat: APIFormat      // .openAI / .anthropic / .gemini / .ollama
    public let iconAsset: ImageRef       // 内置 logo（SF Symbol 兜底）
    public let defaultBaseURL: URL?
    public let allowsCustomBaseURL: Bool // OpenRouter/自托管/兼容端点 → true
    public let credential: CredentialSpec
    public let onboarding: Onboarding    // ★ 差异化重点，见 3.3
    public let models: ModelCatalog      // 预置模型列表 + 是否支持动态拉取
}

public struct ProviderID: RawRepresentable, Hashable, Sendable, Codable {
    public let rawValue: String
}

public enum ProviderKind: Sendable, Codable { case cloud, local, compatible }
public enum APIFormat: Sendable, Codable { case openAI, anthropic, gemini, ollama, custom }
```

### 3.2 凭证规格 — 不同厂商要的东西不一样

```swift
public struct CredentialSpec: Sendable, Codable {
    public let requiresAPIKey: Bool           // Ollama 本地 → false
    public let keyDisplayName: String         // "API Key" / "Token"
    public let validation: KeyValidation?     // 前缀/正则/长度，本地即时校验
    public let extraFields: [CredentialField] // 如 Azure 的 deployment / resource name
}

public struct KeyValidation: Sendable, Codable {
    public let prefix: String?      // "sk-", "sk-ant-"
    public let regex: String?
    public let minLength: Int?
}

public struct CredentialField: Identifiable, Sendable, Codable {
    public let id: String           // "azure_resource"
    public let label: String
    public let isSecret: Bool
    public let placeholder: String?
}
```

### 3.3 Onboarding — 「去哪拿 Key」引导（护城河）

这是所有现成项目都没做、却最费体验的部分。做成结构化数据：

```swift
public struct Onboarding: Sendable, Codable {
    public let consoleURL: URL?          // 直达申请页：platform.openai.com/api-keys 等
    public let signUpURL: URL?           // 还没账号
    public let steps: [OnboardingStep]   // 图文分步引导
    public let pricingURL: URL?
    public let docsURL: URL?
    public let notes: [LocalizedNote]    // "需绑卡" / "新账号有免费额度" / "国内需代理" 等提示
}

public struct OnboardingStep: Identifiable, Sendable, Codable {
    public let id: Int
    public let text: LocalizedString     // "登录后点右上角头像 → API Keys"
    public let imageRef: ImageRef?       // 可选截图
    public let actionURL: URL?           // 该步可点的 deep link
}
```

内置注册表为每个主流厂商预填好 `Onboarding`（OpenAI / Anthropic / Gemini / OpenRouter / DeepSeek / xAI / Mistral / Groq / Ollama / Azure …）。这部分元数据建议放在 `Resources/providers.json`，方便不发版也能 OTA 更新。

### 3.4 模型目录

```swift
public struct ModelCatalog: Sendable, Codable {
    public let presets: [ModelInfo]          // 预置常用模型
    public let supportsDynamicListing: Bool  // 能否调 /models 动态拉取
}

public struct ModelInfo: Identifiable, Hashable, Sendable, Codable {
    public let id: String                    // "gpt-4o", "claude-sonnet-4-6"
    public let displayName: String
    public let contextWindow: Int?
    public let capabilities: Set<ModelCapability>  // .vision, .tools, .reasoning
}
```

### 3.5 用户的配置实例（运行时产物）

```swift
public struct LLMConfiguration: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public var providerID: ProviderID
    public var displayName: String          // 用户可改别名，支持同厂商多 Key
    public var baseURL: URL?                 // 覆盖默认
    public var selectedModelID: String?
    public var extraValues: [String: String]// 非密字段（如 Azure deployment）
    public var isEnabled: Bool
    // 注意：API Key 不在这里，单独进 Keychain，用 id 关联
}
```

---

## 4. 存储（BYOKitStore）

```swift
public protocol CredentialStore: Sendable {
    func saveSecret(_ value: String, for configID: UUID, field: String) throws
    func secret(for configID: UUID, field: String) throws -> String?
    func deleteSecrets(for configID: UUID) throws
}

public struct KeychainCredentialStore: CredentialStore { /* kSecClassGenericPassword */ }

@MainActor
public final class ConfigurationStore: ObservableObject {
    @Published public private(set) var configurations: [LLMConfiguration]
    public func add(_ config: LLMConfiguration, secret: String?) throws
    public func update(_ config: LLMConfiguration) throws
    public func remove(_ id: UUID) throws
    public var activeConfiguration: LLMConfiguration? { get set }  // 当前选用
}
```

- 密文 → Keychain（可选 `kSecAttrAccessibleAfterFirstUnlock`，支持 access group 共享给 extension）。
- 配置元数据 → `UserDefaults` / 文件（JSON），App 可注入自定义后端（如 iCloud KVS）。

---

## 5. 调用抽象 + 连接测试（BYOKitClient）

让 UI 不依赖任何具体 SDK。「测试连接」按钮调的就是它。

```swift
public protocol LLMClient: Sendable {
    func validate(_ resolved: ResolvedConfiguration) async throws -> ValidationResult
    func listModels(_ resolved: ResolvedConfiguration) async throws -> [ModelInfo]   // 可选动态拉取
    func complete(_ request: CompletionRequest, _ resolved: ResolvedConfiguration)
        async throws -> CompletionResponse                                            // 给真要发请求的 App 用
}

public struct ResolvedConfiguration: Sendable {  // config + 从 Keychain 取出的 secret 合体
    public let provider: Provider
    public let configuration: LLMConfiguration
    public let secret: String?
}

public struct ValidationResult: Sendable {
    public let ok: Bool
    public let latency: Duration?
    public let detectedModels: [ModelInfo]?
    public let message: String?           // "Key 有效，检测到 42 个模型"
}
```

默认适配器（独立 target）：

```swift
// BYOKitClientAnyLanguageModel
public struct AnyLanguageModelClient: LLMClient { /* 把 ResolvedConfiguration 映射到 AnyLanguageModel 的 provider */ }
```

> 想用 SwiftOpenAI / MacPaw-OpenAI / 自家网关的，只要实现 `LLMClient` 协议，UI 完全不用动。

---

## 6. UI 组件（BYOKitUI）

全部 SwiftUI，组件分层，既能整页拖入，也能拆开复用。

### 6.1 一行式入口

```swift
import BYOKit

struct SettingsScreen: View {
    var body: some View {
        BYOKSettingsView()                 // 完整配置中心：已配列表 + 添加 + 编辑
            .byokClient(AnyLanguageModelClient())   // 注入调用层
            .byokProviders(.builtin)                // 或自定义子集
    }
}
```

### 6.2 组件清单

| 组件 | 作用 |
|---|---|
| `BYOKSettingsView` | 配置中心：已添加的 configuration 列表、启用开关、+ 添加 |
| `ProviderPickerView` | 选厂商（按 cloud/local 分组，带 logo、搜索） |
| `ProviderConfigForm` | 单厂商表单：Key 输入（SecureField + 显隐 + 粘贴）、baseURL、模型 picker、额外字段 |
| `OnboardingGuideView` | ★ 「去哪拿 Key」：分步图文 + 「打开控制台」按钮（`consoleURL` deep link） |
| `ConnectionTestButton` | 一键测活：loading → ✅ 延迟/模型数 / ❌ 错误原因 |
| `ModelPickerView` | 预置模型 + 动态拉取合并展示，按能力标签过滤 |
| `KeyField` | 可单独复用的脱敏密钥输入框（显隐、校验态、粘贴板检测） |

### 6.3 交互流（添加一个厂商）

```
[+ 添加]
  → ProviderPickerView   选 OpenAI
  → ProviderConfigForm
       ├─ 顶部一句话 + 「还没有 Key？查看获取指南」→ OnboardingGuideView（sheet）
       │      └─ 分步引导 + [打开 platform.openai.com] 按钮
       ├─ KeyField（实时前缀校验 sk-，脱敏，粘贴自动 trim）
       ├─ baseURL（默认折叠，allowsCustomBaseURL 才显示）
       ├─ ModelPickerView
       └─ [测试连接] ConnectionTestButton → ✅ 后 [保存]
  → 存 Keychain + ConfigurationStore，回到列表
```

### 6.4 可定制

```swift
BYOKSettingsView()
    .byokProviders([.openAI, .anthropic, .ollama])     // 限定厂商
    .byokTheme(.init(accent: .brand, cornerRadius: 12)) // 跟随宿主 App 风格
    .byokShowsOnboarding(true)
```

全部走 `Environment` 注入，宿主可覆盖文案、主题、provider 子集、client。支持 Dynamic Type / Dark Mode / 多语言（首批 zh-Hans + en）。

---

## 7. 内置厂商首批清单

OpenAI · Anthropic · Google Gemini · DeepSeek · xAI (Grok) · Mistral · Groq · OpenRouter（兼容聚合）· Ollama（本地）· Azure OpenAI · Apple Foundation Models（端侧，无需 Key）。

每个都预填：logo、apiFormat、defaultBaseURL、Key 校验规则、onboarding（consoleURL + 分步 + notes）、常用模型 presets。

---

## 8. 安全

- Key 只进 Keychain，绝不落 UserDefaults / 日志 / 配置 JSON。
- UI 默认脱敏（`sk-…AB12`），点击才显。
- 「测试连接」用最小请求（优先 `/models`，无则 1-token 补全），不泄漏到分析。
- 支持 Keychain access group，给 Widget / Share Extension 共享。

---

## 9. 示例集成（宿主 App 真正写的代码）

```swift
@main
struct MyApp: App {
    @StateObject private var store = ConfigurationStore(client: AnyLanguageModelClient())
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store)
        }
    }
}

// 设置页
BYOKSettingsView().environmentObject(store)

// 业务里取当前配置发请求
if let active = store.resolvedActive() {
    let resp = try await store.client.complete(.text("Hello"), active)
}
```

---

## 10. 路线图（分阶段）

| 阶段 | 内容 |
|---|---|
| **M1 Core** | 数据模型 + providers.json + Keychain 存储 + `LLMClient` 协议（先实现 `validate`/`listModels`）。无 UI 也能用。 |
| **M2 UI** | ProviderPicker / ConfigForm / KeyField / ConnectionTest / OnboardingGuide + `BYOKSettingsView`。 |
| **M3 Adapter** | AnyLanguageModel 适配器 + 动态模型拉取 + 示例 App。✅ |
| **M4 打磨** | i18n（en + zh-Hans）✅、流式输出 ✅、主题 ✅、a11y（进行中）、provider OTA 更新 ✅、单测 ✅。剩余：更广的 a11y 覆盖与快照测试。 |

---

## 11. 已确定的决策

1. **底层默认依赖**：✅ AnyLanguageModel（覆盖最广、含端侧 MLX / Foundation Models）。`LLMClient` 协议层保证可换 SwiftOpenAI / 自定义。
2. **最低系统版本**：✅ iOS 17 / macOS 14，Swift tools 6.1——对齐 AnyLanguageModel。端侧高版本特性按 provider 用 `@available` 降级。
3. **providers 元数据**：✅ 内置兜底 JSON（编译进包）+ 可选远端 OTA 覆盖。`ProviderRegistry` 启动加载内置，异步用远端 JSON 覆盖（版本号比对，失败回退内置）。

```swift
public actor ProviderRegistry {
    public static let builtin: ProviderRegistry           // 包内 Resources/providers.json
    public func loadRemote(_ url: URL) async              // OTA：拉取 → 校验 → 覆盖；失败保持内置
    public func providers(_ filter: ProviderFilter) -> [Provider]
}
```
```

