import Foundation

/// Session-based timer model (converged with the Tauri app): countdown
/// sessions that auto-advance, instead of open-ended cumulative phases.
/// Sitting/standing attribution still feeds the same daily records.
public enum SessionMode: String, Codable, Sendable, CaseIterable {
    /// Work 45 → move 5, repeating. The default.
    case standUp
    /// Focus 25 → short 5 (×3), long 15 after every 4th focus.
    case pomodoro

    public var displayName: String {
        switch self {
        case .standUp: return "Stand Up"
        case .pomodoro: return "Pomodoro"
        }
    }

    /// Focus sessions before a long break in Pomodoro mode.
    public static let pomodoroCycleLength = 4
}

/// One countdown step. Stand Up cycles work → shortBreak; Pomodoro cycles
/// work → shortBreak (×3), then work → longBreak.
public enum SessionKind: String, Codable, Sendable, Equatable {
    case work
    case shortBreak
    case longBreak

    public var isWork: Bool { self == .work }

    public func title(mode: SessionMode, focusIndex: Int, language: AppLanguage) -> String {
        Strings(language).sessionTitle(kind: self, mode: mode, focusIndex: focusIndex)
    }

    public func duration(mode: SessionMode, settings: AppSettings) -> TimeInterval {
        TimeInterval(settings.minutes(for: self, mode: mode) * 60)
    }
}

/// Sitting or standing while a work session runs. Breaks always count as rest,
/// never as standing: standing here means working upright at the desk.
public enum Posture: String, Codable, Sendable, CaseIterable {
    case sitting
    case standing

    public var symbol: String {
        switch self {
        case .sitting: return "chair"
        case .standing: return "figure.stand"
        }
    }

    public var attribution: SitPhase {
        switch self {
        case .sitting: return .sitting
        case .standing: return .standing
        }
    }
}
