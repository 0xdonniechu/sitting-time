import Foundation

/// Downloadable Vietnamese strings. English ships in the binary as the
/// default; Vietnamese loads from `lang-vi.json` under Application Support
/// only after the user taps Download in Settings, keeping monolingual
/// installs small. Every lookup falls back to English, so a missing or
/// outdated pack degrades gracefully instead of showing blanks.
public struct LanguagePack: Codable, Sendable {
    public var version: Int
    public var strings: [String: String]

    public init(version: Int = 1, strings: [String: String] = [:]) {
        self.version = version
        self.strings = strings
    }
}

public enum LanguagePackError: LocalizedError {
    case invalidPack
    case badResponse(status: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidPack: return "downloaded file is not a language pack"
        case .badResponse(let status): return "server returned HTTP \(status)"
        }
    }
}

public enum LanguagePacks {
    public static let version = 1

    /// Where the app fetches `vi.json`. Must stay publicly reachable: the
    /// app downloads it without credentials. Update if packs move hosts.
    public static let vietnameseURL = URL(
        string: "https://raw.githubusercontent.com/0xdonniechu/sitting-time/main/macos/Resources/LanguagePacks/vi.json"
    )!

    private final class State: @unchecked Sendable {
        let lock = NSLock()
        var cache: LanguagePack?
        var cacheLoaded = false
        var testOverride: LanguagePack?
        var testOverrideSet = false
    }
    private static let state = State()

    /// The installed pack (the test override wins when set), cached in memory.
    public static func installed() -> LanguagePack? {
        state.lock.withLock {
            if state.testOverrideSet { return state.testOverride }
            if !state.cacheLoaded {
                state.cacheLoaded = true
                if let data = Persistence.loadLanguagePack(),
                   let pack = try? JSONDecoder().decode(LanguagePack.self, from: data),
                   pack.version >= 1, !pack.strings.isEmpty
                {
                    state.cache = pack
                }
            }
            return state.cache
        }
    }

    public static func isInstalled() -> Bool { installed() != nil }

    public static func installedBytes() -> Int? {
        Persistence.languagePackBytes()
    }

    /// Effective language: Vietnamese only when its pack is installed,
    /// English otherwise. The `packInstalled` overload is the pure rule, for tests.
    public static func resolve(_ language: AppLanguage, packInstalled: Bool) -> AppLanguage {
        language == .vietnamese && !packInstalled ? .english : language
    }

    public static func resolve(_ language: AppLanguage) -> AppLanguage {
        resolve(language, packInstalled: isInstalled())
    }

    /// Pack value for `key`, or `english` when the language resolves to
    /// English or the pack lacks the key. The `pack` overload takes the pack
    /// directly, for tests.
    public static func string(_ key: String, english: String, language: AppLanguage, pack: LanguagePack?) -> String {
        guard resolve(language, packInstalled: pack != nil) == .vietnamese else { return english }
        return pack?.strings[key] ?? english
    }

    public static func string(_ key: String, english: String, for language: AppLanguage) -> String {
        string(key, english: english, language: language, pack: installed())
    }

    /// Fills `{name}` placeholders. Unknown placeholders are left as-is so a
    /// stale pack shows its template, never a crash.
    public static func format(_ template: String, _ args: [String: String]) -> String {
        args.reduce(template) { partial, pair in
            partial.replacingOccurrences(of: "{\(pair.key)}", with: pair.value)
        }
    }

    /// Validates and installs downloaded bytes.
    public static func install(_ data: Data) throws {
        let pack = try JSONDecoder().decode(LanguagePack.self, from: data)
        guard pack.version >= 1, !pack.strings.isEmpty else {
            throw LanguagePackError.invalidPack
        }
        try Persistence.saveLanguagePack(data)
        state.lock.withLock {
            state.cache = pack
            state.cacheLoaded = true
        }
    }

    public static func remove() {
        Persistence.deleteLanguagePack()
        state.lock.withLock {
            state.cache = nil
            state.cacheLoaded = true
        }
    }

    /// Downloads the Vietnamese pack, installs it, returns the byte count.
    public static func download() async throws -> Int {
        let (data, response) = try await URLSession.shared.data(from: vietnameseURL)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw LanguagePackError.badResponse(status: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        try install(data)
        return data.count
    }

    /// Test seam: fixes the installed pack (nil = none) without touching
    /// disk. Idempotent for identical content, so parallel tests can all call it.
    public static func setOverrideForTesting(_ pack: LanguagePack?) {
        state.lock.withLock {
            state.testOverride = pack
            state.testOverrideSet = true
        }
    }
}
