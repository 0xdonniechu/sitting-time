import Foundation

/// Every user-visible string in one table, keyed by language. Views and
/// notifications read `Strings(store.settings.language)`; nothing is
/// hardcoded in Vietnamese anywhere else.
public struct Strings: Sendable {
    public let language: AppLanguage

    public init(_ language: AppLanguage) {
        self.language = language
    }

    private var vi: Bool { language == .vietnamese }

    // MARK: - Phases

    public func phaseShort(_ phase: SitPhase) -> String {
        switch (phase, language) {
        case (.sitting, .vietnamese): return "Ngồi"
        case (.sitting, .english): return "Sit"
        case (.standing, .vietnamese): return "Đứng"
        case (.standing, .english): return "Stand"
        case (.paused, .vietnamese): return "Nghỉ"
        case (.paused, .english): return "Break"
        }
    }

    public func phaseTitle(_ phase: SitPhase) -> String {
        switch (phase, language) {
        case (.sitting, .vietnamese): return "Đang ngồi"
        case (.sitting, .english): return "Sitting"
        case (.standing, .vietnamese): return "Đang đứng"
        case (.standing, .english): return "Standing"
        case (.paused, .vietnamese): return "Tạm nghỉ"
        case (.paused, .english): return "Paused"
        }
    }

    // MARK: - Popover

    public var autoPausedNote: String {
        vi ? "Tự tạm nghỉ vì không dùng máy — sẽ tiếp tục khi bạn quay lại."
            : "Auto-paused while you were away — resumes when you return."
    }

    public var statusPickerLabel: String { vi ? "Trạng thái" : "Status" }
    public var pauseButton: String { vi ? "Tạm nghỉ" : "Pause" }
    public var resumeButton: String { vi ? "Tiếp tục" : "Resume" }
    public var todaySection: String { vi ? "Hôm nay" : "Today" }
    public var todayLabel: String { vi ? "Hôm nay" : "Today" }

    public func goalProgress(_ goal: String) -> String {
        vi ? "Mục tiêu đứng \(goal)" : "Standing goal \(goal)"
    }

    public func breaksLine(count: Int, longest: String) -> String {
        if vi {
            return "Nghỉ \(count) lần • Ngồi lâu nhất \(longest)"
        }
        return count == 1
            ? "1 break • Longest sit \(longest)"
            : "\(count) breaks • Longest sit \(longest)"
    }

    public var statsButton: String { vi ? "Thống kê" : "Statistics" }
    public var settingsButton: String { vi ? "Cài đặt…" : "Settings…" }
    public var quitButton: String { vi ? "Thoát" : "Quit" }

    // MARK: - Stats window

    public var statsPanelTitle: String { vi ? "Thống kê 7 ngày" : "7-day statistics" }
    public var weekTitle: String { vi ? "7 ngày qua" : "Last 7 days" }

    public func totalLine(sitting: String, standing: String) -> String {
        vi ? "Ngồi \(sitting) • Đứng \(standing)" : "Sitting \(sitting) • Standing \(standing)"
    }

    public var chartDay: String { vi ? "Ngày" : "Day" }
    public var chartHour: String { vi ? "Giờ" : "Hours" }
    public var chartSitting: String { vi ? "Ngồi" : "Sitting" }
    public var chartStanding: String { vi ? "Đứng" : "Standing" }
    public var yAxisHours: String { vi ? "giờ" : "hours" }

    public func daySitting(_ duration: String) -> String {
        vi ? "Ngồi \(duration)" : "Sitting \(duration)"
    }

    public func dayStanding(_ duration: String) -> String {
        vi ? "Đứng \(duration)" : "Standing \(duration)"
    }

    // MARK: - Settings

    public var reminderSection: String { vi ? "Nhắc nhở đứng dậy" : "Stand-up reminders" }
    public var reminderOff: String { vi ? "Tắt nhắc nhở" : "Reminders off" }

    public func reminderEvery(minutes: Int) -> String {
        if vi {
            return "Mỗi \(minutes) phút ngồi liên tục"
        }
        return minutes == 1
            ? "Every minute of continuous sitting"
            : "Every \(minutes) minutes of continuous sitting"
    }

    public var soundToggle: String { vi ? "Âm thanh nhắc nhở" : "Reminder sound" }
    public var flashToggle: String { vi ? "Nháy toàn màn hình" : "Full-screen flash" }
    public var quoteToggle: String { vi ? "Hiện quote khi nháy" : "Show quote on flash" }
    public var dismissHint: String { vi ? "Bấm vào đâu cũng được để tắt" : "Click anywhere to dismiss" }
    public var permissionRow: String { vi ? "Quyền gửi nhắc nhở" : "Notification permission" }
    public var permissionOn: String { vi ? "Đã bật" : "On" }
    public var permissionOff: String { vi ? "Chưa bật" : "Off" }
    public var requestButton: String { vi ? "Xin quyền" : "Request access" }
    public var openSystemButton: String { vi ? "Mở Cài đặt hệ thống" : "Open System Settings" }

