import Foundation
import Observation

/// One day of the weekly chart.
public struct WeekDay: Identifiable, Sendable {
    public var id: String { dateKey }
    public var dateKey: String
    public var label: String
    public var sittingSeconds: TimeInterval
    public var standingSeconds: TimeInterval

    public init(dateKey: String, label: String, sittingSeconds: TimeInterval, standingSeconds: TimeInterval) {
        self.dateKey = dateKey
        self.label = label
        self.sittingSeconds = sittingSeconds
        self.standingSeconds = standingSeconds
    }
}

/// Owns the whole tracking state: countdown session, posture, today's record,
/// history, settings.
///
/// Sessions count down and auto-advance (work → break → work …); sitting and
/// standing time during work sessions still feeds the same daily records, and
/// breaks count as rest. Two clocks run side by side: the session clock drives
/// the countdown, the segment clock drives attribution (checkpoints restart
/// segments every 30 s without disturbing the countdown).
///
/// Time, idle and notifications are injected so tests drive the store
/// deterministically with a fake clock. Production uses `.live()`.
@Observable
@MainActor
public final class SittingStore {
    public private(set) var session: SessionKind
    /// 1-based position in the Pomodoro cycle (always 1 in Stand Up mode).
    public private(set) var focusIndex: Int
    /// Sitting or standing; attributes work-session time. Pauses and breaks
    /// always count as rest.
    public private(set) var posture: Posture
    /// The countdown is frozen while paused.
    public private(set) var paused: Bool
    public private(set) var todayKey: String
    /// Start of the current uninterrupted sitting stretch (work + sitting +
    /// running); nil otherwise.
    public private(set) var continuousSitStartedAt: Date?
    /// Whether the current pause came from idle/sleep (eligible for auto-resume).
    public private(set) var autoPaused: Bool = false

    public var settings: AppSettings {
        didSet {
            // Clamp via direct assignment, never in-place: `settings.clamp()`
            // re-enters didSet through the @Observable wrapper forever (stack
            // overflow; crashed every launch once the Settings scene wrote
            // here). Assignment re-enters at most once, and clamp() is
            // idempotent so the second pass assigns nothing. saveSettings()
            // runs on every pass, so persistence is correct whether or not
            // the re-entry is suppressed.
            let clamped = settings.clamped
            if clamped != settings {
                settings = clamped
            }
            // The current session's own length changed: restart it fresh (the
            // Tauri rule). Other edits leave the running session alone.
            if oldValue.minutes(for: session, mode: oldValue.sessionMode)
                != settings.minutes(for: session, mode: settings.sessionMode)
            {
                sessionElapsedBank = 0
                sessionStartedAt = now()
            }
            saveSettings()
        }
    }

    /// Closed segments per day. The open segment is merged on the fly (see `liveToday()`).
    private var records: [String: DayRecord]
    /// Session clock: banked seconds plus the running stretch since the pause.
    private var sessionStartedAt: Date
    private var sessionElapsedBank: TimeInterval = 0
    /// Segment clock: attribution restarts here on checkpoints and changes.
    private var segmentStartedAt: Date
    private var standGoalNotified = false
    private var lastTick: Date
    /// Bumped at the end of every tick. Views read it so fine-grained
    /// @Observable tracking invalidates them once a second: every other
    /// input is stable while sitting still, so without this dependency the
    /// popover and stats window render once and freeze.
    public private(set) var tickCount = 0
    private var timer: Timer?

    private let now: @Sendable () -> Date
    private let idleSeconds: @Sendable () -> TimeInterval
    private let reminders: ReminderCenter
    private let inMemory: Bool

    /// Called at the end of every tick (MainActor). The app uses it to refresh
    /// the AppKit menu bar label; the hosted SwiftUI views observe this
    /// store through .environment instead. Nil in tests unless a test sets it.
    public var onTick: (() -> Void)?

    /// Called on every session transition when `fullScreenFlash` is on
    /// (MainActor). The app shows the full-screen flash; `quote` is pre-picked
    /// at random when `quoteOnFlash` is on, nil otherwise. Nil in tests unless set.
    public var onFlash: ((String, String, HealthQuote?) -> Void)?

