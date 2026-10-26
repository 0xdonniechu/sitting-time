import Foundation

/// Version shown in Settings. Reads the bundled Info.plist; falls back to
/// `"dev"` when running as a raw binary (which has no plist).
enum AppInfo {
    /// Marketing version (`"1.2.0"`), nil for raw binaries. Drives the
    /// update check; display code uses `version` instead.
    static var shortVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String
        let build = info?["CFBundleVersion"] as? String
        if let short, let build { return "\(short) (\(build))" }
        return "dev"
    }

    /// Donation page.
    static let donateURL = URL(string: "https://ko-fi.com/0xdonniechu")!
    /// Author profile, shown in About.
    static let authorName = "0xdonniechu"
    static let authorURL = URL(string: "https://github.com/0xdonniechu")!
    /// New-issue form, shown in About.
    static let reportBugURL = URL(string: "https://github.com/0xdonniechu/sitting-time/issues/new")!
    /// Repo home, shown in About for the star request.
    static let repoURL = URL(string: "https://github.com/0xdonniechu/sitting-time")!
}