    public var autoSection: String { vi ? "Tự động" : "Automatic" }

    public func idleTitle(minutes: Int) -> String {
        if vi {
            return "Tự tạm nghỉ sau \(minutes) phút không dùng máy"
        }
        return minutes == 1
            ? "Auto-pause after 1 minute idle"
            : "Auto-pause after \(minutes) minutes idle"
    }

    public var resumeToggle: String { vi ? "Tự tiếp tục khi quay lại" : "Auto-resume on return" }
    public var startPausedToggle: String { vi ? "Mở app ở trạng thái Tạm nghỉ" : "Launch paused" }

    public var goalSection: String { vi ? "Mục tiêu" : "Goal" }
    public var goalOff: String { vi ? "Không đặt mục tiêu đứng" : "No standing goal" }

    public func goalOn(_ duration: String) -> String {
        vi ? "Đứng \(duration) mỗi ngày" : "Stand \(duration) a day"
    }

    public var displaySection: String { vi ? "Ngôn ngữ & lịch" : "Language & calendar" }
    public var languageLabel: String { vi ? "Ngôn ngữ" : "Language" }
    public var calendarLabel: String { vi ? "Lịch phụ" : "Secondary calendar" }

    public var systemSection: String { vi ? "Hệ thống" : "System" }
    public var loginToggle: String { vi ? "Mở cùng máy" : "Launch at login" }

    public func loginError(_ detail: String) -> String {
        vi ? "Không đặt được — mục này chỉ dùng khi chạy từ file .app: \(detail)"
            : "Could not set — this only works when running from the .app bundle: \(detail)"
    }

    public var dataSection: String { vi ? "Dữ liệu" : "Data" }
    public var revealButton: String { vi ? "Mở thư mục dữ liệu" : "Reveal data folder" }
    public var resetTodayButton: String { vi ? "Xóa dữ liệu hôm nay" : "Clear today's data" }
    public var clearAllButton: String { vi ? "Xóa toàn bộ lịch sử" : "Erase all history" }

    public func footerNote(version: String) -> String {
        vi ? "SittingTime \(version) • Dữ liệu chỉ nằm trên máy này, không mạng, không tài khoản."
            : "SittingTime \(version) • Data stays on this Mac: no network, no account."
    }

    public var resetTodayDialog: String { vi ? "Xóa dữ liệu hôm nay?" : "Clear today's data?" }
    public var deleteButton: String { vi ? "Xóa" : "Delete" }
    public var keepButton: String { vi ? "Giữ lại" : "Keep" }
    public var clearAllDialog: String { vi ? "Xóa toàn bộ lịch sử?" : "Erase all history?" }
    public var deleteAllButton: String { vi ? "Xóa hết" : "Erase all" }

    // MARK: - Secondary calendar names

    public func calendarName(_ calendar: SubCalendar) -> String {
        switch (calendar, language) {
        case (.off, .vietnamese): return "Tắt"
        case (.off, .english): return "Off"
        case (.vietnamese, .vietnamese): return "Âm lịch (Việt)"
        case (.vietnamese, .english): return "Vietnamese lunar"
        case (.chinese, .vietnamese): return "Lịch Trung"
        case (.chinese, .english): return "Chinese"
        case (.hebrew, .vietnamese): return "Lịch Do Thái"
        case (.hebrew, .english): return "Hebrew"
        case (.islamic, .vietnamese): return "Lịch Hồi giáo"
        case (.islamic, .english): return "Islamic"
        case (.buddhist, .vietnamese): return "Phật lịch"
        case (.buddhist, .english): return "Buddhist"
        }
    }

    // MARK: - Notifications

    public func reminderTitle(continuous: String) -> String {
        vi ? "Ngồi \(continuous) rồi — đứng dậy nhé!" : "Sat \(continuous) — time to stand!"
    }

    public func reminderBody(sitting: String, standing: String) -> String {
        vi ? "Hôm nay: ngồi \(sitting) • đứng \(standing)"
            : "Today: sitting \(sitting) • standing \(standing)"
    }

    public var goalTitle: String { vi ? "Đạt mục tiêu đứng hôm nay!" : "Daily standing goal reached!" }

    public func goalBody(goal: String) -> String {
        vi ? "Bạn đã đứng \(goal). Tuyệt vời!" : "You stood \(goal). Well done!"
    }
}
