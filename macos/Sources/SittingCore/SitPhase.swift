import Foundation

/// Attribution buckets for records: where counted seconds land. Sessions and
/// posture decide the bucket (see `Posture`); the store never parks in these.
public enum SitPhase: String, Codable, Sendable, CaseIterable {
    /// Working seated at the desk.
    case sitting
    /// Working upright (standing desk).
    case standing
    /// Rest: session breaks, manual pauses, idle auto-pauses.
    case paused

    /// Short label used in the menu bar and buttons. Delegates to `Strings`,
    /// the single table for user-visible text.
    public func shortTitle(in language: AppLanguage) -> String {
        Strings(language).phaseShort(self)
    }

    /// Full label used in headings.
    public func title(in language: AppLanguage) -> String {
        Strings(language).phaseTitle(self)
    }

    /// SF Symbol shown in compact UI. Sitting returns the laptop half; rich UI
    /// uses the person+laptop composite instead. All three exist since SF Symbols 4.
    public var symbol: String {
        switch self {
        case .sitting: return "laptopcomputer"
        case .standing: return "figure.stand"
        case .paused: return "pause.circle"
        }
    }
}
