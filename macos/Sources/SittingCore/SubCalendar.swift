import Foundation

/// One secondary-calendar date for the popover tile: a large day number, a
/// short month line, the year line (full Can Chi name or plain year number),
/// and a full spoken/tooltip label. Pure Foundation, no UI.
public struct SubCalendarDate: Sendable, Equatable {
    public let day: String
    public let sub: String
    public let yearLabel: String
    public let yearElement: YearElement?
    /// Zodiac animal for lunar years; nil for numbered years.
    public let yearAnimal: ZodiacAnimal?
    public let accessibleLabel: String
    public let isLeapMonth: Bool

    public init(day: String, sub: String, yearLabel: String, yearElement: YearElement?, yearAnimal: ZodiacAnimal?, accessibleLabel: String, isLeapMonth: Bool) {
        self.day = day
        self.sub = sub
        self.yearLabel = yearLabel
        self.yearElement = yearElement
        self.yearAnimal = yearAnimal
        self.accessibleLabel = accessibleLabel
        self.isLeapMonth = isLeapMonth
    }
}

/// Five-element nature of a lunar year, from its stem: Giáp/Ất wood,
/// Bính/Đinh fire (Bính Ngọ 2026 renders its horse red), Mậu/Kỷ earth,
/// Canh/Tân metal, Nhâm/Quý water. Numbered years (Hebrew, Islamic,
/// Buddhist) carry no element.
public enum YearElement: String, Sendable {
    case wood, fire, earth, metal, water
}

/// Computes `type`'s date for `date`, or nil when the tile is off.
/// The Vietnamese lunar calendar is the Chinese calendar in UTC+7, matching
/// the Tauri app's fixed-time-zone conversion; the Chinese one uses UTC+8.
public func subCalendarDate(for date: Date, calendar type: SubCalendar, language: AppLanguage) -> SubCalendarDate? {
    switch type {
    case .off:
        return nil
    case .vietnamese:
        return lunarDate(for: date, timeZone: TimeZone(identifier: "Asia/Ho_Chi_Minh") ?? TimeZone(secondsFromGMT: 7 * 3600)!, language: language, solar: date)
    case .chinese:
        return lunarDate(for: date, timeZone: TimeZone(identifier: "Asia/Shanghai") ?? TimeZone(secondsFromGMT: 8 * 3600)!, language: language, solar: date)
    case .hebrew:
        return namedMonthDate(for: date, identifier: .hebrew, language: language)
    case .islamic:
        return namedMonthDate(for: date, identifier: .islamicCivil, language: language)
    case .buddhist:
        return buddhistDate(for: date, language: language)
    }
}

// MARK: - Vietnamese / Chinese lunar

private let canChiStemsVI = ["Giáp", "Ất", "Bính", "Đinh", "Mậu", "Kỷ", "Canh", "Tân", "Nhâm", "Quý"]
private let canChiBranchesVI = ["Tý", "Sửu", "Dần", "Mão", "Thìn", "Tỵ", "Ngọ", "Mùi", "Thân", "Dậu", "Tuất", "Hợi"]
private let canChiStemsEN = ["Giap", "At", "Binh", "Dinh", "Mau", "Ky", "Canh", "Tan", "Nham", "Quy"]
private let canChiBranchesEN = ["Ty", "Suu", "Dan", "Mao", "Thin", "Ty", "Ngo", "Mui", "Than", "Dau", "Tuat", "Hoi"]

/// Zodiac animal for the tile icon, from the lunar branch. Both calendars
/// use the rabbit for Mão.
public enum ZodiacAnimal: String, Sendable, CaseIterable {
    case rat, ox, tiger, rabbit, dragon, snake, horse, goat, monkey, rooster, dog, pig

    /// PNG file under Resources/Zodiac.
    public var assetName: String { rawValue }
}

/// Zodiac animal for the cycle year.
private func yearAnimal(cycleYear: Int) -> ZodiacAnimal {
    switch (cycleYear - 1) % 12 {
    case 0: return .rat
    case 1: return .ox
    case 2: return .tiger
    case 3: return .rabbit
    case 4: return .dragon
    case 5: return .snake
    case 6: return .horse
    case 7: return .goat
    case 8: return .monkey
    case 9: return .rooster
    case 10: return .dog
    default: return .pig
    }
}

/// Element from the stem: each pair of stems shares one element.
private func yearElement(cycleYear: Int) -> YearElement {
    switch (cycleYear - 1) % 10 / 2 {
    case 0: return .wood
    case 1: return .fire
    case 2: return .earth
    case 3: return .metal
    default: return .water
    }
}

/// Stem-branch year from the Chinese cycle year (1–60, where 1 is Giáp Tý).
/// Foundation's `.chinese` calendar reports the cycle year, not a Gregorian number.
/// These proper nouns stay in the binary (tiny, structural); only the sentence
/// around them comes from the language pack.
private func canChi(cycleYear: Int, language: AppLanguage) -> String {
    let stemIndex = (cycleYear - 1) % 10
    let branchIndex = (cycleYear - 1) % 12
    switch language {
    case .vietnamese:
        return "\(canChiStemsVI[stemIndex]) \(canChiBranchesVI[branchIndex])"
    case .english:
        return "\(canChiStemsEN[stemIndex]) \(canChiBranchesEN[branchIndex])"
    }
}

