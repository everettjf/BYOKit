# AnyLLM

A Swift Package that gives any iOS / iPadOS / macOS app a **production-grade BYOK
(Bring Your Own Key) configuration experience** in one line.

Most apps that support multiple LLM providers re-build the same thing by hand:
a provider list, an API-key field, "where do I get a key?" guidance, Keychain
storage, and a connection test. AnyLLM ships all of it as polished, themeable
SwiftUI components — and keeps the actual model calls behind a swappable
protocol.

```swift
import AnyLLM

AnyLLMSettingsView()
    .environmentObject(store)            // a ConfigurationStore
    .anyLLMClient(DefaultLLMClient())    // or your own LLMClient
```

<p align="center">
  <img src="Example/screenshots/ios-2-list.png" width="220">
  <img src="Example/screenshots/ios-4-form.png" width="220">
  <img src="Example/screenshots/ios-5-onboarding.png" width="220">
</p>

## Why

The differentiator isn't *calling* models — there are many good libraries for
that ([AnyLanguageModel](https://github.com/mattt/AnyLanguageModel),
[SwiftOpenAI](https://github.com/jamesrochabrun/SwiftOpenAI), …). It's the
**configuration UX**: per-provider onboarding with deep links, key validation,
one-tap connection testing, custom base URLs, and multi-key management. AnyLLM
focuses there.

## Features

- **One-line settings center** — list, add, edit, reorder, delete, choose the active provider.
- **Per-provider onboarding** — structured "get a key" guide with steps, notes, and deep links (console / sign-up / docs / pricing).
- **Secure by default** — keys go to the Keychain; UI masks them; "Test Connection" uses a minimal request.
- **Data-driven catalog** — add a provider by editing `providers.json`; no UI code. Ships built-in, optionally overridden by a remote OTA JSON.
- **Swappable engine** — `DefaultLLMClient` (URLSession, zero deps) speaks OpenAI, Anthropic, Gemini, and Ollama. Conform to `LLMClient` to use anything else.
- **Adaptive** — looks right on iOS, iPadOS, and macOS. Themeable to match the host app.

## Built-in providers

OpenAI · Anthropic · Google Gemini · DeepSeek · OpenRouter · Groq · Mistral ·
xAI (Grok) · Ollama (local) · Custom (any OpenAI-compatible endpoint).

## Install

```swift
.package(url: "https://github.com/everettjf/AnyLLM", from: "1.0.0")
```

Add the `AnyLLM` product (umbrella). For just the data layer, depend on
`AnyLLMCore`; for just the UI, `AnyLLMUI`.

Platforms: **iOS 17 / iPadOS 17 / macOS 14**, Swift 6.1 toolchain.

## Architecture

| Target | Role | Dependencies |
|---|---|---|
| `AnyLLMCore` | Models, provider registry, onboarding metadata, `providers.json` | none |
| `AnyLLMStore` | Keychain credential store + configuration persistence | Core |
| `AnyLLMClient` | `LLMClient` protocol + `DefaultLLMClient` (URLSession) | Core |
| `AnyLLMUI` | SwiftUI components | Core, Store, Client |
| `AnyLLM` | Umbrella re-export | all |

`AnyLLMCore` has **zero third-party dependencies**. Nothing pulls in a heavy SDK
unless you choose to write an adapter.

## Usage

```swift
@main
struct MyApp: App {
    @StateObject private var store = ConfigurationStore()   // Keychain + UserDefaults

    var body: some Scene {
        WindowGroup {
            AnyLLMSettingsView()
                .environmentObject(store)
                .anyLLMClient(DefaultLLMClient())
        }
    }
}
```

Send a request with the active configuration:

```swift
if let config = store.activeConfiguration,
   let provider = await ProviderRegistry.shared.provider(config.providerID) {
    let resolved = ResolvedConfiguration(
        provider: provider,
        configuration: config,
        apiKey: store.apiKey(for: config.id)
    )
    let response = try await DefaultLLMClient()
        .complete(.text("Hello"), with: resolved)
    print(response.text)
}
```

### Customization

```swift
AnyLLMSettingsView()
    .anyLLMProviders(.only(.openAI, .anthropic, .ollama))  // limit providers
    .anyLLMTheme(AnyLLMTheme(accent: .pink, cornerRadius: 16))
    .anyLLMShowsOnboarding(true)
    .anyLLMClient(myCustomClient)
```

### Reusable pieces

`ProviderPickerView`, `ProviderConfigForm`, `OnboardingGuideView`,
`ConnectionTestButton`, `KeyField`, and `ProviderBadge` are all public and usable
on their own.

## Example app

`Example/` contains a multi-platform SwiftUI app.

```bash
cd Example
xcodegen generate           # needs `brew install xcodegen`
open AnyLLMDemo.xcodeproj
```

## Testing

```bash
swift test
```

32 tests cover the registry, key validation, Keychain round-trips, the store, and
all four API formats (via a stubbed `URLProtocol`). Set `ROCKY_OPENAI_APIKEY` to
also run two live OpenAI smoke tests (skipped otherwise). The package is build-
verified on macOS and the iOS/iPadOS simulator SDKs.

## License

MIT © Everett
