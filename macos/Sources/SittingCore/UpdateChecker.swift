import Foundation

/// Manual update check against the public GitHub releases list. No
/// credentials, no background polling: the About panel runs this only when
/// the user taps Check for Updates.
public enum UpdateChecker {
    /// All releases, newest first. Only `macos-v*` tags count.
    public static let apiReleases = URL(string: "https://api.github.com/0xdonniechu/sitting-time/releases")!

    public enum Status: Sendable, Equatable {
        case current
        case available(String)
        case failed
    }

    private struct GHRelease: Decodable {
        var tagName: String
    }

    /// Parses a releases-list payload, returning the highest `macos-v*`
    /// version (`"1.2.0"`), or nil when none is found.
    public static func latestVersion(in data: Data) -> String? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let releases = try? decoder.decode([GHRelease].self, from: data) else { return nil }
        let versions = releases.compactMap { release -> String? in
            guard release.tagName.hasPrefix("macos-v") else { return nil }
            let version = String(release.tagName.dropFirst("macos-v".count))
            return version.allSatisfy { $0.isNumber || $0 == "." } && !version.isEmpty ? version : nil
        }
        return versions.max { compareVersions($0, $1) == .orderedAscending }
    }

    /// Numeric per-component comparison (`"1.1.10"` beats `"1.1.3"`;
    /// missing components count as zero).
    public static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(left.count, right.count) {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r { return l < r ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }

    /// Download page for a macOS release.
    public static func releasePageURL(version: String) -> URL {
        URL(string: "https://github.com/0xdonniechu/sitting-time/releases/tag/macos-v\(version)")!
    }

    /// Checks for a newer release. Never throws: anything unexpected (no
    /// network, bad payload, dev build without a version) is `.failed`.
    public static func check(currentVersion: String?) async -> Status {
        guard let current = currentVersion, !current.isEmpty else { return .failed }
        guard let (data, response) = try? await URLSession.shared.data(from: apiReleases),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let latest = latestVersion(in: data)
        else { return .failed }
        return compareVersions(latest, current) == .orderedDescending ? .available(latest) : .current
    }
}
