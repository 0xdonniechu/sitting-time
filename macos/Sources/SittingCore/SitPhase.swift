import Foundation

/// The three mutually exclusive states of the user.
public enum SitPhase: String, Codable, Sendable, CaseIterable {
    /// User is sitting (working at the desk).
    case sitting
    /// User is standing (standing desk / walking around).
    case standing
    /// Tracking is paused: manual break or auto-pause (idle / Mac asleep).
    case paused

    /// Short label used in the menu bar and buttons.
    public var shortTitle: String {
        switch self {
        case .sitting: return "Ngồi"
        case .standing: return "Đứng"
        case .paused: return "Nghỉ"
        }
    }

    /// Full label used in headings.
    public var title: String {
        switch self {
        case .sitting: return "Đang ngồi"
        case .standing: return "Đang đứng"
        case .paused: return "Tạm nghỉ"
        }
    }

    /// SF Symbol shown in the menu bar and UI. All three exist since SF Symbols 4.
    public var symbol: String {
        switch self {
        case .sitting: return "chair"
        case .standing: return "figure.stand"
        case .paused: return "pause.circle"
        }
    }
}
