import AppKit
import Foundation
import Testing
@testable import SittingCore

// MARK: - Fakes

/// Mutable clock captured by the store's `@Sendable` providers.
/// `@unchecked Sendable` is safe here: every test touches it from `@MainActor` only.
final class FakeClock: @unchecked Sendable {
    var now: Date
    init(_ now: Date) { self.now = now }
    func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}

final class FakeIdle: @unchecked Sendable {
    var seconds: TimeInterval = 0
}

final class SpyNotify: @unchecked Sendable {
    var posts: [(title: String, body: String, sound: Bool)] = []
    var reminderCount: Int { posts.count }
}

/// Advances the fake clock in 1-second steps, ticking the store each time —
/// the same cadence as the production 1 s timer (and it never trips the
/// sleep-gap detector, which needs a > 120 s jump between ticks).
@MainActor
func run(_ store: SittingStore, _ clock: FakeClock, seconds: Int) {
    for _ in 0..<seconds {
        clock.advance(1)
        store.tick()
    }
}

func isNear(_ actual: TimeInterval, _ expected: TimeInterval, tolerance: TimeInterval = 2) -> Bool {
    abs(actual - expected) <= tolerance
}

/// 10:00 local today: long simulated runs (up to 8 h) never cross midnight,
// in any time zone.
func defaultTestStart() -> Date {
    Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())
        ?? Date(timeIntervalSince1970: 1_790_000_000)
}

@MainActor
func makeStore(
    start: Date? = nil,
    settings: AppSettings? = nil,
    idle: TimeInterval = 0
) -> (store: SittingStore, clock: FakeClock, idleBox: FakeIdle, spy: SpyNotify) {
    let clock = FakeClock(start ?? defaultTestStart())
    let idleBox = FakeIdle()
    idleBox.seconds = idle
    let spy = SpyNotify()
    let center = ReminderCenter(
        requestAccess: { true },
        post: { title, body, sound in spy.posts.append((title, body, sound)) },
        isAuthorized: { true }
    )
    let store = SittingStore(
        now: { clock.now },
        idleSeconds: { idleBox.seconds },
        reminders: center,
        inMemory: true,
        initialSettings: settings
    )
    return (store, clock, idleBox, spy)
}

/// 1-minute sessions for fast transition tests (Stand Up by default).
func minuteSettings(mode: SessionMode = .standUp) -> AppSettings {
    var settings = AppSettings()
    settings.sessionMode = mode
    settings.standUpWorkMinutes = 1
    settings.standUpBreakMinutes = 1
    settings.pomodoroWorkMinutes = 1
    settings.pomodoroShortMinutes = 1
    settings.pomodoroLongMinutes = 1
    settings.standGoalMinutes = 0
    return settings
}

