import Foundation

/// UI language. English ships in the binary and is the default; Vietnamese
/// downloads on demand from Settings (see `LanguagePacks`).
public enum AppLanguage: String, Codable, Sendable, CaseIterable {
    case vietnamese = "vi"
    case english = "en"

    /// Language names are shown in their own language, the standard convention.
    public var displayName: String {
        switch self {
        case .vietnamese: return "Tiếng Việt"
        case .english: return "English"
        }
    }
}

/// Secondary calendar shown as a small tile in the popover, next to the phase icon.
/// `.off` hides the tile. The Vietnamese lunar calendar is the Chinese calendar
/// observed in UTC+7, matching the Tauri app's fixed-time-zone conversion.
public enum SubCalendar: String, Codable, Sendable, CaseIterable {
    case off
    case vietnamese
    case chinese
    case hebrew
    case islamic
    case buddhist
}