private func lunarDate(for date: Date, timeZone: TimeZone, language: AppLanguage, solar: Date) -> SubCalendarDate? {
    var calendar = Calendar(identifier: .chinese)
    calendar.timeZone = timeZone
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
    let leap = parts.isLeapMonth ?? false
    let lang = LanguagePacks.resolve(language)
    let solarFull = fullSolarString(for: solar, language: lang)
    let stemBranch = canChi(cycleYear: year, language: lang)
    let sub: String
    let label: String
    switch lang {
    case .vietnamese:
        let suffix = LanguagePacks.string("lunar.leapSuffix", english: "L", for: .vietnamese)
        let leapWord = leap ? LanguagePacks.string("lunar.leapWord", english: " (leap)", for: .vietnamese) : ""
        let template = LanguagePacks.string(
            "lunar.label",
            english: "{solar}; lunar: day {day}, month {month}{leap}, {year} year",
            for: .vietnamese
        )
        sub = leap ? "\(month)\(suffix)" : "\(month)"
        label = LanguagePacks.format(template, [
            "solar": solarFull, "day": "\(day)", "month": "\(month)",
            "leap": leapWord, "year": stemBranch,
        ])
    case .english:
        sub = leap ? "\(month)L" : "\(month)"
        label = "\(solarFull); lunar: day \(day), month \(month)\(leap ? " (leap)" : ""), \(stemBranch) year"
    }
    return SubCalendarDate(
        day: "\(day)", sub: sub,
        yearLabel: canChi(cycleYear: year, language: lang), yearElement: yearElement(cycleYear: year),
        yearAnimal: yearAnimal(cycleYear: year),
        accessibleLabel: label, isLeapMonth: leap
    )
}

// MARK: - Hebrew / Islamic (named months)

// Month names come from the calendar itself (always consistent with the month
// number by construction) in English; they are proper nouns in both languages.
private func namedMonthDate(for date: Date, identifier: Calendar.Identifier, language: AppLanguage) -> SubCalendarDate? {
    var calendar = Calendar(identifier: identifier)
    calendar.locale = Locale(identifier: "en_US")
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
    let symbols = calendar.standaloneMonthSymbols
    guard month >= 1, month <= symbols.count else { return nil }
    var name = symbols[month - 1]
    let leap = parts.isLeapMonth ?? false
    // In Hebrew leap years month 7 is Adar II, but the symbols array still
    // calls it "Adar" there; detect the leap year by the Metonic cycle.
    if identifier == .hebrew, month == 7, isHebrewLeapYear(year) {
        name = "Adar II"
    }
    let solarFull = fullSolarString(for: date, language: LanguagePacks.resolve(language))
    let label = "\(solarFull); \(name) \(day), \(year)"
    return SubCalendarDate(
        day: "\(day)", sub: name, yearLabel: "\(year)", yearElement: nil, yearAnimal: nil,
        accessibleLabel: label, isLeapMonth: leap
    )
}

/// Hebrew leap years in the 19-year Metonic cycle.
private func isHebrewLeapYear(_ year: Int) -> Bool {
    [0, 3, 6, 8, 11, 14, 17].contains(year % 19)
}

// MARK: - Buddhist

private func buddhistDate(for date: Date, language: AppLanguage) -> SubCalendarDate? {
    let calendar = Calendar(identifier: .buddhist)
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.dateStyle = .long
    formatter.timeStyle = .none
    let label: String
    switch LanguagePacks.resolve(language) {
    case .vietnamese:
        formatter.locale = Locale(identifier: "vi_VN")
        let suffix = LanguagePacks.string("buddhist.suffix", english: " (Buddhist)", for: .vietnamese)
        label = "\(formatter.string(from: date))\(suffix)"
    case .english:
        formatter.locale = Locale(identifier: "en_US")
        label = "\(formatter.string(from: date)) (Buddhist)"
    }
    return SubCalendarDate(
        day: "\(day)", sub: "\(month)", yearLabel: "\(year)", yearElement: nil, yearAnimal: nil,
        accessibleLabel: label, isLeapMonth: false
    )
}

// MARK: - ISO week + month labels

/// Solar labels for the popover tile: ISO 8601 week number, capitalised
/// English month abbreviation, and day of month (`"W44"`, `"OCT"`, `"26"`).
/// Computed from the civil date at noon so the values never depend on the
/// time of day.
public func solarLabels(for date: Date, calendar: Calendar = .current) -> (week: String, month: String, day: String) {
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    var iso = Calendar(identifier: .iso8601)
    iso.timeZone = calendar.timeZone
    let noon = iso.date(from: DateComponents(
        year: parts.year, month: parts.month, day: parts.day, hour: 12
    )) ?? date
    let week = iso.component(.weekOfYear, from: noon)
    let formatter = DateFormatter()
    formatter.calendar = iso
    formatter.locale = Locale(identifier: "en_US")
    formatter.dateFormat = "MMM"
    return ("W\(week)", formatter.string(from: noon).uppercased(), "\(iso.component(.day, from: noon))")
}

// MARK: - Solar label

private func fullSolarString(for date: Date, language: AppLanguage) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .full
    formatter.timeStyle = .none
    switch LanguagePacks.resolve(language) {
    case .vietnamese:
        formatter.locale = Locale(identifier: "vi_VN")
    case .english:
        formatter.locale = Locale(identifier: "en_US")
    }
    return formatter.string(from: date)
}
