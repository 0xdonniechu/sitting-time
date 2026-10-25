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
        #expect(SitPhase.sitting.shortTitle(in: .vietnamese) == "Ngồi")
        #expect(SitPhase.standing.shortTitle(in: .vietnamese) == "Đứng")
        #expect(SitPhase.paused.shortTitle(in: .vietnamese) == "Nghỉ")
        #expect(SitPhase.allCases.count == 3)
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
        #expect(Strings(.english).breaksLine(count: 1, longest: "5 minutes") == "1 break • Longest sit 5 minutes")
    }

    @Test func weekdayLabelsInBothLanguages() {
        // 2026-10-25 is a Sunday; 2026-10-26 a Monday (public calendar facts).
        let sunday = solarDate(2026, 10, 25)
        let monday = solarDate(2026, 10, 26)
        #expect(weekdayLabel(for: sunday) == "CN")
        #expect(weekdayLabel(for: monday) == "T2")
        #expect(weekdayLabel(for: sunday, language: .english) == "Sun")
        #expect(weekdayLabel(for: monday, language: .english) == "Mon")
    }

    @Test func oldSettingsWithoutNewKeysLoadWithDefaults() {
        let json = #"{"sitReminderMinutes":45,"idlePauseMinutes":5,"standGoalMinutes":60,"autoResumeOnReturn":true,"startPaused":false,"reminderSound":true,"launchAtLogin":false}"#
        let decoded = try? JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        #expect(decoded?.language == .vietnamese)
        #expect(decoded?.subCalendar == .vietnamese)
        #expect(decoded?.fullScreenFlash == true)
        #expect(decoded?.quoteOnFlash == true)
        #expect(decoded?.sitReminderMinutes == 45)
    }

    @Test @MainActor func englishWeekLabelsFollowSettings() {
        var settings = AppSettings()
        settings.language = .english
        let (store, clock, _, _) = makeStore(settings: settings)
        run(store, clock, seconds: 5)
        let week = store.weekData()
        #expect(week.last?.label == "Today")
    }

    @Test @MainActor func englishReminderTextFollowsSettings() {
        var settings = AppSettings()
        settings.language = .english
        settings.sitReminderMinutes = 1
        settings.standGoalMinutes = 0
        let (store, clock, _, spy) = makeStore(settings: settings)
        run(store, clock, seconds: 65)
        #expect(spy.reminderCount == 1)
        #expect(spy.posts.first?.title.contains("time to stand") == true)
        #expect(spy.posts.first?.body.contains("Today:") == true)
    }

    @Test @MainActor func flashHookFiresWithRandomQuote() {
        var settings = AppSettings()
        settings.sitReminderMinutes = 1
        settings.standGoalMinutes = 0
        let (store, clock, _, spy) = makeStore(settings: settings)
        var flashed: [(String, String, HealthQuote?)] = []
        store.onSitReminder = { flashed.append(($0, $1, $2)) }
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
        var off = AppSettings()
        off.sitReminderMinutes = 1
        off.standGoalMinutes = 0
        off.fullScreenFlash = false
        let (storeA, clockA, _, spyA) = makeStore(settings: off)
        var countA = 0
        storeA.onSitReminder = { _, _, _ in countA += 1 }
        run(storeA, clockA, seconds: 65)
        #expect(countA == 0)
        #expect(spyA.posts.first?.sound == true)
        // Quote off: hook fires with a nil quote, banner silent.
        var noQuote = AppSettings()
        noQuote.sitReminderMinutes = 1
        noQuote.standGoalMinutes = 0
        noQuote.quoteOnFlash = false
        let (storeB, clockB, _, spyB) = makeStore(settings: noQuote)
        var flashedB: [(String, String, HealthQuote?)] = []
        storeB.onSitReminder = { flashedB.append(($0, $1, $2)) }
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
        // Tết Bính Ngọ: 2026-02-17 is lunar 1/1 (public holiday fact).
        let date = solarDate(2026, 2, 17)
        for type in [SubCalendar.vietnamese, SubCalendar.chinese] {
            let lunar = subCalendarDate(for: date, calendar: type, language: .vietnamese)
            #expect(lunar?.day == "1")
            #expect(lunar?.sub == "1")
            #expect(lunar?.isLeapMonth == false)
            #expect(lunar?.accessibleLabel.contains("Bính Ngọ") == true)
        }
        let en = subCalendarDate(for: date, calendar: .vietnamese, language: .english)
        #expect(en?.accessibleLabel.contains("Binh Ngo") == true)
    }

    @Test func leapMonthIsFlagged() {
        // 2025 has a leap 6th lunar month (Jul 25 – Aug 22); Aug 1 is inside it.
        let lunar = subCalendarDate(for: solarDate(2025, 8, 1), calendar: .vietnamese, language: .vietnamese)
        #expect(lunar?.isLeapMonth == true)
        #expect(lunar?.sub == "6N")
        #expect(lunar?.accessibleLabel.contains("nhuận") == true)
    }

    @Test func hebrewHolidays() {
        // Yom Kippur 2026-09-21 is 10 Tishri 5787 (public holiday fact).
        let kippur = subCalendarDate(for: solarDate(2026, 9, 21), calendar: .hebrew, language: .vietnamese)
        #expect(kippur?.day == "10")
        #expect(kippur?.sub == "Tishri")
        #expect(kippur?.accessibleLabel.contains("5787") == true)
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
    }

    @Test func buddhistYear() {
        let date = subCalendarDate(for: solarDate(2026, 2, 17), calendar: .buddhist, language: .vietnamese)
        #expect(date?.day == "17")
        #expect(date?.sub == "2")
        #expect(date?.accessibleLabel.contains("2569") == true)
    }
}

// MARK: - Health quotes

@Suite struct HealthQuoteTests {
    @Test func exactly365Quotes() {
        #expect(healthQuotes.count == 365)
    }

    @Test func quotesFilledShortAndUnique() {
        var seenVI = Set<String>()
        var seenEN = Set<String>()
        for quote in healthQuotes {
            #expect(!quote.emoji.isEmpty && !quote.vi.isEmpty && !quote.en.isEmpty)
            #expect(quote.vi.count <= 160)
            #expect(quote.en.count <= 160)
            seenVI.insert(quote.vi)
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
