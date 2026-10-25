import Foundation

/// One secondary-calendar date for the popover tile: a large day number, a
/// short month line, and a full spoken/tooltip label. Pure Foundation, no UI.
public struct SubCalendarDate: Sendable, Equatable {
    public let day: String
    public let sub: String
    public let accessibleLabel: String
    public let isLeapMonth: Bool

    public init(day: String, sub: String, accessibleLabel: String, isLeapMonth: Bool) {
        self.day = day
        self.sub = sub
        self.accessibleLabel = accessibleLabel
        self.isLeapMonth = isLeapMonth
    }
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

/// Stem-branch year from the Chinese cycle year (1–60, where 1 is Giáp Tý).
/// Foundation's `.chinese` calendar reports the cycle year, not a Gregorian number.
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
    let sub: String
    let label: String
    let solarFull = fullSolarString(for: solar, language: language)
    switch language {
    case .vietnamese:
        sub = leap ? "\(month)N" : "\(month)"
        label = "\(solarFull); âm lịch: ngày \(day) tháng \(month)\(leap ? " nhuận" : ""), năm \(canChi(cycleYear: year, language: language))"
    case .english:
        sub = leap ? "\(month)L" : "\(month)"
        label = "\(solarFull); lunar: day \(day), month \(month)\(leap ? " (leap)" : ""), \(canChi(cycleYear: year, language: language)) year"
    }
    return SubCalendarDate(day: "\(day)", sub: sub, accessibleLabel: label, isLeapMonth: leap)
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
    let solarFull = fullSolarString(for: date, language: language)
    let label: String
    switch language {
    case .vietnamese:
        label = "\(solarFull); \(name) \(day), \(year)"
    case .english:
        label = "\(solarFull); \(name) \(day), \(year)"
    }
    return SubCalendarDate(day: "\(day)", sub: name, accessibleLabel: label, isLeapMonth: leap)
}

/// Hebrew leap years in the 19-year Metonic cycle.
private func isHebrewLeapYear(_ year: Int) -> Bool {
    [0, 3, 6, 8, 11, 14, 17].contains(year % 19)
}

// MARK: - Buddhist

private func buddhistDate(for date: Date, language: AppLanguage) -> SubCalendarDate? {
    let calendar = Calendar(identifier: .buddhist)
    let parts = calendar.dateComponents([.month, .day], from: date)
    guard let month = parts.month, let day = parts.day else { return nil }
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.dateStyle = .long
    formatter.timeStyle = .none
    let label: String
    switch language {
    case .vietnamese:
        formatter.locale = Locale(identifier: "vi_VN")
        label = "\(formatter.string(from: date)) (Phật lịch)"
    case .english:
        formatter.locale = Locale(identifier: "en_US")
        label = "\(formatter.string(from: date)) (Buddhist)"
    }
    return SubCalendarDate(day: "\(day)", sub: "\(month)", accessibleLabel: label, isLeapMonth: false)
}

// MARK: - Solar label

private func fullSolarString(for date: Date, language: AppLanguage) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .full
    formatter.timeStyle = .none
    switch language {
    case .vietnamese:
        formatter.locale = Locale(identifier: "vi_VN")
    case .english:
        formatter.locale = Locale(identifier: "en_US")
    }
    return formatter.string(from: date)
}
