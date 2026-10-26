import Foundation

/// Every user-visible string in one table. English ships in the binary as the
/// default; Vietnamese resolves through the downloadable pack (see
/// `LanguagePacks`), falling back to English per string. Views and
/// notifications read `Strings(store.settings.language)`; nothing is
/// hardcoded in Vietnamese anywhere else.
public struct Strings: Sendable {
    /// Effective language: `.vietnamese` only when its pack is installed,
    /// otherwise `.english`.
    public let language: AppLanguage

    public init(_ language: AppLanguage) {
        self.language = LanguagePacks.resolve(language)
    }

    private func t(_ key: String, _ en: String, _ args: [String: String] = [:]) -> String {
        var template = en
        if language == .vietnamese, let value = LanguagePacks.installed()?.strings[key] {
            template = value
        }
        return LanguagePacks.format(template, args)
    }

    /// Count-based form: English picks `.one` for exactly 1, Vietnamese
    /// always uses `.other` (no plural distinction). `{count}` is always filled.
    private func tp(_ base: String, count: Int, oneEn: String, otherEn: String, _ args: [String: String] = [:]) -> String {
        var args = args
        args["count"] = "\(count)"
        if language == .english, count == 1 {
            return t("\(base).one", oneEn, args)
        }
        return t("\(base).other", otherEn, args)
    }

    // MARK: - Phases

    public func phaseShort(_ phase: SitPhase) -> String {
        switch phase {
        case .sitting: return t("phaseShort.sitting", "Sit")
        case .standing: return t("phaseShort.standing", "Stand")
        case .paused: return t("phaseShort.paused", "Break")
        }
    }

    public func phaseTitle(_ phase: SitPhase) -> String {
        switch phase {
        case .sitting: return t("phaseTitle.sitting", "Sitting")
        case .standing: return t("phaseTitle.standing", "Standing")
        case .paused: return t("phaseTitle.paused", "Paused")
        }
    }

    // MARK: - Popover

    public var autoPausedNote: String {
        t("autoPausedNote", "Auto-paused while you were away — resumes when you return.")
    }

    public var statusPickerLabel: String { t("statusPickerLabel", "Status") }
    public var pauseButton: String { t("pauseButton", "Pause") }
    public var resumeButton: String { t("resumeButton", "Resume") }
    public var todaySection: String { t("todaySection", "Today") }
    public var todayLabel: String { t("todayLabel", "Today") }

    public func goalProgress(_ goal: String) -> String {
        t("goalProgress", "Standing goal {goal}", ["goal": goal])
    }

    public func breaksLine(count: Int, longest: String) -> String {
        tp(
            "breaksLine", count: count,
            oneEn: "1 stand-up • Longest sit {longest}",
            otherEn: "{count} stand-ups • Longest sit {longest}",
            ["longest": longest]
        )
    }

    public var statsButton: String { t("statsButton", "Statistics") }
    public var backButton: String { t("backButton", "Dashboard") }
    public var settingsButton: String { t("settingsButton", "Settings") }
    public var quitButton: String { t("quitButton", "Quit") }
    public var skipButton: String { t("skipButton", "Skip") }

    // MARK: - Sessions

    public func sessionTitle(kind: SessionKind, mode: SessionMode, focusIndex: Int) -> String {
        switch (kind, mode) {
        case (.work, .pomodoro):
            t(
                "sessionTitle.focus", "Focus {index}/{total}",
                ["index": "\(focusIndex)", "total": "\(SessionMode.pomodoroCycleLength)"]
            )
        case (.work, .standUp):
            t("sessionTitle.work", "Work")
        case (.shortBreak, .standUp):
            t("sessionTitle.move", "Move")
        case (.shortBreak, .pomodoro):
            t("sessionTitle.shortBreak", "Short break")
        case (.longBreak, _):
            t("sessionTitle.longBreak", "Long break")
        }
    }

    // MARK: - Settings window

    public var settingsPanelTitle: String { t("settingsPanelTitle", "Settings") }

    // MARK: - Stats window

    public var statsPanelTitle: String { t("statsPanelTitle", "7-day statistics") }
    public var weekTitle: String { t("weekTitle", "Last 7 days") }

    public func totalLine(sitting: String, standing: String) -> String {
        t("totalLine", "Sitting {sitting} • Standing {standing}", ["sitting": sitting, "standing": standing])
    }

    public var chartDay: String { t("chartDay", "Day") }
    public var chartHour: String { t("chartHour", "Hours") }
    public var chartSitting: String { t("chartSitting", "Sitting") }
    public var chartStanding: String { t("chartStanding", "Standing") }
    public var yAxisHours: String { t("yAxisHours", "hours") }

    public func daySitting(_ duration: String) -> String {
        t("daySitting", "Sitting {duration}", ["duration": duration])
    }

    public func dayStanding(_ duration: String) -> String {
        t("dayStanding", "Standing {duration}", ["duration": duration])
    }

    // MARK: - Settings

    public var sessionSection: String { t("sessionSection", "Work sessions") }
    public var notifySection: String { t("notifySection", "Session alerts") }
    public var modeLabel: String { t("modeLabel", "Mode") }

