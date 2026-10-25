import Foundation

/// User-tunable behaviour. Persisted as JSON; unknown keys from older versions are ignored.
public struct AppSettings: Codable, Sendable, Equatable {
    /// Countdown session model: Stand Up (work/move) or Pomodoro (focus/breaks).
    public var sessionMode: SessionMode
    /// Stand Up work session length in minutes.
    public var standUpWorkMinutes: Int
    /// Stand Up move-break length in minutes.
    public var standUpBreakMinutes: Int
    /// Pomodoro focus session length in minutes.
    public var pomodoroWorkMinutes: Int
    /// Pomodoro short-break length in minutes.
    public var pomodoroShortMinutes: Int
    /// Pomodoro long-break length in minutes (after every 4th focus).
    public var pomodoroLongMinutes: Int
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
        sessionMode: SessionMode = .standUp,
        standUpWorkMinutes: Int = 45,
        standUpBreakMinutes: Int = 5,
        pomodoroWorkMinutes: Int = 25,
        pomodoroShortMinutes: Int = 5,
        pomodoroLongMinutes: Int = 15,
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
        self.sessionMode = sessionMode
        self.standUpWorkMinutes = standUpWorkMinutes
        self.standUpBreakMinutes = standUpBreakMinutes
        self.pomodoroWorkMinutes = pomodoroWorkMinutes
        self.pomodoroShortMinutes = pomodoroShortMinutes
        self.pomodoroLongMinutes = pomodoroLongMinutes
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
        case sessionMode, standUpWorkMinutes, standUpBreakMinutes
        case pomodoroWorkMinutes, pomodoroShortMinutes, pomodoroLongMinutes
        case idlePauseMinutes, standGoalMinutes
        case autoResumeOnReturn, startPaused, reminderSound, launchAtLogin
        case language, subCalendar, fullScreenFlash, quoteOnFlash
    }

    /// Every field falls back to its default: a settings.json saved before a
    /// field existed (or from the pre-session model, e.g. `sitReminderMinutes`)
    /// still loads instead of failing the decode.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sessionMode = try c.decodeIfPresent(SessionMode.self, forKey: .sessionMode) ?? .standUp
        standUpWorkMinutes = try c.decodeIfPresent(Int.self, forKey: .standUpWorkMinutes) ?? 45
        standUpBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .standUpBreakMinutes) ?? 5
        pomodoroWorkMinutes = try c.decodeIfPresent(Int.self, forKey: .pomodoroWorkMinutes) ?? 25
        pomodoroShortMinutes = try c.decodeIfPresent(Int.self, forKey: .pomodoroShortMinutes) ?? 5
        pomodoroLongMinutes = try c.decodeIfPresent(Int.self, forKey: .pomodoroLongMinutes) ?? 15
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

    /// Session length in minutes for one kind under one mode.
    public func minutes(for kind: SessionKind, mode: SessionMode) -> Int {
        switch (mode, kind) {
        case (.standUp, .work): return standUpWorkMinutes
        case (.standUp, _): return standUpBreakMinutes
        case (.pomodoro, .work): return pomodoroWorkMinutes
        case (.pomodoro, .shortBreak): return pomodoroShortMinutes
        case (.pomodoro, .longBreak): return pomodoroLongMinutes
        }
    }

    /// Clamps every numeric field to its sane range. Called after loading and after edits.
    public mutating func clamp() {
        standUpWorkMinutes = min(max(standUpWorkMinutes, 1), 240)
        standUpBreakMinutes = min(max(standUpBreakMinutes, 1), 60)
        pomodoroWorkMinutes = min(max(pomodoroWorkMinutes, 1), 240)
        pomodoroShortMinutes = min(max(pomodoroShortMinutes, 1), 60)
        pomodoroLongMinutes = min(max(pomodoroLongMinutes, 1), 60)
        idlePauseMinutes = min(max(idlePauseMinutes, 1), 60)
        standGoalMinutes = min(max(standGoalMinutes, 0), 600)
    }

    public var clamped: AppSettings {
        var copy = self
        copy.clamp()
        return copy
    }
}
