import Foundation

/// Filter for querying the registry.
public struct ProviderFilter: Sendable {
    public var kinds: Set<ProviderKind>?
    public var ids: Set<ProviderID>?

    public init(kinds: Set<ProviderKind>? = nil, ids: Set<ProviderID>? = nil) {
        self.kinds = kinds
        self.ids = ids
    }

    public static let all = ProviderFilter()
    public static func only(_ ids: ProviderID...) -> ProviderFilter { .init(ids: Set(ids)) }
    public static func kinds(_ kinds: ProviderKind...) -> ProviderFilter { .init(kinds: Set(kinds)) }

    func matches(_ provider: Provider) -> Bool {
        if let kinds, !kinds.contains(provider.kind) { return false }
        if let ids, !ids.contains(provider.id) { return false }
        return true
    }
}

/// On-disk shape of `providers.json` (and any remote OTA override).
struct ProviderBundle: Codable {
    var version: Int
    var providers: [Provider]
}

public enum ProviderRegistryError: Error, Sendable {
    case builtinResourceMissing
    case remoteOlderThanBuiltin(remote: Int, builtin: Int)
}

/// Loads and serves provider definitions. Ships a built-in `providers.json`,
/// and can be overridden at runtime by a remote JSON (OTA) of a newer version.
public actor ProviderRegistry {
    private var bundle: ProviderBundle
    private var ordering: [ProviderID]

    public static let shared = ProviderRegistry()

    /// Loads the built-in bundle. Traps only if the package resource is corrupt,
    /// which is a build-time error, never a runtime one.
    public init() {
        let loaded = Self.loadBuiltin()
        self.bundle = loaded
        self.ordering = loaded.providers.map(\.id)
    }

    /// For tests / custom hosting: start from an explicit bundle.
    public init(providers: [Provider], version: Int = 1) {
        self.bundle = ProviderBundle(version: version, providers: providers)
        self.ordering = providers.map(\.id)
    }

    public var version: Int { bundle.version }

    /// All providers in their curated display order.
    public func all() -> [Provider] { bundle.providers }

    public func providers(_ filter: ProviderFilter) -> [Provider] {
        bundle.providers.filter(filter.matches)
    }

    public func provider(_ id: ProviderID) -> Provider? {
        bundle.providers.first { $0.id == id }
    }

    /// OTA: replace the catalog from a remote JSON, but only if it's newer.
    /// On any failure the existing (built-in) catalog is kept.
    @discardableResult
    public func loadRemote(from url: URL, session: URLSession = .shared) async throws -> Int {
        let (data, _) = try await session.data(from: url)
        return try apply(data: data)
    }

    /// Apply raw JSON, enforcing the monotonic-version rule. Returns the new version.
    @discardableResult
    public func apply(data: Data) throws -> Int {
        let decoder = JSONDecoder()
        let remote = try decoder.decode(ProviderBundle.self, from: data)
        guard remote.version >= bundle.version else {
            throw ProviderRegistryError.remoteOlderThanBuiltin(remote: remote.version, builtin: bundle.version)
        }
        bundle = remote
        ordering = remote.providers.map(\.id)
        return remote.version
    }

    // MARK: - Built-in loading

    static func loadBuiltin() -> ProviderBundle {
        guard let url = Bundle.module.url(forResource: "providers", withExtension: "json") else {
            // Resource is compiled into the package; absence is a packaging bug.
            return ProviderBundle(version: 0, providers: [])
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(ProviderBundle.self, from: data)
        } catch {
            assertionFailure("AnyLLM: failed to decode built-in providers.json: \(error)")
            return ProviderBundle(version: 0, providers: [])
        }
    }
}
