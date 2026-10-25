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

/// `"2 giờ 15 phút"`, `"45 phút"`, `"30 giây"`. Used for totals and stats.
public func formatDuration(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds.rounded()))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    if hours > 0, minutes > 0 {
        return "\(hours) giờ \(minutes) phút"
    }
    if hours > 0 {
        return "\(hours) giờ"
    }
    if minutes > 0 {
        return "\(minutes) phút"
    }
    return "\(total) giây"
}

/// `"45 phút"`-style compact form for notifications: `"1 giờ 5 phút"` / `"45 phút"`.
public func formatShortDuration(_ seconds: TimeInterval) -> String {
    formatDuration(seconds)
}

/// Day key `"yyyy-MM-dd"` in the current time zone.
public func dateKey(for date: Date, calendar: Calendar = .current) -> String {
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
}

/// Short weekday label in Vietnamese: `"T2"` … `"CN"`.
public func weekdayLabel(for date: Date, calendar: Calendar = .current) -> String {
    var cal = calendar
    cal.locale = Locale(identifier: "vi_VN")
    let weekday = cal.component(.weekday, from: date) // 1 = Sunday
    switch weekday {
    case 1: return "CN"
    default: return "T\(weekday)"
    }
}
