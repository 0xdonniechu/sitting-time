import Foundation

/// User-tunable behaviour. Persisted as JSON; unknown keys from older versions are ignored.
public struct AppSettings: Codable, Sendable, Equatable {
    /// Remind to stand up after this many continuous sitting minutes. 0 disables reminders.
    public var sitReminderMinutes: Int
    /// Auto-pause tracking after this many minutes without keyboard/mouse input.
    public var idlePauseMinutes: Int
    /// Daily standing goal in minutes. 0 disables the goal.
    public var standGoalMinutes: Int
    /// Resume the previous phase automatically when input returns after an auto-pause.
    public var autoResumeOnReturn: Bool
    /// Start the app in the paused phase.
    public var startPaused: Bool
    /// Play a sound with reminders.
    public var reminderSound: Bool
    /// Launch at login (applied through SMAppService).
    public var launchAtLogin: Bool
    /// UI + notification language.
    public var language: AppLanguage
    /// Secondary calendar shown in the popover tile.
    public var subCalendar: SubCalendar
    /// Show the full-screen flash on sit reminders (with the banner kept silent).
    public var fullScreenFlash: Bool
    /// Show a random health quote on the flash (20 s instead of 6 s).
    public var quoteOnFlash: Bool

    public init(
        sitReminderMinutes: Int = 45,
        idlePauseMinutes: Int = 5,
        standGoalMinutes: Int = 60,
        autoResumeOnReturn: Bool = true,
        startPaused: Bool = false,
        reminderSound: Bool = true,
        launchAtLogin: Bool = false,
        language: AppLanguage = .vietnamese,
        subCalendar: SubCalendar = .vietnamese,
        fullScreenFlash: Bool = true,
        quoteOnFlash: Bool = true
    ) {
        self.sitReminderMinutes = sitReminderMinutes
        self.idlePauseMinutes = idlePauseMinutes
        self.standGoalMinutes = standGoalMinutes
        self.autoResumeOnReturn = autoResumeOnReturn
        self.startPaused = startPaused
        self.reminderSound = reminderSound
        self.launchAtLogin = launchAtLogin
        self.language = language
        self.subCalendar = subCalendar
        self.fullScreenFlash = fullScreenFlash
        self.quoteOnFlash = quoteOnFlash
    }

    enum CodingKeys: String, CodingKey {
        case sitReminderMinutes, idlePauseMinutes, standGoalMinutes
        case autoResumeOnReturn, startPaused, reminderSound, launchAtLogin
        case language, subCalendar, fullScreenFlash, quoteOnFlash
    }

    /// Every field falls back to its default: a settings.json saved before a
    /// field existed (e.g. `language`) still loads instead of failing the decode.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sitReminderMinutes = try c.decodeIfPresent(Int.self, forKey: .sitReminderMinutes) ?? 45
        idlePauseMinutes = try c.decodeIfPresent(Int.self, forKey: .idlePauseMinutes) ?? 5
        standGoalMinutes = try c.decodeIfPresent(Int.self, forKey: .standGoalMinutes) ?? 60
        autoResumeOnReturn = try c.decodeIfPresent(Bool.self, forKey: .autoResumeOnReturn) ?? true
        startPaused = try c.decodeIfPresent(Bool.self, forKey: .startPaused) ?? false
        reminderSound = try c.decodeIfPresent(Bool.self, forKey: .reminderSound) ?? true
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        language = try c.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .vietnamese
        subCalendar = try c.decodeIfPresent(SubCalendar.self, forKey: .subCalendar) ?? .vietnamese
        fullScreenFlash = try c.decodeIfPresent(Bool.self, forKey: .fullScreenFlash) ?? true
        quoteOnFlash = try c.decodeIfPresent(Bool.self, forKey: .quoteOnFlash) ?? true
    }

    /// Clamps every numeric field to its sane range. Called after loading and after edits.
    public mutating func clamp() {
        sitReminderMinutes = min(max(sitReminderMinutes, 0), 240)
        idlePauseMinutes = min(max(idlePauseMinutes, 1), 60)
        standGoalMinutes = min(max(standGoalMinutes, 0), 600)
    }

    public var clamped: AppSettings {
        var copy = self
        copy.clamp()
        return copy
    }
}
