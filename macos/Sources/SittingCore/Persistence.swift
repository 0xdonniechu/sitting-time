import Foundation

/// On-disk shape. `version` lets future releases migrate old files.
public struct StoredData: Codable, Sendable {
    public var version: Int
    public var records: [String: DayRecord]

    public init(version: Int = 1, records: [String: DayRecord] = [:]) {
        self.version = version
        self.records = records
    }
}

/// JSON persistence under `~/Library/Application Support/SittingTime`.
/// Loads never throw: a missing or corrupt file yields defaults (and the error
/// goes to stderr so a console run shows it instead of silently dropping data).
public enum Persistence {
    public static let folderName = "SittingTime"
    public static let dataFileName = "records.json"
    public static let settingsFileName = "settings.json"
    public static let currentVersion = 1

    public static func folderURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent(folderName, isDirectory: true)
    }

    public static func loadData() -> StoredData {
        guard let url = folderURL()?.appendingPathComponent(dataFileName),
              FileManager.default.fileExists(atPath: url.path)
        else { return StoredData() }
        do {
            let raw = try Data(contentsOf: url)
            let stored = try JSONDecoder().decode(StoredData.self, from: raw)
            if stored.version != currentVersion {
                fputs("SittingTime: records version \(stored.version), keeping as-is\n", stderr)
            }
            return stored
        } catch {
            fputs("SittingTime: cannot load records (\(error)); starting empty\n", stderr)
            return StoredData()
        }
    }

    public static func saveData(_ data: StoredData) {
        guard let folder = folderURL() else { return }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let raw = try JSONEncoder().encode(data)
            try raw.write(to: folder.appendingPathComponent(dataFileName), options: .atomic)
        } catch {
            fputs("SittingTime: cannot save records (\(error))\n", stderr)
        }
    }

    public static func loadSettings() -> AppSettings {
        guard let url = folderURL()?.appendingPathComponent(settingsFileName),
              FileManager.default.fileExists(atPath: url.path)
        else { return AppSettings() }
        do {
            let raw = try Data(contentsOf: url)
            return try JSONDecoder().decode(AppSettings.self, from: raw).clamped
        } catch {
            fputs("SittingTime: cannot load settings (\(error)); using defaults\n", stderr)
            return AppSettings()
        }
    }

    public static func saveSettings(_ settings: AppSettings) {
        guard let folder = folderURL() else { return }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let raw = try JSONEncoder().encode(settings)
            try raw.write(to: folder.appendingPathComponent(settingsFileName), options: .atomic)
        } catch {
            fputs("SittingTime: cannot save settings (\(error))\n", stderr)
        }
    }
}
