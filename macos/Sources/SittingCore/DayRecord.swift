import Foundation

/// Closed (finished) segments of one calendar day, keyed by `"yyyy-MM-dd"`.
/// The currently open segment is NOT included here; callers merge it for live display.
public struct DayRecord: Codable, Sendable, Equatable {
    public var dateKey: String
    public var sittingSeconds: TimeInterval
    public var standingSeconds: TimeInterval
    public var pausedSeconds: TimeInterval
    public var breakCount: Int
    public var longestSitSeconds: TimeInterval

    public init(
        dateKey: String,
        sittingSeconds: TimeInterval = 0,
        standingSeconds: TimeInterval = 0,
        pausedSeconds: TimeInterval = 0,
        breakCount: Int = 0,
        longestSitSeconds: TimeInterval = 0
    ) {
        self.dateKey = dateKey
        self.sittingSeconds = sittingSeconds
        self.standingSeconds = standingSeconds
        self.pausedSeconds = pausedSeconds
        self.breakCount = breakCount
        self.longestSitSeconds = longestSitSeconds
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
}
