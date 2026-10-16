# SittingTime — MVP Specification

## Product behavior

The app is a small Windows tray utility with two modes:

- **Stand Up:** 45 minutes of sitting/work, followed by 5 minutes of movement.
- **Pomodoro:** 25 minutes of focus, 5 minutes of short break, and a 15-minute long break after four focus sessions.

The current MVP launches a compact window, keeps running when the window is closed, and implements live Pomodoro and Stand Up timers. Rust stores an absolute deadline while running and a remaining duration while paused. The frontend receives snapshots and never acts as the source of truth for elapsed time.

## Architecture

- Tauri 2 provides the native Windows shell and system tray.
- Rust owns timer state, timestamps/deadlines, persistence, notifications, and tray commands.
- Vanilla TypeScript only renders state and sends commands to Rust.
- Plain CSS provides a compact light/dark system-aware UI.
- A hidden, always-on-top reminder WebView renders the optional full-screen transition effect; Rust decides when it is shown.
- Local JSON/config persistence is sufficient; there is no server, account, database, telemetry, or cloud sync.

Settings and timer state are stored in `state.json` under Tauri's application config directory. Writes occur after user actions, settings changes, and session transitions; the countdown itself remains deadline-based and does not write every second. Each write goes to a sibling temporary file that is renamed over `state.json`. A `state.json` that cannot be parsed is copied to `state.json.corrupt` before defaults are used, and restored durations outside the settings ranges fall back to the product defaults. Saving settings resets the current session only when a timer duration or the long-break cycle changed.

Timer state will use explicit Rust enums/structs for mode, phase, run state, and persisted timestamps. Elapsed time must be derived from timestamps/deadlines rather than a JavaScript interval, so it remains correct while the window is hidden, inactive, or the machine sleeps.

## Tray behavior

Closing the main window prevents the close action and hides the window. The process remains alive until an explicit Quit tray action is selected. The tray exposes Show, Start/Resume, Pause, mode selection, Skip, Settings, and Quit.

## Planned milestones

1. Verification on Windows, including sleep/wake and restart behavior.
2. Build and test the Windows installer so notification identity is correct.
3. Verify full-screen reminders, alert sound, and multi-monitor behavior on Windows hardware.
