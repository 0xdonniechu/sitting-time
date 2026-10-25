import Foundation
import IOKit

/// Seconds since the last keyboard/mouse input, read from the `HIDIdleTime`
/// property of the `IOHIDSystem` service (nanoseconds, converted to seconds).
/// Read-only registry access: no event taps, no Accessibility permission needed.
/// Returns 0 when the value cannot be read (fail-present, never fail-idle:
/// a read failure must not auto-pause the user).
public enum IdleMonitor {
    public static func secondsSinceInput() -> TimeInterval {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOHIDSystem"))
        guard service != IO_OBJECT_NULL else { return 0 }
        defer { IOObjectRelease(service) }
        guard let raw = IORegistryEntryCreateCFProperty(
            service,
            "HIDIdleTime" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() else { return 0 }
        guard let nanos = (raw as? NSNumber)?.uint64Value else { return 0 }
        return TimeInterval(nanos) / 1_000_000_000
    }
}
