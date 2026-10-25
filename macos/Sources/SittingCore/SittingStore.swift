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

/// Owns the whole tracking state: current phase, today's record, history, settings.
///
/// Time, idle and notifications are injected so tests drive the store
/// deterministically with a fake clock. Production uses `.live()`.
@Observable
@MainActor
public final class SittingStore {
    public private(set) var phase: SitPhase
    public private(set) var phaseStartedAt: Date
    public private(set) var todayKey: String
    /// Start of the current uninterrupted sitting stretch; nil unless sitting.
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
            saveSettings()
        }
    }

    /// Closed segments per day. The open segment is merged on the fly (see `liveToday()`).
    private var records: [String: DayRecord]
    private var lastActivePhase: SitPhase = .sitting
    private var remindedContinuous: TimeInterval = 0
    private var standGoalNotified = false
    private var lastTick: Date
    /// Bumped at the end of every tick. Views read it so fine-grained
    /// @Observable tracking invalidates them once a second: every other
    /// input is stable while sitting still, so without this dependency the
    /// popover and stats window render once and freeze.
    public private(set) var tickCount = 0
    /// Display seconds closed by checkpoints within the current stretch.
    /// `checkpoint()` restarts the open segment every 30 s for crash safety;
    /// without this offset the menu bar timer would visibly reset to 0:00.
    /// Reset on every real phase change, at midnight, and on data reset.
    private var displayOffset: TimeInterval = 0
    private var timer: Timer?

    private let now: @Sendable () -> Date
    private let idleSeconds: @Sendable () -> TimeInterval
    private let reminders: ReminderCenter
    private let inMemory: Bool

    /// Called at the end of every tick (MainActor). The app uses it to refresh
    /// the AppKit menu bar label; the hosted SwiftUI views observe this
    /// store through .environment instead. Nil in tests unless a test sets it.
    public var onTick: (() -> Void)?

    /// Called on every sit reminder when `fullScreenFlash` is on (MainActor).
    /// The app shows the full-screen flash; `quote` is pre-picked at random
    /// when `quoteOnFlash` is on, nil otherwise. Nil in tests unless set.
    public var onSitReminder: ((String, String, HealthQuote?) -> Void)?

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
        if settings.startPaused {
            self.phase = .paused
        } else {
            self.phase = .sitting
        }
        self.phaseStartedAt = nowDate
        if self.phase == .sitting {
            self.continuousSitStartedAt = nowDate
        }
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

    /// Elapsed seconds of the current stretch: what the menu bar timer shows.
    /// Checkpoints restart the underlying segment every 30 s; displayOffset
    /// carries the closed part so the visible timer never jumps backwards.
    public var openElapsed: TimeInterval {
        displayOffset + openSegmentSeconds
    }

    /// Seconds since the open segment started (checkpoints restart it).
    /// Accounting only: liveToday() merges this into the closed record.
    private var openSegmentSeconds: TimeInterval {
        max(0, now().timeIntervalSince(phaseStartedAt))
    }

    /// Length of the current uninterrupted sitting stretch (0 unless sitting).
    public var continuousSit: TimeInterval {
        guard phase == .sitting, let start = continuousSitStartedAt else { return 0 }
        return max(0, now().timeIntervalSince(start))
    }

    /// Today's closed record (without the open segment).
    public var todayRecord: DayRecord {
        records[todayKey] ?? DayRecord(dateKey: todayKey)
    }

    /// Today's record merged with the open segment: what the UI shows.
    public func liveToday() -> DayRecord {
        var record = todayRecord
        record.addSegment(phase: phase, seconds: openSegmentSeconds, continuousSitSeconds: continuousSit)
        // longestSit must also reflect a still-running stretch.
        if phase == .sitting {
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

    /// Compact menu bar text, e.g. `"1:23:45"`.
    public var menuElapsed: String {
        formatElapsed(openElapsed)
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

    // MARK: - Phase changes

    /// Switches phase, closing the open segment into today's record.
    public func setPhase(_ newPhase: SitPhase, manual: Bool = true) {
        let at = now()
        rolloverIfNeeded(at: at)
        if newPhase == phase {
            if manual { autoPaused = false }
            return
        }
        closeSegment(upTo: at)
        if newPhase == .paused, phase == .sitting || phase == .standing {
            records[todayKey, default: DayRecord(dateKey: todayKey)].breakCount += 1
        }
        phase = newPhase
        phaseStartedAt = at
        displayOffset = 0
        if manual { autoPaused = false }
        switch newPhase {
        case .sitting:
            continuousSitStartedAt = at
            remindedContinuous = 0
            lastActivePhase = .sitting
        case .standing:
            continuousSitStartedAt = nil
            lastActivePhase = .standing
        case .paused:
            continuousSitStartedAt = nil
        }
        saveData()
    }

    /// Pauses, or resumes to the last active phase.
    public func togglePause() {
        if phase == .paused {
            autoPaused = false
            setPhase(lastActivePhase)
        } else {
            setPhase(.paused)
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
        // time. Close the segment where presence was last seen and start a fresh
        // auto-pause now; the gap itself is discarded.
        if at.timeIntervalSince(lastTick) > Self.sleepGapThreshold {
            rolloverIfNeeded(at: at)
            closeSegment(upTo: lastTick)
            if phase == .sitting || phase == .standing {
                records[todayKey, default: DayRecord(dateKey: todayKey)].breakCount += 1
            }
            phase = .paused
            phaseStartedAt = at
            displayOffset = 0
            continuousSitStartedAt = nil
            autoPaused = true
        }
        lastTick = at
        rolloverIfNeeded(at: at)
        idleCheck(at: at)
        reminderCheck(at: at)
        goalCheck()
        tickCount += 1
        if tickCount % 30 == 0 { checkpoint() }
        onTick?()
    }

    private func idleCheck(at: Date) {
        let idle = idleSeconds()
        let threshold = TimeInterval(settings.idlePauseMinutes * 60)
        if phase != .paused, idle >= threshold {
            // User walked away: auto-pause, keeping the phase to resume to.
            lastActivePhase = phase
            autoPaused = true
            setPhase(.paused, manual: false)
            _ = at
        } else if autoPaused, phase == .paused,
                  settings.autoResumeOnReturn, idle < Self.userBackThreshold {
            autoPaused = false
            setPhase(lastActivePhase, manual: false)
        }
    }

    private func reminderCheck(at: Date) {
        guard phase == .sitting else { return }
        let interval = TimeInterval(settings.sitReminderMinutes * 60)
        guard interval > 0 else { return }
        let cont = max(0, at.timeIntervalSince(continuousSitStartedAt ?? at))
        if cont - remindedContinuous >= interval {
            remindedContinuous = cont
            let today = liveToday()
            let lang = settings.language
            let strings = Strings(lang)
            let title = strings.reminderTitle(continuous: formatShortDuration(cont, language: lang))
            let body = strings.reminderBody(
                sitting: formatShortDuration(today.sittingSeconds, language: lang),
                standing: formatShortDuration(today.standingSeconds, language: lang)
            )
            // The banner stays silent when the flash shows: the flash owns
            // the sound, so the user never hears it twice.
            reminders.post(title, body, settings.reminderSound && !settings.fullScreenFlash)
            if settings.fullScreenFlash {
                var quote: HealthQuote?
                if settings.quoteOnFlash {
                    quote = healthQuotes.randomElement()
                }
                onSitReminder?(title, body, quote)
            }
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
        // Close [phaseStartedAt, midnight) into the old day; the same phase
        // continues into the new day.
        let boundary = max(midnight, phaseStartedAt)
        closeSegment(upTo: boundary)
        saveData()
        todayKey = key
        phaseStartedAt = midnight
        displayOffset = 0
        standGoalNotified = false
    }

    private func closeSegment(upTo: Date) {
        let seconds = upTo.timeIntervalSince(phaseStartedAt)
        guard seconds > 0 else { return }
        var record = records[todayKey] ?? DayRecord(dateKey: todayKey)
        var continuous: TimeInterval = 0
        if phase == .sitting {
            continuous = upTo.timeIntervalSince(continuousSitStartedAt ?? phaseStartedAt)
        }
        record.addSegment(phase: phase, seconds: seconds, continuousSitSeconds: continuous)
        records[todayKey] = record
    }

    // MARK: - Data management

    /// Merges the open segment into today's record and persists everything.
    /// Call on quit, sleep, or backgrounding so the open stretch is never lost.
    public func checkpoint() {
        let at = now()
        rolloverIfNeeded(at: at)
        closeSegment(upTo: at)
        displayOffset += max(0, at.timeIntervalSince(phaseStartedAt))
        phaseStartedAt = at
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
        phaseStartedAt = at
        displayOffset = 0
        remindedContinuous = 0
        standGoalNotified = false
        if phase == .sitting {
            continuousSitStartedAt = at
        } else {
            continuousSitStartedAt = nil
        }
    }
}