/// Installs the checked-in Vietnamese pack so `.vietnamese` lookups resolve.
/// Idempotent (same content every call), so parallel tests can all call it.
func installVietnamesePackForTests() {
    let here = URL(fileURLWithPath: #filePath)
    let packURL = here
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources/LanguagePacks/vi.json")
    let data = try! Data(contentsOf: packURL)
    let pack = try! JSONDecoder().decode(LanguagePack.self, from: data)
    LanguagePacks.setOverrideForTesting(pack)
}

// MARK: - Store behaviour

@Suite struct SittingStoreTests {
    @Test @MainActor func startsInFreshWorkSession() {
        let (store, _, _, _) = makeStore()
        #expect(store.session == .work)
        #expect(store.focusIndex == 1)
        #expect(store.posture == .sitting)
        #expect(store.paused == false)
        #expect(store.sessionRemaining == 45 * 60)
        #expect(store.menuCountdown == "45:00")
        #expect(store.statusTitle == "Work")
        #expect(store.statusSymbol == "laptopcomputer")
    }

    @Test @MainActor func startsPausedWhenConfigured() {
        var settings = AppSettings()
        settings.startPaused = true
        let (store, _, _, _) = makeStore(settings: settings)
        #expect(store.paused == true)
        #expect(store.autoPaused == false)
        #expect(store.sessionRemaining == 45 * 60)
        #expect(store.statusTitle == "Paused")
    }

    @Test @MainActor func countdownDecreasesAndFormats() {
        let (store, clock, _, _) = makeStore()
        run(store, clock, seconds: 61)
        #expect(store.sessionRemaining == 45 * 60 - 61)
        #expect(store.menuCountdown == "43:59")
        #expect(isNear(store.sessionProgress, 61.0 / 2700.0, tolerance: 0.01))
    }

    @Test @MainActor func pauseFreezesCountdown() {
        let (store, clock, _, _) = makeStore()
        run(store, clock, seconds: 60)
        store.togglePause()
        #expect(store.paused == true)
        run(store, clock, seconds: 120)
        #expect(store.sessionRemaining == 45 * 60 - 60)
        store.togglePause()
        #expect(store.paused == false)
        run(store, clock, seconds: 60)
        #expect(store.sessionRemaining == 45 * 60 - 120)
    }

    @Test @MainActor func workEndAutoAdvancesToBreakWithFanfare() {
        let (store, clock, _, spy) = makeStore(settings: minuteSettings())
        var flashed: [(String, String, HealthQuote?)] = []
        store.onFlash = { flashed.append(($0, $1, $2)) }
        run(store, clock, seconds: 60)
        #expect(store.session == .shortBreak)
        #expect(store.sessionRemaining == 60)
        #expect(spy.reminderCount == 1)
        #expect(store.liveToday().breakCount == 1)
        #expect(spy.posts.first?.title.contains("stand up and move") == true)
        #expect(spy.posts.first?.body.contains("Today:") == true)
        // Banner posted silent: the flash owns the sound.
        #expect(spy.posts.first?.sound == false)
        #expect(flashed.count == 1)
        #expect(flashed.first?.2 != nil)
    }

    @Test @MainActor func breakEndAutoAdvancesToWork() {
        let (store, clock, _, spy) = makeStore(settings: minuteSettings())
        run(store, clock, seconds: 60)
        run(store, clock, seconds: 60)
        #expect(store.session == .work)
        #expect(spy.reminderCount == 2)
        #expect(store.liveToday().breakCount == 1)
        #expect(spy.posts.last?.title == "Break over — back to work!")
    }

    @Test @MainActor func standUpCycleRepeats() {
        let (store, clock, _, _) = makeStore(settings: minuteSettings())
        run(store, clock, seconds: 60)
        #expect(store.session == .shortBreak)
        run(store, clock, seconds: 60)
        #expect(store.session == .work)
        run(store, clock, seconds: 60)
        #expect(store.session == .shortBreak)
        #expect(store.liveToday().breakCount == 2)
    }

    @Test @MainActor func pomodoroFullCycle() {
        let (store, clock, _, spy) = makeStore(settings: minuteSettings(mode: .pomodoro))
        let expected: [(SessionKind, Int)] = [
            (.shortBreak, 1), (.work, 2), (.shortBreak, 2), (.work, 3),
            (.shortBreak, 3), (.work, 4), (.longBreak, 1), (.work, 1),
        ]
        for (kind, focus) in expected {
            run(store, clock, seconds: 60)
            #expect(store.session == kind)
            #expect(store.focusIndex == focus)
        }
        #expect(store.liveToday().breakCount == 4)
        #expect(spy.reminderCount == 8)
        #expect(store.statusTitle == "Focus 1/4")
    }

    @Test @MainActor func pomodoroWorkTitleCountsFocus() {
        var settings = AppSettings()
        settings.sessionMode = .pomodoro
        let (store, _, _, _) = makeStore(settings: settings)
        #expect(store.statusTitle == "Focus 1/4")
    }

    @Test @MainActor func skipAdvancesSilently() {
        let (store, clock, _, spy) = makeStore(settings: minuteSettings())
        store.skipSession()
        #expect(store.session == .shortBreak)
        #expect(spy.reminderCount == 0)
        #expect(store.liveToday().breakCount == 0)
        store.skipSession()
        #expect(store.session == .work)
        #expect(spy.reminderCount == 0)
        // Skip keeps the pause state and freezes the fresh session.
        store.togglePause()
        run(store, clock, seconds: 30)
        store.skipSession()
        #expect(store.paused == true)
        #expect(store.sessionRemaining == 60)
    }

    @Test @MainActor func postureAttributesWorkTime() {
        let (store, clock, _, _) = makeStore()
        run(store, clock, seconds: 60)
        store.setPosture(.standing)
        #expect(store.statusSymbol == "figure.stand")
        run(store, clock, seconds: 30)
        let today = store.liveToday()
        #expect(isNear(today.sittingSeconds, 60))
        #expect(isNear(today.standingSeconds, 30))
        // Posture never disturbs the countdown.
        #expect(isNear(store.sessionRemaining, 45 * 60 - 90))
    }

    @Test @MainActor func breaksAndPausesCountAsRest() {
        let (store, clock, _, _) = makeStore(settings: minuteSettings())
        run(store, clock, seconds: 60)
        run(store, clock, seconds: 60)
        store.togglePause()
        run(store, clock, seconds: 30)
        let today = store.liveToday()
        #expect(isNear(today.sittingSeconds, 60))
        #expect(isNear(today.pausedSeconds, 90))
        #expect(isNear(today.standingSeconds, 0))
    }

    @Test @MainActor func longestSitTracksLongestStretch() {
        var settings = AppSettings()
        settings.standGoalMinutes = 0
        let (store, clock, _, _) = makeStore(settings: settings)
        run(store, clock, seconds: 20 * 60)
        store.setPosture(.standing)
        run(store, clock, seconds: 60)
        store.setPosture(.sitting)
        // 50 more minutes: a work→break→work transition happens mid-stretch,
        // and the stretch survives it (sitting through a break is still
        // continuous sitting).
        run(store, clock, seconds: 50 * 60)
        #expect(isNear(store.liveToday().longestSitSeconds, 3000, tolerance: 5))
    }

    @Test @MainActor func setModeKeepsWorkSessionAndElapsed() {
        let (store, clock, _, spy) = makeStore()
        store.setPosture(.standing)
        run(store, clock, seconds: 30)
        store.setMode(.pomodoro)
        #expect(store.session == .work)
        #expect(store.focusIndex == 1)
        #expect(store.posture == .standing)
        // The 30 s carry over into the 25-minute Pomodoro focus.
        #expect(isNear(store.sessionRemaining, 25 * 60 - 30))
        #expect(spy.reminderCount == 0)
        // Stats kept the banked seconds too.
        #expect(isNear(store.liveToday().standingSeconds, 30))
        // And back: the same elapsed time under the 45-minute Stand Up work.
        store.setMode(.standUp)
        #expect(store.session == .work)
        #expect(isNear(store.sessionRemaining, 45 * 60 - 30))
    }

    @Test @MainActor func setModeKeepsBreak() {
        let (store, clock, _, _) = makeStore(settings: minuteSettings())
        run(store, clock, seconds: 60)
        #expect(store.session == .shortBreak)
        run(store, clock, seconds: 20)
        store.setMode(.pomodoro)
        #expect(store.session == .shortBreak)
        #expect(isNear(store.sessionRemaining, 60 - 20))
    }

    @Test @MainActor func setModeMapsLongBreakToShortBreak() {
        let (store, clock, _, _) = makeStore(settings: minuteSettings(mode: .pomodoro))
        // work → short ×3, work → long: 7 transitions to the long break.
        for _ in 0..<7 {
            run(store, clock, seconds: 60)
        }
        #expect(store.session == .longBreak)
        run(store, clock, seconds: 10)
        store.setMode(.standUp)
        #expect(store.session == .shortBreak)
        #expect(store.focusIndex == 1)
        #expect(isNear(store.sessionRemaining, 60 - 10))
    }

    @Test @MainActor func setModeOverrunAdvancesNextTick() {
        var settings = AppSettings()
        settings.standUpWorkMinutes = 45
        settings.pomodoroWorkMinutes = 25
        let (store, clock, _, _) = makeStore(settings: settings)
        run(store, clock, seconds: 30 * 60)
        store.setMode(.pomodoro)
        #expect(store.session == .work)
        #expect(store.sessionRemaining == 0)
        run(store, clock, seconds: 1)
        #expect(store.session == .shortBreak)
    }

    @Test @MainActor func durationChangeRestartsCurrentSessionOnly() {
        let (store, clock, _, _) = makeStore()
        run(store, clock, seconds: 30)
        store.settings.standUpWorkMinutes = 50
        #expect(store.sessionRemaining == 50 * 60)
        run(store, clock, seconds: 10)
        #expect(store.sessionRemaining == 50 * 60 - 10)
        // Other durations leave the running session alone.
        store.settings.standUpBreakMinutes = 10
        #expect(store.sessionRemaining == 50 * 60 - 10)
        store.settings.language = .vietnamese
        #expect(store.sessionRemaining == 50 * 60 - 10)
    }

    @Test @MainActor func idleAutoPausesAndAutoResumes() {
        var settings = AppSettings()
        settings.idlePauseMinutes = 5
        settings.autoResumeOnReturn = true
        settings.standGoalMinutes = 0
        let (store, clock, idleBox, _) = makeStore(settings: settings)
        run(store, clock, seconds: 10)
        idleBox.seconds = 400
        store.tick()
        #expect(store.paused == true)
        #expect(store.autoPaused == true)
        let frozen = store.sessionRemaining
        run(store, clock, seconds: 60)
        #expect(store.sessionRemaining == frozen)
        idleBox.seconds = 0
        store.tick()
        #expect(store.paused == false)
        #expect(store.autoPaused == false)
    }

    @Test @MainActor func manualPauseNeverAutoResumes() {
        var settings = AppSettings()
        settings.autoResumeOnReturn = true
        let (store, clock, idleBox, _) = makeStore(settings: settings)
        run(store, clock, seconds: 10)
        store.togglePause()
        #expect(store.autoPaused == false)
        idleBox.seconds = 0
        store.tick()
        #expect(store.paused == true)
    }

    @Test @MainActor func noAutoResumeWhenDisabled() {
        var settings = AppSettings()
        settings.idlePauseMinutes = 5
        settings.autoResumeOnReturn = false
        let (store, clock, idleBox, _) = makeStore(settings: settings)
        run(store, clock, seconds: 10)
        idleBox.seconds = 400
        store.tick()
        #expect(store.paused == true)
        idleBox.seconds = 0
        store.tick()
        #expect(store.paused == true)
    }

    @Test @MainActor func sleepGapDiscardsUnknownTime() {
        var settings = AppSettings()
        settings.standGoalMinutes = 0
        let (store, clock, idleBox, _) = makeStore(settings: settings)
        run(store, clock, seconds: 60)
        // 8 h pass with no tick: the Mac slept.
        clock.advance(8 * 3600)
        idleBox.seconds = 8 * 3600
        store.tick()
        #expect(store.paused == true)
        #expect(store.autoPaused == true)
        let today = store.liveToday()
        #expect(isNear(today.sittingSeconds, 60, tolerance: 5))
        #expect(today.sittingSeconds < 3600)
        // Back at the Mac: resumes, sleep gap stays out of the stats,
        // countdown resumes where presence was last seen.
        idleBox.seconds = 0
        store.tick()
        #expect(store.paused == false)
        #expect(store.liveToday().sittingSeconds < 3600)
        #expect(isNear(store.sessionRemaining, 45 * 60 - 60, tolerance: 5))
    }

    @Test @MainActor func overnightSleepDiscardsGapAcrossMidnight() {
        var settings = AppSettings()
        settings.standGoalMinutes = 0
        settings.autoResumeOnReturn = false
        let calendar = Calendar.current
        guard let start = calendar.date(bySettingHour: 23, minute: 50, second: 0, of: Date()) else {
            Issue.record("cannot build 23:50 test date")
            return
        }
        let (store, clock, idleBox, _) = makeStore(start: start, settings: settings)
        run(store, clock, seconds: 60)
        // Sleep through the night: one tick 9 h later, past midnight.
        clock.advance(9 * 3600)
        idleBox.seconds = 9 * 3600
        store.tick()
        #expect(store.paused == true)
        #expect(store.autoPaused == true)
        #expect(store.todayKey == dateKey(for: clock.now))
        // Yesterday holds only real presence (~1 min) — the [23:51, midnight)
        // stretch was asleep, not presence. Today starts empty.
        let week = store.weekData()
        #expect(isNear(week[week.count - 2].trackedSeconds, 60, tolerance: 5))
        #expect(store.liveToday().trackedSeconds == 0)
    }

    @Test @MainActor func midnightRolloverSplitsTheSegment() {
        var settings = AppSettings()
        settings.standGoalMinutes = 0
        let calendar = Calendar.current
        guard let start = calendar.date(bySettingHour: 23, minute: 50, second: 0, of: Date()) else {
            Issue.record("cannot build 23:50 test date")
            return
        }
        let (store, clock, _, _) = makeStore(start: start, settings: settings)
        run(store, clock, seconds: 20 * 60)
        #expect(store.todayKey == dateKey(for: clock.now))
        // The session runs through midnight untouched.
        #expect(store.session == .work)
        #expect(isNear(store.sessionRemaining, 45 * 60 - 1200, tolerance: 5))
        // Uninterrupted stretch survives midnight.
        #expect(store.continuousSit > 1100)
        let week = store.weekData()
        #expect(week.count == 7)
        #expect(week.last?.label == "Today")
        let yesterday = week[week.count - 2]
        #expect(isNear(yesterday.sittingSeconds, 600, tolerance: 5))
        #expect(isNear(store.liveToday().sittingSeconds, 600, tolerance: 5))
    }

    @Test @MainActor func checkpointKeepsCountdownAndNoDoubleCount() {
        let (store, clock, _, _) = makeStore()
        run(store, clock, seconds: 35)
        // A checkpoint fired at tick 30: the countdown must not jump ...
        #expect(isNear(store.sessionRemaining, 45 * 60 - 35))
        // ... and the checkpointed seconds must not be counted twice.
        #expect(isNear(store.todayRecord.sittingSeconds, 30))
        #expect(isNear(store.liveToday().sittingSeconds, 35))
    }

    @Test @MainActor func standGoalNotifiesOncePerDay() {
        var settings = AppSettings()
        settings.standGoalMinutes = 60
        let (store, clock, _, spy) = makeStore(settings: settings)
        store.setPosture(.standing)
        // Standing accrues during work sessions only: 45 + 5 + 20.
        run(store, clock, seconds: 70 * 60)
        let goals = spy.posts.filter { $0.title.contains("standing goal") }
        #expect(goals.count == 1)
        run(store, clock, seconds: 10 * 60)
        #expect(spy.posts.filter { $0.title.contains("standing goal") }.count == 1)
    }

    @Test @MainActor func resetTodayClearsAndKeepsSession() {
        let (store, clock, _, _) = makeStore()
        run(store, clock, seconds: 60)
        store.resetToday()
        let today = store.liveToday()
        #expect(today.sittingSeconds == 0)
        #expect(today.breakCount == 0)
        #expect(today.longestSitSeconds == 0)
        #expect(store.session == .work)
        // Clearing data is not a session reset: the countdown continues.
        #expect(isNear(store.sessionRemaining, 45 * 60 - 60))
        #expect(store.continuousSit < 5)
    }

    @Test @MainActor func clearHistoryWipesEverything() {
        let (store, clock, _, _) = makeStore()
        run(store, clock, seconds: 60)
        store.setPosture(.standing)
        run(store, clock, seconds: 30)
        store.clearHistory()
        let today = store.liveToday()
        #expect(today.trackedSeconds == 0)
        #expect(store.weekData().allSatisfy { $0.sittingSeconds == 0 && $0.standingSeconds == 0 })
    }

    @Test @MainActor func weekDataHasSevenDaysEndingToday() {
        let (store, clock, _, _) = makeStore()
        run(store, clock, seconds: 30)
        let week = store.weekData()
        #expect(week.count == 7)
        #expect(week.last?.dateKey == store.todayKey)
        #expect(isNear(week.last?.sittingSeconds ?? -1, 30))
        #expect(week.dropLast().allSatisfy { $0.sittingSeconds == 0 && $0.standingSeconds == 0 })
    }

    @Test @MainActor func hourlySplitAcrossHourBoundary() {
        let start = Calendar.current.date(bySettingHour: 10, minute: 59, second: 30, of: Date())!
        let (store, clock, _, _) = makeStore(start: start)
        // 30 s in hour 10, 60 s in hour 11 — through closed segments
        // (checkpoints) and the open one.
        run(store, clock, seconds: 90)
        let today = store.liveToday()
        #expect(isNear(today.sittingSeconds, 90))
        #expect(isNear(today.hourly[10].sittingSeconds, 30))
        #expect(isNear(today.hourly[11].sittingSeconds, 60))
        #expect(today.hourly.enumerated().allSatisfy { $0.offset == 10 || $0.offset == 11 || $0.element.trackedSeconds == 0 })
        #expect(isNear(store.weekData().last?.trackedSeconds ?? -1, 90))
    }

    @Test @MainActor func resumeBanksPausedStretchAsRest() {
        let (store, clock, _, _) = makeStore()
        run(store, clock, seconds: 10)
        store.togglePause()
        // 10 paused ticks: no checkpoint fires (tick 11–20), so without the
        // resume-time closeSegment these seconds would vanish from history.
        run(store, clock, seconds: 10)
        store.togglePause()
        #expect(isNear(store.liveToday().pausedSeconds, 10))
        #expect(isNear(store.liveToday().hourly[10].pausedSeconds, 10))
    }

    @Test @MainActor func settingsWriteAfterInitClampsWithoutRecursion() {
        // Regression test: `settings.clamp()` inside didSet re-entered didSet
        // through the @Observable wrapper forever (stack overflow on launch).
        let (store, _, _, _) = makeStore()
        store.settings = AppSettings(standUpWorkMinutes: 999, pomodoroLongMinutes: 0, idlePauseMinutes: 0, standGoalMinutes: -5)
        #expect(store.settings.standUpWorkMinutes == 240)
        #expect(store.settings.pomodoroLongMinutes == 1)
        #expect(store.settings.idlePauseMinutes == 1)
        #expect(store.settings.standGoalMinutes == 0)
        store.settings.launchAtLogin = true // member-wise write, the crash shape
        #expect(store.settings.launchAtLogin == true)
    }

    @Test @MainActor func onTickFiresOncePerTick() {
        let (store, clock, _, _) = makeStore()
        var calls = 0
        store.onTick = { calls += 1 }
        run(store, clock, seconds: 5)
        #expect(calls == 5)
        store.onTick = nil
        run(store, clock, seconds: 3)
        #expect(calls == 5)
    }
}

// MARK: - Models and formatting (pure, no actor needed)

@Suite struct ModelTests {
    @Test func dayRecordMergesSegments() {
        var record = DayRecord(dateKey: "2026-10-25")
        record.addSegment(phase: .sitting, seconds: 100, continuousSitSeconds: 100)
        record.addSegment(phase: .sitting, seconds: 50, continuousSitSeconds: 150)
        record.addSegment(phase: .standing, seconds: 30)
        record.addSegment(phase: .paused, seconds: 10)
        record.addSegment(phase: .sitting, seconds: -5)
        record.addSegment(phase: .sitting, seconds: 0)
        #expect(record.sittingSeconds == 150)
        #expect(record.standingSeconds == 30)
        #expect(record.pausedSeconds == 10)
        #expect(record.longestSitSeconds == 150)
        #expect(record.trackedSeconds == 190)
    }

    @Test func dayRecordHourlyBuckets() {
        var record = DayRecord(dateKey: "2026-10-25")
        #expect(record.hourly.count == 24)
        record.addHourly(hour: 9, phase: .sitting, seconds: 100)
        record.addHourly(hour: 9, phase: .standing, seconds: 30)
        record.addHourly(hour: 24, phase: .sitting, seconds: 50)
        record.addHourly(hour: -1, phase: .sitting, seconds: 50)
        record.addHourly(hour: 10, phase: .paused, seconds: 0)
        #expect(record.hourly[9].sittingSeconds == 100)
        #expect(record.hourly[9].standingSeconds == 30)
        #expect(record.hourly[9].trackedSeconds == 130)
        #expect(record.hourly[10].trackedSeconds == 0)
    }

    @Test func dayRecordDecodesWithoutHourlyKey() {
        // Files written before v1.1.0 have no hourly key: totals decode,
        // buckets default to zeros.
        let json = #"{"dateKey":"2026-10-25","sittingSeconds":100,"standingSeconds":20,"pausedSeconds":10,"breakCount":1,"longestSitSeconds":60}"#
        let record = try! JSONDecoder().decode(DayRecord.self, from: Data(json.utf8))
        #expect(record.sittingSeconds == 100)
        #expect(record.breakCount == 1)
        #expect(record.hourly.count == 24)
        #expect(record.hourly.allSatisfy { $0.trackedSeconds == 0 })
        // Round-trip with hourly data survives.
        var changed = record
        changed.addHourly(hour: 9, phase: .sitting, seconds: 100)
        let back = try! JSONDecoder().decode(DayRecord.self, from: JSONEncoder().encode(changed))
        #expect(back == changed)
    }

    @Test func settingsClampToSaneRanges() {
        var settings = AppSettings(standUpWorkMinutes: 999, pomodoroLongMinutes: 0, idlePauseMinutes: 0, standGoalMinutes: -5)
        settings.clamp()
        #expect(settings.standUpWorkMinutes == 240)
        #expect(settings.pomodoroLongMinutes == 1)
        #expect(settings.idlePauseMinutes == 1)
        #expect(settings.standGoalMinutes == 0)
    }

    @Test func sessionMinutesPerMode() {
        let settings = AppSettings()
        #expect(settings.minutes(for: .work, mode: .standUp) == 45)
        #expect(settings.minutes(for: .shortBreak, mode: .standUp) == 5)
        #expect(settings.minutes(for: .longBreak, mode: .standUp) == 5)
        #expect(settings.minutes(for: .work, mode: .pomodoro) == 25)
        #expect(settings.minutes(for: .shortBreak, mode: .pomodoro) == 5)
        #expect(settings.minutes(for: .longBreak, mode: .pomodoro) == 15)
        var custom = AppSettings()
        custom.standUpWorkMinutes = 50
        #expect(custom.minutes(for: .work, mode: .standUp) == 50)
        #expect(SessionMode.standUp.displayName == "Stand Up")
        #expect(SessionMode.pomodoro.displayName == "Pomodoro")
        #expect(SessionMode.pomodoroCycleLength == 4)
    }

    @Test func sessionTitlesInBothLanguages() {
        installVietnamesePackForTests()
        #expect(SessionKind.work.title(mode: .standUp, focusIndex: 1, language: .vietnamese) == "Làm việc")
        #expect(SessionKind.shortBreak.title(mode: .standUp, focusIndex: 1, language: .vietnamese) == "Vận động")
        #expect(SessionKind.work.title(mode: .pomodoro, focusIndex: 2, language: .vietnamese) == "Tập trung 2/4")
        #expect(SessionKind.shortBreak.title(mode: .pomodoro, focusIndex: 2, language: .english) == "Short break")
        #expect(SessionKind.longBreak.title(mode: .pomodoro, focusIndex: 1, language: .english) == "Long break")
        #expect(Strings(.english).breakOverTitle == "Break over — back to work!")
        #expect(Strings(.english).skipButton == "Skip")
    }

    @Test func elapsedFormatsLikeAClock() {
        #expect(formatElapsed(3661) == "1:01:01")
        #expect(formatElapsed(61) == "1:01")
        #expect(formatElapsed(5) == "0:05")
        #expect(formatElapsed(0) == "0:00")
    }

    @Test func durationFormatsInVietnamese() {
        installVietnamesePackForTests()
        #expect(formatDuration(3600, language: .vietnamese) == "1 giờ")
        #expect(formatDuration(5400, language: .vietnamese) == "1 giờ 30 phút")
        #expect(formatDuration(300, language: .vietnamese) == "5 phút")
        #expect(formatDuration(30, language: .vietnamese) == "30 giây")
    }

    @Test func sitPhaseHasVietnameseTitles() {
        installVietnamesePackForTests()
        #expect(SitPhase.sitting.shortTitle(in: .vietnamese) == "Ngồi")
        #expect(SitPhase.standing.shortTitle(in: .vietnamese) == "Đứng")
        #expect(SitPhase.paused.shortTitle(in: .vietnamese) == "Nghỉ")
        #expect(SitPhase.allCases.count == 3)
        #expect(Posture.allCases.count == 2)
        #expect(Posture.standing.symbol == "figure.stand")
        #expect(Posture.sitting.attribution == .sitting)
    }

    @Test func durationFormatsInEnglishWithPlurals() {
        #expect(formatDuration(3600, language: .english) == "1 hour")
        #expect(formatDuration(5400, language: .english) == "1 hour 30 minutes")
        #expect(formatDuration(60, language: .english) == "1 minute")
        #expect(formatDuration(300, language: .english) == "5 minutes")
        #expect(formatDuration(1, language: .english) == "1 second")
        #expect(formatDuration(30, language: .english) == "30 seconds")
        #expect(SitPhase.sitting.shortTitle(in: .english) == "Sit")
        #expect(SitPhase.paused.title(in: .english) == "Paused")
        #expect(Strings(.english).quitButton == "Quit")
        #expect(Strings(.english).breaksLine(count: 1, longest: "5 minutes") == "1 stand-up • Longest sit 5 minutes")
    }

    @Test func solarLabelsForPopoverTile() {
        // 2026-02-17 is a Tuesday in ISO week 8; 2026-10-26 a Monday starting
        // ISO week 44 (2026-01-01 is a Thursday, so W1 starts Dec 29 2025).
        let feb = solarLabels(for: solarDate(2026, 2, 17))
        #expect(feb.week == "W8")
        #expect(feb.month == "FEB")
        #expect(feb.day == "17")
        let oct = solarLabels(for: solarDate(2026, 10, 26))
        #expect(oct.week == "W44")
        #expect(oct.month == "OCT")
        #expect(oct.day == "26")
    }

    @Test func weekdayLabelsInBothLanguages() {
        // 2026-10-25 is a Sunday; 2026-10-26 a Monday (public calendar facts).
        installVietnamesePackForTests()
        let sunday = solarDate(2026, 10, 25)
        let monday = solarDate(2026, 10, 26)
        #expect(weekdayLabel(for: sunday, language: .vietnamese) == "CN")
        #expect(weekdayLabel(for: monday, language: .vietnamese) == "T2")
        #expect(weekdayLabel(for: sunday) == "Sun")
        #expect(weekdayLabel(for: monday) == "Mon")
    }

    @Test func oldSettingsWithoutNewKeysLoadWithDefaults() {
        // A settings.json from the pre-session model: the removed
        // `sitReminderMinutes` is ignored, every new field gets its default.
        let json = #"{"sitReminderMinutes":45,"idlePauseMinutes":5,"standGoalMinutes":60,"autoResumeOnReturn":true,"startPaused":false,"reminderSound":true,"launchAtLogin":false}"#
        let decoded = try? JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        #expect(decoded?.sessionMode == .standUp)
        #expect(decoded?.standUpWorkMinutes == 45)
        #expect(decoded?.standUpBreakMinutes == 5)
        #expect(decoded?.pomodoroWorkMinutes == 25)
        #expect(decoded?.language == .english)
        #expect(decoded?.subCalendar == .vietnamese)
        #expect(decoded?.fullScreenFlash == true)
        #expect(decoded?.quoteOnFlash == true)
    }

    @Test @MainActor func englishWeekLabelsFollowSettings() {
        var settings = AppSettings()
        settings.language = .english
        let (store, clock, _, _) = makeStore(settings: settings)
        run(store, clock, seconds: 5)
        let week = store.weekData()
        #expect(week.last?.label == "Today")
    }

    @Test @MainActor func englishTransitionTextFollowsSettings() {
        var settings = minuteSettings(mode: .standUp)
        settings.language = .english
        let (store, clock, _, spy) = makeStore(settings: settings)
        run(store, clock, seconds: 65)
        #expect(spy.reminderCount == 1)
        #expect(spy.posts.first?.title.contains("stand up and move") == true)
        #expect(spy.posts.first?.body.contains("Today:") == true)
    }

    @Test @MainActor func flashHookFiresWithRandomQuote() {
        installVietnamesePackForTests()
        var viSettings = minuteSettings()
        viSettings.language = .vietnamese
        let (store, clock, _, spy) = makeStore(settings: viSettings)
        var flashed: [(String, String, HealthQuote?)] = []
        store.onFlash = { flashed.append(($0, $1, $2)) }
        run(store, clock, seconds: 65)
        #expect(flashed.count == 1)
        if let first = flashed.first {
            #expect(first.0.contains("đứng dậy"))
            #expect(first.1.contains("Hôm nay:"))
            #expect(first.2 != nil)
            #expect(healthQuotes.contains(first.2!))
        }
        // Banner posted silent: the flash owns the sound.
        #expect(spy.posts.first?.sound == false)
    }

    @Test @MainActor func flashHookRespectsSwitches() {
        // Flash off: no hook, banner keeps its sound.
        var off = minuteSettings()
        off.fullScreenFlash = false
        let (storeA, clockA, _, spyA) = makeStore(settings: off)
        var countA = 0
        storeA.onFlash = { _, _, _ in countA += 1 }
        run(storeA, clockA, seconds: 65)
        #expect(countA == 0)
        #expect(spyA.posts.first?.sound == true)
        // Quote off: hook fires with a nil quote, banner silent.
        var noQuote = minuteSettings()
        noQuote.quoteOnFlash = false
        let (storeB, clockB, _, spyB) = makeStore(settings: noQuote)
        var flashedB: [(String, String, HealthQuote?)] = []
        storeB.onFlash = { flashedB.append(($0, $1, $2)) }
        run(storeB, clockB, seconds: 65)
        #expect(flashedB.count == 1)
        if let first = flashedB.first {
            #expect(first.2 == nil)
        }
        #expect(spyB.posts.first?.sound == false)
    }
}

// MARK: - Secondary calendar

/// Noon UTC: safely inside the same civil day in UTC+7/+8 and the test time zones.
func solarDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
}

