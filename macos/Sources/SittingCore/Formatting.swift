import Foundation

/// `"1:02:03"` for over an hour, `"02:03"` below an hour. Used for the live timer.
public func formatElapsed(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds.rounded()))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let secs = total % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, secs)
    }
    return String(format: "%d:%02d", minutes, secs)
}

/// `"2 giờ 15 phút"`, `"45 phút"`, `"30 giây"` (or the English equivalents
/// with proper plurals). Used for totals and stats.
public func formatDuration(_ seconds: TimeInterval, language: AppLanguage = .english) -> String {
    let total = max(0, Int(seconds.rounded()))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    switch LanguagePacks.resolve(language) {
    case .vietnamese:
        let hour = LanguagePacks.string("unit.hour", english: "hour", for: .vietnamese)
        let minute = LanguagePacks.string("unit.minute", english: "minute", for: .vietnamese)
        let second = LanguagePacks.string("unit.second", english: "second", for: .vietnamese)
        if hours > 0, minutes > 0 {
            return "\(hours) \(hour) \(minutes) \(minute)"
        }
        if hours > 0 {
            return "\(hours) \(hour)"
        }
        if minutes > 0 {
            return "\(minutes) \(minute)"
        }
        return "\(total) \(second)"
    case .english:
        func unit(_ value: Int, _ singular: String) -> String {
            value == 1 ? "1 \(singular)" : "\(value) \(singular)s"
        }
        if hours > 0, minutes > 0 {
            return "\(unit(hours, "hour")) \(unit(minutes, "minute"))"
        }
        if hours > 0 {
            return unit(hours, "hour")
        }
        if minutes > 0 {
            return unit(minutes, "minute")
        }
        return unit(total, "second")
    }
}

/// Compact form for notifications; same units as `formatDuration`.
public func formatShortDuration(_ seconds: TimeInterval, language: AppLanguage = .english) -> String {
    formatDuration(seconds, language: language)
}

/// Day key `"yyyy-MM-dd"` in the current time zone.
public func dateKey(for date: Date, calendar: Calendar = .current) -> String {
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
}

/// Short weekday label: `"T2"` … `"CN"` in Vietnamese, `"Sun"` … in English.
public func weekdayLabel(for date: Date, calendar: Calendar = .current, language: AppLanguage = .english) -> String {
    switch LanguagePacks.resolve(language) {
    case .vietnamese:
        var cal = calendar
        cal.locale = Locale(identifier: "vi_VN")
        let weekday = cal.component(.weekday, from: date) // 1 = Sunday
        switch weekday {
        case 1: return "CN"
        default: return "T\(weekday)"
        }
    case .english:
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}
