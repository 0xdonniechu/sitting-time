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

// MARK: - Store behaviour

@Suite struct SittingStoreTests {
    @Test @MainActor func startsSittingByDefault() {
        let (store, _, _, _) = makeStore()
        #expect(store.phase == .sitting)
        #expect(store.continuousSit >= 0)
    }

    @Test @MainActor func startsPausedWhenConfigured() {
        var settings = AppSettings()
        settings.startPaused = true
        let (store, _, _, _) = makeStore(settings: settings)
        #expect(store.phase == .paused)
        #expect(store.autoPaused == false)
    }

    @Test @MainActor func phaseChangeAccumulatesTime() {
        let (store, clock, _, _) = makeStore()
        clock.advance(3600)
        store.setPhase(.standing)
        clock.advance(600)
        store.setPhase(.sitting)
        let today = store.liveToday()
        #expect(isNear(today.sittingSeconds, 3600))
        #expect(isNear(today.standingSeconds, 600))
        #expect(today.breakCount == 0)
    }

    @Test @MainActor func pauseCountsBreaksAndResumes() {
        let (store, clock, _, _) = makeStore()
        run(store, clock, seconds: 60)
        store.togglePause()
        #expect(store.phase == .paused)
        run(store, clock, seconds: 300)
        store.togglePause()
        #expect(store.phase == .sitting)
        store.setPhase(.paused)
        let today = store.liveToday()
        #expect(today.breakCount == 2)
        #expect(isNear(today.pausedSeconds, 300))
        #expect(isNear(today.sittingSeconds, 60))
    }

    @Test @MainActor func checkpointKeepsDisplayElapsedContinuous() {
        let (store, clock, _, _) = makeStore()
        run(store, clock, seconds: 35)
        // A checkpoint fired at tick 30: the menu bar timer must not jump back.
        #expect(isNear(store.openElapsed, 35))
        // ... and the checkpointed seconds must not be counted twice.
        #expect(isNear(store.todayRecord.sittingSeconds, 30))
        #expect(isNear(store.liveToday().sittingSeconds, 35))
    }

    @Test @MainActor func phaseChangeResetsDisplayElapsed() {
        let (store, clock, _, _) = makeStore()
        run(store, clock, seconds: 40)
        store.setPhase(.standing)
        run(store, clock, seconds: 5)
        #expect(isNear(store.openElapsed, 5))
        #expect(isNear(store.liveToday().standingSeconds, 5))
        #expect(isNear(store.liveToday().sittingSeconds, 40))
    }

    @Test @MainActor func sitReminderFiresOnEachInterval() {
        var settings = AppSettings()
        settings.sitReminderMinutes = 45
        settings.standGoalMinutes = 0
        let (store, clock, _, spy) = makeStore(settings: settings)
        run(store, clock, seconds: 30 * 60)
        #expect(spy.reminderCount == 0)
        run(store, clock, seconds: 20 * 60)
        #expect(spy.reminderCount == 1)
        run(store, clock, seconds: 45 * 60)
        #expect(spy.reminderCount == 2)
        // Leaving the chair resets the continuous stretch.
        store.setPhase(.standing)
        store.setPhase(.sitting)
        run(store, clock, seconds: 44 * 60)
        #expect(spy.reminderCount == 2)
        run(store, clock, seconds: 2 * 60)
        #expect(spy.reminderCount == 3)
    }

    @Test @MainActor func reminderDisabledWhenZero() {
        var settings = AppSettings()
        settings.sitReminderMinutes = 0
        settings.standGoalMinutes = 0
        let (store, clock, _, spy) = makeStore(settings: settings)
        run(store, clock, seconds: 2 * 3600)
        #expect(spy.reminderCount == 0)
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
        #expect(store.phase == .paused)
        #expect(store.autoPaused == true)
        idleBox.seconds = 0
        store.tick()
        #expect(store.phase == .sitting)
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
        #expect(store.phase == .paused)
    }