@Suite struct SubCalendarTests {
    @Test func offReturnsNil() {
        #expect(subCalendarDate(for: solarDate(2026, 2, 17), calendar: .off, language: .vietnamese) == nil)
    }

    @Test func tetIsLunarNewYear() {
        installVietnamesePackForTests()
        // Tết Bính Ngọ: 2026-02-17 is lunar 1/1 (public holiday fact).
        let date = solarDate(2026, 2, 17)
        for type in [SubCalendar.vietnamese, SubCalendar.chinese] {
            let lunar = subCalendarDate(for: date, calendar: type, language: .vietnamese)
            #expect(lunar?.day == "1")
            #expect(lunar?.sub == "1")
            #expect(lunar?.isLeapMonth == false)
            #expect(lunar?.accessibleLabel.contains("Bính Ngọ") == true)
            #expect(lunar?.yearLabel == "Bính Ngọ")
            #expect(lunar?.yearElement == .fire)
            #expect(lunar?.yearAnimal == .horse)
        }
        let en = subCalendarDate(for: date, calendar: .vietnamese, language: .english)
        #expect(en?.accessibleLabel.contains("Binh Ngo") == true)
        #expect(en?.yearLabel == "Binh Ngo")
    }

    @Test func leapMonthIsFlagged() {
        installVietnamesePackForTests()
        // 2025 has a leap 6th lunar month (Jul 25 – Aug 22); Aug 1 is inside it.
        let lunar = subCalendarDate(for: solarDate(2025, 8, 1), calendar: .vietnamese, language: .vietnamese)
        #expect(lunar?.isLeapMonth == true)
        #expect(lunar?.sub == "6N")
        #expect(lunar?.accessibleLabel.contains("nhuận") == true)
        #expect(lunar?.yearLabel == "Ất Tỵ")
        #expect(lunar?.yearElement == .wood)
    }

