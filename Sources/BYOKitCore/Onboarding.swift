import Foundation

/// "Where do I get a key?" guidance — the part every BYOK app re-writes by hand.
/// Structured so the UI can render a polished, deep-linkable walkthrough.
public struct Onboarding: Hashable, Sendable, Codable {
    /// Direct link to the page where the user creates/copies a key.
    public var consoleURL: URL?
    /// Sign-up page for users without an account yet.
    public var signUpURL: URL?
    /// API documentation.
    public var docsURL: URL?
    /// Pricing page.
    public var pricingURL: URL?
    /// Ordered, human-readable steps.
    public var steps: [OnboardingStep]
    /// Short caveats, e.g. "Requires billing setup", "Free tier available".
    public var notes: [String]

    public init(
        consoleURL: URL? = nil,
        signUpURL: URL? = nil,
        docsURL: URL? = nil,
        pricingURL: URL? = nil,
        steps: [OnboardingStep] = [],
        notes: [String] = []
    ) {
        self.consoleURL = consoleURL
        self.signUpURL = signUpURL
        self.docsURL = docsURL
        self.pricingURL = pricingURL
        self.steps = steps
        self.notes = notes
    }

    /// Whether there is anything worth showing in the guide UI.
    public var hasContent: Bool {
        consoleURL != nil || signUpURL != nil || !steps.isEmpty || !notes.isEmpty
    }
}

public struct OnboardingStep: Identifiable, Hashable, Sendable, Codable {
    public var id: Int
    public var text: String
    /// Optional deep link for this specific step.
    public var actionURL: URL?
    /// Optional SF Symbol shown next to the step.
    public var symbolName: String?

    public init(id: Int, text: String, actionURL: URL? = nil, symbolName: String? = nil) {
        self.id = id
        self.text = text
        self.actionURL = actionURL
        self.symbolName = symbolName
    }
}