    public func workMinutes(_ minutes: Int) -> String {
        t("workMinutes", "Work: {minutes} min", ["minutes": "\(minutes)"])
    }

    public func moveMinutes(_ minutes: Int) -> String {
        t("moveMinutes", "Move: {minutes} min", ["minutes": "\(minutes)"])
    }

    public func shortMinutes(_ minutes: Int) -> String {
        t("shortMinutes", "Short break: {minutes} min", ["minutes": "\(minutes)"])
    }

    public func longMinutes(_ minutes: Int) -> String {
        t("longMinutes", "Long break: {minutes} min", ["minutes": "\(minutes)"])
    }

    public var soundToggle: String { t("soundToggle", "Reminder sound") }
    public var flashToggle: String { t("flashToggle", "Full-screen flash") }
    public var quoteToggle: String { t("quoteToggle", "Show quote on flash") }
    public var dismissHint: String { t("dismissHint", "Click anywhere to dismiss") }
    public var permissionRow: String { t("permissionRow", "Notification permission") }
    public var permissionOn: String { t("permissionOn", "On") }
    public var permissionOff: String { t("permissionOff", "Off") }
    public var requestButton: String { t("requestButton", "Request access") }
    public var openSystemButton: String { t("openSystemButton", "Open System Settings") }

    public var autoSection: String { t("autoSection", "Automatic") }

    public func idleTitle(minutes: Int) -> String {
        tp(
            "idleTitle", count: minutes,
            oneEn: "Auto-pause after 1 minute idle",
            otherEn: "Auto-pause after {minutes} minutes idle",
            ["minutes": "\(minutes)"]
        )
    }

    public var resumeToggle: String { t("resumeToggle", "Auto-resume on return") }
    public var startPausedToggle: String { t("startPausedToggle", "Launch paused") }

    public var goalSection: String { t("goalSection", "Goal") }
    public var goalOff: String { t("goalOff", "No standing goal") }

    public func goalOn(_ duration: String) -> String {
        t("goalOn", "Stand {duration} a day", ["duration": duration])
    }

    public var displaySection: String { t("displaySection", "Language & calendar") }
    public var languageLabel: String { t("languageLabel", "Language") }
    public var calendarLabel: String { t("calendarLabel", "Secondary calendar") }

    // MARK: - Language pack rows

    public var langDownload: String { t("langDownload", "Download") }
    public var langDownloading: String { t("langDownloading", "Downloading…") }

    public func langDownloaded(_ size: String) -> String {
        t("langDownloaded", "Downloaded • {size}", ["size": size])
    }

    public var langNotDownloaded: String { t("langNotDownloaded", "Not downloaded") }

    public func downloadFailed(_ detail: String) -> String {
        t("downloadFailed", "Couldn't download Vietnamese: {detail}", ["detail": detail])
    }

    public var systemSection: String { t("systemSection", "System") }
    public var loginToggle: String { t("loginToggle", "Launch at login") }

    public func loginError(_ detail: String) -> String {
        t("loginError", "Could not set — this only works when running from the .app bundle: {detail}", ["detail": detail])
    }

    public var dataSection: String { t("dataSection", "Data") }
    public var supportSection: String { t("supportSection", "Support") }
    public var revealButton: String { t("revealButton", "Reveal data folder") }
    public var resetTodayButton: String { t("resetTodayButton", "Clear today's data") }
    public var clearAllButton: String { t("clearAllButton", "Erase all history") }

    public func footerNote(version: String) -> String {
        t(
            "footerNote",
            "SittingTime {version} • Data stays on this Mac: no account, no tracking.",
            ["version": version]
        )
    }

    public var resetTodayDialog: String { t("resetTodayDialog", "Clear today's data?") }
    public var deleteButton: String { t("deleteButton", "Delete") }
    public var keepButton: String { t("keepButton", "Keep") }
    public var clearAllDialog: String { t("clearAllDialog", "Erase all history?") }
    public var deleteAllButton: String { t("deleteAllButton", "Erase all") }

    // MARK: - Secondary calendar names

    public func calendarName(_ calendar: SubCalendar) -> String {
        switch calendar {
        case .off: return t("calendarName.off", "Off")
        case .vietnamese: return t("calendarName.vietnamese", "Vietnamese lunar")
        case .chinese: return t("calendarName.chinese", "Chinese")
        case .hebrew: return t("calendarName.hebrew", "Hebrew")
        case .islamic: return t("calendarName.islamic", "Islamic")
        case .buddhist: return t("calendarName.buddhist", "Buddhist")
        }
    }

    // MARK: - Notifications

    public func workEndTitle(duration: String) -> String {
        t("workEndTitle", "Work done after {duration} — stand up and move!", ["duration": duration])
    }

    public var breakOverTitle: String { t("breakOverTitle", "Break over — back to work!") }

    public func reminderBody(sitting: String, standing: String) -> String {
        t("reminderBody", "Today: sitting {sitting} • standing {standing}", ["sitting": sitting, "standing": standing])
    }

    public var goalTitle: String { t("goalTitle", "Daily standing goal reached!") }

    public func goalBody(goal: String) -> String {
        t("goalBody", "You stood {goal}. Well done!", ["goal": goal])
    }
}