    @Test func hebrewHolidays() {
        // Yom Kippur 2026-09-21 is 10 Tishri 5787 (public holiday fact).
        let kippur = subCalendarDate(for: solarDate(2026, 9, 21), calendar: .hebrew, language: .vietnamese)
        #expect(kippur?.day == "10")
        #expect(kippur?.sub == "Tishri")
        #expect(kippur?.yearLabel == "5787")
        #expect(kippur?.yearElement == nil)
        // Purim Katan 2024-02-23 is 14 Adar I 5784 (leap year, public fact).
        let adar1 = subCalendarDate(for: solarDate(2024, 2, 23), calendar: .hebrew, language: .english)
        #expect(adar1?.day == "14")
        #expect(adar1?.sub == "Adar I")
        // Common year: 2025-03-01 is 1 Adar 5785 (Purim is Mar 14).
        let adar = subCalendarDate(for: solarDate(2025, 3, 1), calendar: .hebrew, language: .english)
        #expect(adar?.day == "1")
        #expect(adar?.sub == "Adar")
        // Purim 2024-03-24 is 14 Adar II 5784.
        let adar2 = subCalendarDate(for: solarDate(2024, 3, 24), calendar: .hebrew, language: .english)
        #expect(adar2?.day == "14")
        #expect(adar2?.sub == "Adar II")
    }