    /// Gap between two ticks above which the Mac must have slept: the unknown
    /// interval is discarded instead of polluting the stats.
    private static let sleepGapThreshold: TimeInterval = 120
    /// Input within the last minute means the user is back at the Mac.
    private static let userBackThreshold: TimeInterval = 60

    // MARK: - Init

    public init(
        now: @escaping @Sendable () -> Date,
        idleSeconds: @escaping @Sendable () -> TimeInterval,
        reminders: ReminderCenter,
        inMemory: Bool,
        initialSettings: AppSettings? = nil
    ) {
        let nowDate = now()
        let settings = (initialSettings ?? (inMemory ? AppSettings() : Persistence.loadSettings())).clamped
        self.now = now
        self.idleSeconds = idleSeconds
        self.reminders = reminders
        self.inMemory = inMemory
        self.settings = settings
        self.records = inMemory ? [:] : Persistence.loadData().records
        self.todayKey = dateKey(for: nowDate)
        self.lastTick = nowDate
        self.session = .work
        self.focusIndex = 1
        self.posture = .sitting
        self.paused = settings.startPaused
        self.sessionStartedAt = nowDate
        self.segmentStartedAt = nowDate
        if !self.paused {
            self.continuousSitStartedAt = nowDate
        }
        refreshLanguagePackStatus()
    }

    /// Production store: real clock, real idle monitor, real notifications, disk
    /// persistence — and the timer already started, because the App creates this
    /// once at launch (the popover view may not exist until first opened).
    public static func live() -> SittingStore {
        let store = SittingStore(
            now: { Date() },
            idleSeconds: { IdleMonitor.secondsSinceInput() },
            reminders: .live,
            inMemory: false
        )
        store.start()
        return store
    }

    // MARK: - Live values

    /// Full length of the running session.
    public var sessionDuration: TimeInterval {
        session.duration(mode: settings.sessionMode, settings: settings)
    }

    /// Seconds counted into the running session (frozen while paused).
    public var sessionElapsed: TimeInterval {
        sessionElapsedBank + (paused ? 0 : max(0, now().timeIntervalSince(sessionStartedAt)))
    }

    /// Countdown value: what the menu bar timer shows.
    public var sessionRemaining: TimeInterval {
        max(0, sessionDuration - sessionElapsed)
    }

    /// Share of the session elapsed, for the progress bar.
    public var sessionProgress: TimeInterval {
        let duration = sessionDuration
        guard duration > 0 else { return 0 }
        return min(1, sessionElapsed / duration)
    }

    /// Compact menu bar text, e.g. `"44:32"`.
    public var menuCountdown: String {
        formatElapsed(sessionRemaining)
    }

    /// Menu bar icon: posture while working, activity while resting.
    public var statusSymbol: String {
        if paused { return "pause.circle" }
        switch session {
        case .work: return posture.symbol
        case .shortBreak: return "figure.walk"
        case .longBreak: return "cup.and.saucer"
        }
    }

    /// Menu bar / popover heading.
    public var statusTitle: String {
        let lang = settings.language
        if paused { return Strings(lang).phaseTitle(.paused) }
        return session.title(mode: settings.sessionMode, focusIndex: focusIndex, language: lang)
    }

    /// Attribution bucket of the running stretch.
    private var attributionPhase: SitPhase {
        if paused { return .paused }
        if session.isWork { return posture.attribution }
        return .paused
    }

    /// Seconds since the open segment started (checkpoints restart it).
    /// Accounting only: liveToday() merges this into the closed record.
    private var openSegmentSeconds: TimeInterval {
        max(0, now().timeIntervalSince(segmentStartedAt))
    }

    /// Length of the current uninterrupted sitting stretch (0 unless sitting).
    public var continuousSit: TimeInterval {
        guard posture == .sitting, !paused, let start = continuousSitStartedAt else { return 0 }
        return max(0, now().timeIntervalSince(start))
    }

    /// Today's closed record (without the open segment).
    public var todayRecord: DayRecord {
        records[todayKey] ?? DayRecord(dateKey: todayKey)
    }

