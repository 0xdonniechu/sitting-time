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

    public init(
        sitReminderMinutes: Int = 45,
        idlePauseMinutes: Int = 5,
        standGoalMinutes: Int = 60,
        autoResumeOnReturn: Bool = true,
        startPaused: Bool = false,
        reminderSound: Bool = true,
        launchAtLogin: Bool = false
    ) {
        self.sitReminderMinutes = sitReminderMinutes
        self.idlePauseMinutes = idlePauseMinutes
        self.standGoalMinutes = standGoalMinutes
        self.autoResumeOnReturn = autoResumeOnReturn
        self.startPaused = startPaused
        self.reminderSound = reminderSound
        self.launchAtLogin = launchAtLogin
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