    @Test func islamicRamadan() {
        // 2026-03-01 falls inside Ramadan 1447 (public holiday fact); only the
        // month is asserted because civil vs observed boundaries vary by a day.
        let date = subCalendarDate(for: solarDate(2026, 3, 1), calendar: .islamic, language: .english)
        #expect(date?.sub == "Ramadan")
        #expect(date?.accessibleLabel.contains("1447") == true)
        #expect(date?.yearLabel == "1447")
        #expect(date?.yearElement == nil)
    }

    @Test func buddhistYear() {
        let date = subCalendarDate(for: solarDate(2026, 2, 17), calendar: .buddhist, language: .vietnamese)
        #expect(date?.day == "17")
        #expect(date?.sub == "2")
        #expect(date?.accessibleLabel.contains("2569") == true)
        #expect(date?.yearLabel == "2569")
        #expect(date?.yearElement == nil)
    }

    @Test func zodiacAnimalsResolve() {
        // Quý Mão 2023: both calendars use the rabbit (public CNY fact).
        let maoVI = subCalendarDate(for: solarDate(2023, 3, 15), calendar: .vietnamese, language: .vietnamese)
        let maoZH = subCalendarDate(for: solarDate(2023, 3, 15), calendar: .chinese, language: .vietnamese)
        #expect(maoVI?.yearAnimal == .rabbit)
        #expect(maoZH?.yearAnimal == .rabbit)
        // Tân Sửu 2021: one bovine art serves both calendars.
        let suuVI = subCalendarDate(for: solarDate(2021, 3, 15), calendar: .vietnamese, language: .vietnamese)
        let suuZH = subCalendarDate(for: solarDate(2021, 3, 15), calendar: .chinese, language: .vietnamese)
        #expect(suuVI?.yearAnimal == .ox)
        #expect(suuZH?.yearAnimal == .ox)
        // Numbered years carry no animal.
        let hebrew = subCalendarDate(for: solarDate(2026, 9, 21), calendar: .hebrew, language: .english)
        #expect(hebrew?.yearAnimal == nil)
    }

