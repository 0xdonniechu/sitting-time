import Foundation

/// One hour's totals within a day (hour 0–23). Days recorded before v1.1.0
/// have no hourly data (all zeros); the day totals still hold the full day.
public struct HourRecord: Codable, Sendable, Equatable {
    public var sittingSeconds: TimeInterval
    public var standingSeconds: TimeInterval
    public var pausedSeconds: TimeInterval

    public init(
        sittingSeconds: TimeInterval = 0,
        standingSeconds: TimeInterval = 0,
        pausedSeconds: TimeInterval = 0
    ) {
        self.sittingSeconds = sittingSeconds
        self.standingSeconds = standingSeconds
        self.pausedSeconds = pausedSeconds
    }

    /// Total tracked seconds in this hour (all phases).
    public var trackedSeconds: TimeInterval {
        sittingSeconds + standingSeconds + pausedSeconds
    }
}

/// Closed (finished) segments of one calendar day, keyed by `"yyyy-MM-dd"`.
/// The currently open segment is NOT included here; callers merge it for live display.
public struct DayRecord: Codable, Sendable, Equatable {
    public var dateKey: String
    public var sittingSeconds: TimeInterval
    public var standingSeconds: TimeInterval
    public var pausedSeconds: TimeInterval
    public var breakCount: Int
    public var longestSitSeconds: TimeInterval
    /// Per-hour buckets, always 24 entries. Days written before v1.1.0 decode
    /// to zeros (the key is absent); totals are unaffected.
    public var hourly: [HourRecord]

    public init(
        dateKey: String,
        sittingSeconds: TimeInterval = 0,
        standingSeconds: TimeInterval = 0,
        pausedSeconds: TimeInterval = 0,
        breakCount: Int = 0,
        longestSitSeconds: TimeInterval = 0,
        hourly: [HourRecord] = Array(repeating: HourRecord(), count: 24)
    ) {
        self.dateKey = dateKey
        self.sittingSeconds = sittingSeconds
        self.standingSeconds = standingSeconds
        self.pausedSeconds = pausedSeconds
        self.breakCount = breakCount
        self.longestSitSeconds = longestSitSeconds
        self.hourly = Self.normalized(hourly)
    }

    private enum CodingKeys: String, CodingKey {
        case dateKey
        case sittingSeconds
        case standingSeconds
        case pausedSeconds
        case breakCount
        case longestSitSeconds
        case hourly
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dateKey = try container.decode(String.self, forKey: .dateKey)
        sittingSeconds = try container.decode(TimeInterval.self, forKey: .sittingSeconds)
        standingSeconds = try container.decode(TimeInterval.self, forKey: .standingSeconds)
        pausedSeconds = try container.decode(TimeInterval.self, forKey: .pausedSeconds)
        breakCount = try container.decode(Int.self, forKey: .breakCount)
        longestSitSeconds = try container.decode(TimeInterval.self, forKey: .longestSitSeconds)
        hourly = Self.normalized(try container.decodeIfPresent([HourRecord].self, forKey: .hourly) ?? [])
    }

    /// Truncates or zero-pads to exactly 24 buckets.
    private static func normalized(_ hours: [HourRecord]) -> [HourRecord] {
        (hours + Array(repeating: HourRecord(), count: 24)).prefix(24).map { $0 }
    }

    /// Total tracked seconds (all phases).
    public var trackedSeconds: TimeInterval {
        sittingSeconds + standingSeconds + pausedSeconds
    }

    /// Adds one finished segment to the record.
    /// - Parameters:
    ///   - phase: the segment's phase.
    ///   - seconds: segment length; non-positive values are ignored.
    ///   - continuousSitSeconds: for `.sitting` segments, the length of the whole
    ///     uninterrupted sitting stretch this segment belongs to (used for the longest-sit stat).
    public mutating func addSegment(
        phase: SitPhase,
        seconds: TimeInterval,
        continuousSitSeconds: TimeInterval = 0
    ) {
        guard seconds > 0 else { return }
        switch phase {
        case .sitting:
            sittingSeconds += seconds
            longestSitSeconds = max(longestSitSeconds, continuousSitSeconds)
        case .standing:
            standingSeconds += seconds
        case .paused:
            pausedSeconds += seconds
        }
    }

    /// Adds seconds to one hour bucket; out-of-range hours are ignored.
    public mutating func addHourly(hour: Int, phase: SitPhase, seconds: TimeInterval) {
        guard seconds > 0, (0..<24).contains(hour) else { return }
        switch phase {
        case .sitting:
            hourly[hour].sittingSeconds += seconds
        case .standing:
            hourly[hour].standingSeconds += seconds
        case .paused:
            hourly[hour].pausedSeconds += seconds
        }
    }
}