    @Test @MainActor func noAutoResumeWhenDisabled() {
        var settings = AppSettings()
        settings.idlePauseMinutes = 5
        settings.autoResumeOnReturn = false
        let (store, clock, idleBox, _) = makeStore(settings: settings)
        run(store, clock, seconds: 10)
        idleBox.seconds = 400
        store.tick()
        #expect(store.phase == .paused)
        idleBox.seconds = 0
        store.tick()
        #expect(store.phase == .paused)
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
        #expect(store.phase == .paused)
        #expect(store.autoPaused == true)
        let today = store.liveToday()
        #expect(isNear(today.sittingSeconds, 60, tolerance: 5))
        #expect(today.sittingSeconds < 3600)
        // Back at the Mac: resumes sitting, sleep gap stays out of the stats.
        idleBox.seconds = 0
        store.tick()
        #expect(store.phase == .sitting)
        #expect(store.liveToday().sittingSeconds < 3600)
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
        #expect(store.phase == .sitting)
        // Uninterrupted stretch survives midnight.
        #expect(store.continuousSit > 1100)
        let week = store.weekData()
        #expect(week.count == 7)
        #expect(week.last?.label == "Hôm nay")
        let yesterday = week[week.count - 2]
        #expect(isNear(yesterday.sittingSeconds, 600, tolerance: 5))
        #expect(isNear(store.liveToday().sittingSeconds, 600, tolerance: 5))
    }

    @Test @MainActor func longestSitTracksLongestStretch() {
        var settings = AppSettings()
        settings.standGoalMinutes = 0
        let (store, clock, _, _) = makeStore(settings: settings)
        run(store, clock, seconds: 20 * 60)
        store.setPhase(.standing)
        run(store, clock, seconds: 60)
        store.setPhase(.sitting)
        run(store, clock, seconds: 50 * 60)
        #expect(isNear(store.liveToday().longestSitSeconds, 3000, tolerance: 5))
    }

    @Test @MainActor func standGoalNotifiesOncePerDay() {
        var settings = AppSettings()
        settings.standGoalMinutes = 60
        settings.sitReminderMinutes = 0
        let (store, clock, _, spy) = makeStore(settings: settings)
        store.setPhase(.standing)
        run(store, clock, seconds: 61 * 60)
        #expect(spy.reminderCount == 1)
        run(store, clock, seconds: 10 * 60)
        #expect(spy.reminderCount == 1)
    }

    @Test @MainActor func resetTodayClearsAndRestarts() {
        let (store, clock, _, _) = makeStore()
        run(store, clock, seconds: 60)
        store.resetToday()
        let today = store.liveToday()
        #expect(today.sittingSeconds == 0)
        #expect(today.breakCount == 0)
        #expect(today.longestSitSeconds == 0)
        #expect(store.phase == .sitting)
        #expect(store.continuousSit < 5)
    }

    @Test @MainActor func clearHistoryWipesEverything() {
        let (store, clock, _, _) = makeStore()
        run(store, clock, seconds: 60)
        store.setPhase(.standing)
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

    @Test @MainActor func settingsWriteAfterInitClampsWithoutRecursion() {
        // Regression test: `settings.clamp()` inside didSet re-entered didSet
        // through the @Observable wrapper forever (stack overflow on launch).
        let (store, _, _, _) = makeStore()
        store.settings = AppSettings(sitReminderMinutes: 999, idlePauseMinutes: 0, standGoalMinutes: -5)
        #expect(store.settings.sitReminderMinutes == 240)
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

    @Test func settingsClampToSaneRanges() {
        var settings = AppSettings(sitReminderMinutes: 999, idlePauseMinutes: 0, standGoalMinutes: -5)
        settings.clamp()
        #expect(settings.sitReminderMinutes == 240)
        #expect(settings.idlePauseMinutes == 1)
        #expect(settings.standGoalMinutes == 0)
    }

    @Test func elapsedFormatsLikeAClock() {
        #expect(formatElapsed(3661) == "1:01:01")
        #expect(formatElapsed(61) == "1:01")
        #expect(formatElapsed(5) == "0:05")
        #expect(formatElapsed(0) == "0:00")
    }

    @Test func durationFormatsInVietnamese() {
        #expect(formatDuration(3600) == "1 giờ")
        #expect(formatDuration(5400) == "1 giờ 30 phút")
        #expect(formatDuration(300) == "5 phút")
        #expect(formatDuration(30) == "30 giây")
    }

    @Test func sitPhaseHasVietnameseTitles() {
        #expect(SitPhase.sitting.shortTitle == "Ngồi")
        #expect(SitPhase.standing.shortTitle == "Đứng")
        #expect(SitPhase.paused.shortTitle == "Nghỉ")
        #expect(SitPhase.allCases.count == 3)
    }
}