    @Test func zodiacArtworkShipsForKnownAnimals() {
        // Every animal must have a decodable PNG.
        let here = URL(fileURLWithPath: #filePath)
        let dir = here
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Zodiac")
        for animal in ZodiacAnimal.allCases {
            let url = dir.appendingPathComponent("\(animal.assetName).png")
            #expect(FileManager.default.fileExists(atPath: url.path), "missing \(animal.assetName).png")
            #expect(NSImage(contentsOf: url) != nil, "undecodable \(animal.assetName).png")
        }
    }

    @Test func yearElementsCoverAllFive() {
        installVietnamesePackForTests()
        // Mid-March dates sit safely inside their lunar years (public CNY facts).
        let cases: [(Date, String, YearElement)] = [
            (solarDate(2024, 3, 15), "Giáp Thìn", .wood),
            (solarDate(2026, 3, 15), "Bính Ngọ", .fire),
            (solarDate(2019, 3, 15), "Kỷ Hợi", .earth),
            (solarDate(2020, 3, 15), "Canh Tý", .metal),
            (solarDate(2022, 3, 15), "Nhâm Dần", .water),
        ]
        for (date, name, element) in cases {
            let lunar = subCalendarDate(for: date, calendar: .vietnamese, language: .vietnamese)
            #expect(lunar?.yearLabel == name)
            #expect(lunar?.yearElement == element)
        }
    }
}

// MARK: - Health quotes

@Suite struct HealthQuoteTests {
    @Test func exactly365Quotes() {
        #expect(healthQuotes.count == 365)
    }

