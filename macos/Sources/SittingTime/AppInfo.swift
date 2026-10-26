import Foundation

/// Version shown in Settings. Reads the bundled Info.plist; falls back to
/// `"dev"` when running as a raw binary (which has no plist).
enum AppInfo {
    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String
        let build = info?["CFBundleVersion"] as? String
        if let short, let build { return "\(short) (\(build))" }
        return "dev"
    }

    /// Donation page.
    static let donateURL = URL(string: "https://ko-fi.com/0xdonniechu")!
}