    /// Today's record merged with the open segment: what the UI shows.
    public func liveToday() -> DayRecord {
        var record = todayRecord
        record.addSegment(phase: attributionPhase, seconds: openSegmentSeconds)
        // longestSit must also reflect a still-running stretch.
        if posture == .sitting, !paused {
            record.longestSitSeconds = max(record.longestSitSeconds, continuousSit)
        }
        return record
    }

    /// Last 7 days ending today, oldest first. Missing days are zeros; today is live.
    public func weekData() -> [WeekDay] {
        let calendar = Calendar.current
        let today = now()
        return (0..<7).map { index in
            let back = 6 - index
            let date = calendar.date(byAdding: .day, value: -back, to: today) ?? today
            let key = dateKey(for: date)
            let record: DayRecord
            if key == todayKey {
                record = liveToday()
            } else {
                record = records[key] ?? DayRecord(dateKey: key)
            }
            return WeekDay(
                dateKey: key,
                label: index == 6
                    ? Strings(settings.language).todayLabel
                    : weekdayLabel(for: date, language: settings.language),
                sittingSeconds: record.sittingSeconds,
                standingSeconds: record.standingSeconds
            )
        }
    }

    // MARK: - Timer

    public func start() {
        stop()
        lastTick = now()
        // No synchronous first tick: it would let a duplicate instance save
        // before it terminates (~50 ms later, before the 1 s timer fires).
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Session control

    /// Switches sitting/standing attribution. The session clock keeps running.
    public func setPosture(_ newPosture: Posture) {
        guard newPosture != posture else { return }
        let at = now()
        rolloverIfNeeded(at: at)
        closeSegment(upTo: at)
        posture = newPosture
        segmentStartedAt = at
        refreshContinuousSit(at: at)
        saveData()
    }

    /// Switches Stand Up / Pomodoro, restarting from a fresh work session.
    /// Posture is the user's physical state, so it carries over.
    public func setMode(_ newMode: SessionMode) {
        guard newMode != settings.sessionMode else { return }
        let at = now()
        rolloverIfNeeded(at: at)
        closeSegment(upTo: at)
        settings.sessionMode = newMode
        session = .work
        focusIndex = 1
        sessionStartedAt = at
        sessionElapsedBank = 0
        segmentStartedAt = at
        refreshContinuousSit(at: at)
        saveData()
    }

    /// Freezes or resumes the countdown.
    public func togglePause() {
        if paused {
            resume()
        } else {
            pause(manual: true)
        }
    }

    /// Jumps to the next session now, silently: a manual move needs no fanfare,
    /// and a skipped work session does not count as a completed stand-up.
    public func skipSession() {
        advance(manual: true)
    }

    // MARK: - Language pack

    /// Vietnamese pack state for the Settings language rows. Refreshed on
    /// init, when Settings appears, and after download/delete.
    public private(set) var vietnamesePackInstalled = false
    public private(set) var vietnamesePackBytes = 0

    public func refreshLanguagePackStatus() {
        vietnamesePackInstalled = LanguagePacks.isInstalled()
        vietnamesePackBytes = LanguagePacks.installedBytes() ?? 0
    }

    /// Downloads the Vietnamese pack and switches to it. Returns a localized
    /// error line on failure, nil on success.
    public func downloadVietnamesePack() async -> String? {
        do {
            _ = try await LanguagePacks.download()
        } catch {
            return Strings(settings.language).downloadFailed(error.localizedDescription)
        }
        refreshLanguagePackStatus()
        settings.language = .vietnamese
        return nil
    }

    /// Deletes the downloaded pack, freeing its bytes. Falls back to English
    /// when Vietnamese was active.
    public func deleteVietnamesePack() {
        LanguagePacks.remove()
        if settings.language == .vietnamese {
            settings.language = .english
        }
        refreshLanguagePackStatus()
    }

    private func pause(manual: Bool) {
        guard !paused else { return }
        let at = now()
        rolloverIfNeeded(at: at)
        bankElapsed(upTo: at)
        closeSegment(upTo: at)
        paused = true
        autoPaused = !manual
        segmentStartedAt = at
        continuousSitStartedAt = nil
        saveData()
    }

    private func resume() {
        guard paused else { return }
        let at = now()
        rolloverIfNeeded(at: at)
        paused = false
        autoPaused = false
        sessionStartedAt = at
        segmentStartedAt = at
        refreshContinuousSit(at: at)
        saveData()
    }

    /// Moves to the next session, closing the books on this one. A finished
    /// work session counts as one stand-up break.
    private func advance(manual: Bool) {
        let at = now()
        rolloverIfNeeded(at: at)
        closeSegment(upTo: at)
        let ended = session
        let endedDuration = ended.duration(mode: settings.sessionMode, settings: settings)
        if ended.isWork, !manual {
            records[todayKey, default: DayRecord(dateKey: todayKey)].breakCount += 1
        }
        (session, focusIndex) = nextSession(after: ended)
        sessionStartedAt = at
        sessionElapsedBank = 0
        segmentStartedAt = at
        refreshContinuousSit(at: at)
        saveData()
        if !manual {
            fanfare(ended: ended, duration: endedDuration)
        }
    }

    private func nextSession(after kind: SessionKind) -> (SessionKind, Int) {
        switch (settings.sessionMode, kind) {
        case (.standUp, .work):
            return (.shortBreak, 1)
        case (.standUp, _):
            return (.work, 1)
        case (.pomodoro, .work):
            if focusIndex >= SessionMode.pomodoroCycleLength {
                return (.longBreak, 1)
            }
            return (.shortBreak, focusIndex)
        case (.pomodoro, .shortBreak):
            return (.work, focusIndex + 1)
        case (.pomodoro, .longBreak):
            return (.work, 1)
        }
    }

    /// Bell + banner + flash for a finished session. The banner stays silent
    /// when the flash shows: the flash owns the sound, so the user never
    /// hears it twice.
    private func fanfare(ended: SessionKind, duration: TimeInterval) {
        let today = liveToday()
        let lang = settings.language
        let strings = Strings(lang)
        let title: String
        if ended.isWork {
            title = strings.workEndTitle(duration: formatDuration(duration, language: lang))
        } else {
            title = strings.breakOverTitle
        }
        let body = strings.reminderBody(
            sitting: formatShortDuration(today.sittingSeconds, language: lang),
            standing: formatShortDuration(today.standingSeconds, language: lang)
        )
        reminders.post(title, body, settings.reminderSound && !settings.fullScreenFlash)
        if settings.fullScreenFlash {
            var quote: HealthQuote?
            if settings.quoteOnFlash {
                quote = healthQuotes.randomElement()
            }
            onFlash?(title, body, quote)
        }
    }

    /// Credits session seconds up to `at` into the bank (pause-time accounting).
    private func bankElapsed(upTo at: Date) {
        sessionElapsedBank += max(0, at.timeIntervalSince(sessionStartedAt))
    }

    /// Sitting stretches accrue while sitting and running, across session
    /// boundaries: sitting through a break is still continuous sitting.
    /// Preserves an ongoing stretch across segment restarts.
    private func refreshContinuousSit(at: Date) {
        if posture == .sitting, !paused {
            continuousSitStartedAt = continuousSitStartedAt ?? at
        } else {
            continuousSitStartedAt = nil
        }
    }

    public func requestNotificationAccess() async -> Bool {
        await reminders.requestAccess()
    }

    public func notificationAuthorized() async -> Bool {
        await reminders.isAuthorized()
    }

    // MARK: - Tick

    public func tick() {
        let at = now()
        // Sleep/wake: the timer did not fire during sleep, so the gap is unknown
        // time. Credit presence up to the last tick, then auto-pause now; the
        // gap itself is discarded.
        if at.timeIntervalSince(lastTick) > Self.sleepGapThreshold {
            rolloverIfNeeded(at: at)
            if !paused {
                bankElapsed(upTo: lastTick)
            }
            closeSegment(upTo: lastTick)
            paused = true
            autoPaused = true
            segmentStartedAt = at
            continuousSitStartedAt = nil
        }
        lastTick = at
        rolloverIfNeeded(at: at)
        idleCheck(at: at)
        sessionCheck(at: at)
        goalCheck()
        tickCount += 1
        if tickCount % 30 == 0 { checkpoint() }
        onTick?()
    }

    private func idleCheck(at: Date) {
        let idle = idleSeconds()
        let threshold = TimeInterval(settings.idlePauseMinutes * 60)
        if !paused, idle >= threshold {
            // User walked away: auto-pause the countdown.
            pause(manual: false)
            _ = at
        } else if autoPaused, paused,
                  settings.autoResumeOnReturn, idle < Self.userBackThreshold
        {
            resume()
        }
    }

    private func sessionCheck(at: Date) {
        guard !paused else { return }
        _ = at
        if sessionRemaining <= 0 {
            // One transition per tick at most: the fresh session starts with a
            // full duration, so overruns never cascade. The overrun stays
            // attributed to the finished session (the user was still there).
            advance(manual: false)
        }
    }

    private func goalCheck() {
        guard !standGoalNotified else { return }
        let goal = TimeInterval(settings.standGoalMinutes * 60)
        guard goal > 0 else { return }
        if liveToday().standingSeconds >= goal {
            standGoalNotified = true
            let lang = settings.language
            reminders.post(
                Strings(lang).goalTitle,
                Strings(lang).goalBody(goal: formatShortDuration(goal, language: lang)),
                settings.reminderSound
            )
        }
    }

    // MARK: - Day rollover

    private func rolloverIfNeeded(at: Date) {
        let key = dateKey(for: at)
        guard key != todayKey else { return }
        let midnight = Calendar.current.startOfDay(for: at)
        // Close [segmentStartedAt, midnight) into the old day; the session
        // clock runs through midnight untouched.
        let boundary = max(midnight, segmentStartedAt)
        closeSegment(upTo: boundary)
        saveData()
        todayKey = key
        segmentStartedAt = midnight
        standGoalNotified = false
    }

    private func closeSegment(upTo: Date) {
        let seconds = upTo.timeIntervalSince(segmentStartedAt)
        guard seconds > 0 else { return }
        var record = records[todayKey] ?? DayRecord(dateKey: todayKey)
        // Longest-sit is credited from the stretch clock, not the attribution:
        // a stretch can span a break (sitting through it) while its seconds
        // land in rest.
        if posture == .sitting, !paused, let start = continuousSitStartedAt {
            record.longestSitSeconds = max(record.longestSitSeconds, upTo.timeIntervalSince(start))
        }
        record.addSegment(phase: attributionPhase, seconds: seconds)
        records[todayKey] = record
    }

    // MARK: - Data management

    /// Merges the open segment into today's record and persists everything.
    /// Call on quit, sleep, or backgrounding so the open stretch is never lost.
    /// The session clock is untouched: the countdown never jumps from a checkpoint.
    public func checkpoint() {
        let at = now()
        rolloverIfNeeded(at: at)
        closeSegment(upTo: at)
        segmentStartedAt = at
        saveData()
    }

    public func save() {
        checkpoint()
        saveSettings()
    }

    private func saveData() {
        guard !inMemory else { return }
        Persistence.saveData(StoredData(records: records))
    }

    private func saveSettings() {
        guard !inMemory else { return }
        Persistence.saveSettings(settings)
    }

    /// Clears today's record and restarts the open segment now.
    /// The session clock keeps running: clearing data is not a session reset.
    public func resetToday() {
        records[todayKey] = DayRecord(dateKey: todayKey)
        restartOpenSegment()
        saveData()
    }

    /// Deletes all history and restarts the open segment now.
    public func clearHistory() {
        records = [:]
        restartOpenSegment()
        saveData()
    }

    private func restartOpenSegment() {
        let at = now()
        segmentStartedAt = at
        standGoalNotified = false
        // Clearing data restarts the stretch too: otherwise pre-reset seconds
        // would leak back into longestSit. The session clock keeps running.
        if posture == .sitting, !paused {
            continuousSitStartedAt = at
        } else {
            continuousSitStartedAt = nil
        }
    }
}