    @Test func quotesFilledShortAndUnique() {
        installVietnamesePackForTests()
        var seenVI = Set<String>()
        var seenEN = Set<String>()
        for quote in healthQuotes {
            let vi = quote.text(in: .vietnamese)
            #expect(!quote.emoji.isEmpty && !vi.isEmpty && !quote.en.isEmpty)
            #expect(vi.count <= 160)
            #expect(quote.en.count <= 160)
            seenVI.insert(vi)
            seenEN.insert(quote.en)
        }
        #expect(seenVI.count == healthQuotes.count)
        #expect(seenEN.count == healthQuotes.count)
    }

    @Test func randomPicksStayInsideTheBundle() {
        // Flash quotes are pre-picked with randomElement(); every pick must
        // be a member, and 200 picks must not collapse to one quote.
        let picked = (0..<200).compactMap { _ in healthQuotes.randomElement() }
        #expect(picked.count == 200)
        #expect(Set(picked).count > 1)
    }
}

// MARK: - Language packs

@Suite struct LanguagePackTests {
    /// Every non-quote key the code looks up. Update alongside Strings: a key
    /// added in code without a pack entry silently renders English.
    static let requiredKeys = [
        "autoPausedNote",
        "backButton",
        "autoSection",
        "aboutButton",
        "aboutMadeBy",
        "aboutPanelTitle",
        "breakOverTitle",
        "breaksLine.other",
        "buddhist.suffix",
        "calendarLabel",
        "calendarName.buddhist",
        "calendarName.chinese",
        "calendarName.hebrew",
        "calendarName.islamic",
        "calendarName.off",
        "calendarName.vietnamese",
        "chartDay",
        "chartHour",
        "chartRest",
        "chartSitting",
        "chartStanding",
        "checkUpdatesAvailable",
        "checkUpdatesButton",
        "checkUpdatesChecking",
        "checkUpdatesCurrent",
        "checkUpdatesFailed",
        "clearAllButton",
        "clearAllDialog",
        "dataSection",
        "daySitting",
        "dayStanding",
        "deleteAllButton",
        "deleteButton",
        "dismissHint",
        "displaySection",
        "downloadFailed",
        "flashToggle",
        "footerNote",
        "goalBody",
        "goalOff",
        "goalOn",
        "goalProgress",
        "goalSection",
        "goalTitle",
        "idleTitle.other",
        "keepButton",
        "langDownload",
        "langDownloaded",
        "langDownloading",
        "langNotDownloaded",
        "languageLabel",
        "loginError",
        "loginToggle",
        "longMinutes",
        "lunar.label",
        "lunar.leapSuffix",
        "lunar.leapWord",
        "modeLabel",
        "moveMinutes",
        "notifySection",
        "openSystemButton",
        "pauseButton",
        "permissionOff",
        "permissionOn",
        "permissionRow",
        "phaseShort.paused",
        "phaseShort.sitting",
        "phaseShort.standing",
        "phaseTitle.paused",
        "phaseTitle.sitting",
        "phaseTitle.standing",
        "quitButton",
        "quoteToggle",
        "reminderBody",
        "reportBugButton",
        "requestButton",
        "resetTodayButton",
        "resetTodayDialog",
        "resumeButton",
        "resumeToggle",
        "revealButton",
        "sessionSection",
        "sessionTitle.focus",
        "sessionTitle.longBreak",
        "sessionTitle.move",
        "sessionTitle.shortBreak",
        "sessionTitle.work",
        "settingsButton",
        "settingsPanelTitle",
        "shortMinutes",
        "skipButton",
        "soundToggle",
        "startPausedToggle",
        "statsButton",
        "statsDailyAverage",
        "statsDay",
        "statsNoActivity",
        "statsPanelTitle",
        "statsWeek",
        "statusPickerLabel",
        "supportSection",
        "systemSection",
        "todayLabel",
        "todaySection",
        "totalLine",
        "unit.hour",
        "unit.minute",
        "unit.second",
        "viewReleaseButton",
        "weekTitle",
        "workEndTitle",
        "workMinutes",
        "yAxisHours",
    ]

    static func checkedInPack() -> LanguagePack {
        let here = URL(fileURLWithPath: #filePath)
        let packURL = here
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/LanguagePacks/vi.json")
        let data = try! Data(contentsOf: packURL)
        return try! JSONDecoder().decode(LanguagePack.self, from: data)
    }

    @Test func packFileIsValidAndComplete() {
        let pack = Self.checkedInPack()
        #expect(pack.version >= 1)
        let keys = Set(pack.strings.keys)
        for key in Self.requiredKeys {
            #expect(keys.contains(key), "pack missing \(key)")
        }
        // One Vietnamese text per quote, in order; no extras, no gaps.
        #expect(pack.strings.keys.filter { $0.hasPrefix("quote.") }.count == healthQuotes.count)
        for i in 0..<healthQuotes.count {
            #expect(pack.strings["quote.\(i)"] != nil, "pack missing quote.\(i)")
        }
        #expect(pack.strings.count == Self.requiredKeys.count + healthQuotes.count)
    }

    @Test func vietnameseStringsResolveThroughPack() {
        installVietnamesePackForTests()
        let strings = Strings(.vietnamese)
        #expect(strings.language == .vietnamese)
        #expect(strings.pauseButton == "Tạm nghỉ")
        #expect(strings.settingsButton == "Cài đặt")
        #expect(strings.goalProgress("1 giờ") == "Mục tiêu đứng 1 giờ")
        #expect(strings.breaksLine(count: 1, longest: "5 phút") == "Đứng dậy 1 lần • Ngồi lâu nhất 5 phút")
        #expect(strings.breaksLine(count: 3, longest: "5 phút") == "Đứng dậy 3 lần • Ngồi lâu nhất 5 phút")
        #expect(strings.idleTitle(minutes: 1) == "Tự tạm nghỉ sau 1 phút không dùng máy")
        #expect(strings.footerNote(version: "1.0") == "SittingTime 1.0 • Dữ liệu chỉ nằm trên máy này, không tài khoản, không theo dõi.")
        #expect(strings.calendarName(.vietnamese) == "Âm lịch (Việt)")
        #expect(strings.sessionTitle(kind: .work, mode: .pomodoro, focusIndex: 2) == "Tập trung 2/4")
        #expect(formatDuration(300, language: .vietnamese) == "5 phút")
        #expect(healthQuotes[0].text(in: .vietnamese) == Self.checkedInPack().strings["quote.0"])
    }

    @Test func missingPackFallsBackToEnglish() {
        // Pure overloads: no global state, safe under parallel tests.
        #expect(LanguagePacks.resolve(.vietnamese, packInstalled: false) == .english)
        #expect(LanguagePacks.resolve(.vietnamese, packInstalled: true) == .vietnamese)
        #expect(LanguagePacks.resolve(.english, packInstalled: false) == .english)
        #expect(LanguagePacks.string("pauseButton", english: "Pause", language: .vietnamese, pack: nil) == "Pause")
        let thin = LanguagePack(version: 1, strings: ["pauseButton": "Tạm nghỉ"])
        #expect(LanguagePacks.string("pauseButton", english: "Pause", language: .vietnamese, pack: thin) == "Tạm nghỉ")
        #expect(LanguagePacks.string("skipButton", english: "Skip", language: .vietnamese, pack: thin) == "Skip")
        #expect(LanguagePacks.string("pauseButton", english: "Pause", language: .english, pack: thin) == "Pause")
    }

    @Test func formatFillsPlaceholders() {
        #expect(LanguagePacks.format("A {x} B {y}", ["x": "1"]) == "A 1 B {y}")
        #expect(LanguagePacks.format("No placeholders", [:]) == "No placeholders")
    }

    @Test func englishIsTheDefault() {
        installVietnamesePackForTests()
        #expect(AppSettings().language == .english)
        #expect(Strings(.english).pauseButton == "Pause")
        // Resolved English stays English even with the pack installed.
        #expect(Strings(.english).language == .english)
    }
}

// MARK: - Update checker (pure, no actor needed)

@Suite struct UpdateCheckerTests {
    @Test func parsesLatestMacOSRelease() {
        let json = """
            [{"tag_name":"macos-v1.1.3"},{"tag_name":"win-v2.0.0"},{"tag_name":"macos-v1.2.0"},{"tag_name":"macos-v1.10.0"}]
            """
        #expect(UpdateChecker.latestVersion(in: Data(json.utf8)) == "1.10.0")
    }

    @Test func ignoresNonMacOSTagsAndGarbage() {
        #expect(UpdateChecker.latestVersion(in: Data(#"[{"tag_name":"win-v2.0.0"}]"#.utf8)) == nil)
        #expect(UpdateChecker.latestVersion(in: Data("not json".utf8)) == nil)
        #expect(UpdateChecker.latestVersion(in: Data("[]".utf8)) == nil)
        #expect(UpdateChecker.latestVersion(in: Data(#"[{"tag_name":"macos-vbeta"}]"#.utf8)) == nil)
    }

    @Test func comparesVersionsNumerically() {
        #expect(UpdateChecker.compareVersions("1.1.10", "1.1.3") == .orderedDescending)
        #expect(UpdateChecker.compareVersions("1.1.3", "1.1.10") == .orderedAscending)
        #expect(UpdateChecker.compareVersions("1.2", "1.2.0") == .orderedSame)
        #expect(UpdateChecker.compareVersions("2.0", "1.9.9") == .orderedDescending)
        #expect(UpdateChecker.releasePageURL(version: "1.2.0").absoluteString.hasSuffix("/releases/tag/macos-v1.2.0"))
    }
}
