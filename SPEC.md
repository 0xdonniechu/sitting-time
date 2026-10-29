# SittingTime — MVP Specification

## Product behavior

The app is a small Windows tray utility with two modes:

- **Stand Up:** 45 minutes of sitting/work, followed by 5 minutes of movement.
- **Pomodoro:** 25 minutes of focus, 5 minutes of short break, and a 15-minute long break after four focus sessions.

The current MVP launches a compact window, keeps running when the window is closed, and implements live Pomodoro and Stand Up timers. Rust stores an absolute deadline while running and a remaining duration while paused. The frontend receives snapshots and never acts as the source of truth for elapsed time. Switching modes keeps the running session (work stays work, break stays break), like the macOS app.

## Architecture

- Tauri 2 provides the native Windows shell and system tray.
- Rust owns timer state, timestamps/deadlines, persistence, notifications, and tray commands.
- Vanilla TypeScript only renders state and sends commands to Rust.
- Plain CSS provides a compact light/dark system-aware UI. Each session kind has its own accent from the Edge Browser palette (#55d555, #2bc3d2, #40bfff, #057fd7, #104e92); text and buttons use darker shades of the same hues so contrast stays at or above 4.5:1. A progress bar shows the share of the session elapsed, computed from the Rust snapshot's remaining and total seconds. The top-right corner shows a small red calendar tile: today's solar day in large type and the Vietnamese lunar day/month below it (leap months marked "N"); to its left, the ISO 8601 week number in light type (e.g. "W42") above the bold capitalised English month abbreviation (e.g. "OCT"); to its right, the lunar year's zodiac animal from the macOS art set, at the tile's height. The mode title carries a small regular "after N minutes" suffix showing the active mode's work-session length from the settings. Hovering the tile, the week label or the zodiac icon shows the full date (weekday, solar date, ISO week, lunar date and can chi year), which is also the tile's accessible label; Rust computes both in the fixed UTC+7 time zone with Hồ Ngọc Đức's conversion, and the frontend asks for them at startup, when the window becomes visible, and every minute.
- A hidden, always-on-top reminder WebView renders the optional full-screen transition effect; Rust decides when it is shown.
- The full-screen reminder can also show one short health fact (movement, water, food, eating habits, sleep, sunlight, stretching, eyes) with an emoji, in Vietnamese with the English line below it; it then stays up for 20 seconds instead of 6. 365 facts (one per day) are compiled into the app and Rust picks one at random each time; the toast never shows one. The "Health facts on reminders" setting is on by default, and a `state.json` saved before it existed loads with it on.
- Local JSON/config persistence is sufficient; there is no server, account, database, telemetry, or cloud sync.

Rust also attributes sitting / standing / rest time into per-day statistics (UTC+7 day keys, hourly buckets, break counts, longest-sit stretches), shown in a Screen Time-style Statistics view with Day/Week scopes. A Sit/Stand picker with macOS-style desk pictograms sits above Pause/Skip: work sessions attribute to sitting or standing per the picker, while every break (including Move) counts as rest. Posture is live body state, never persisted: a restart always comes back sitting. Gaps over two minutes between attributions (sleep) are discarded from stats; the countdown itself keeps its deadline catch-up. A daily standing goal (default 60 minutes, 0 disables it) notifies once per day.

The UI is bilingual (English default, Vietnamese bundled — no download) and includes an About panel (version, author, bug reports; no network update check), a "Buy me a coffee" link, and the lunar year's zodiac animal beside the calendar tile. An optional daily quote (366 bilingual entrepreneurial quotes, one per calendar day, off by default) can replace the status line.

Settings, timer state and statistics are stored in `state.json` under Tauri's application config directory. Writes occur after user actions, settings changes, and session transitions; the countdown itself remains deadline-based and does not write every second. Each write goes to a sibling temporary file that is renamed over `state.json`. A `state.json` that cannot be parsed is copied to `state.json.corrupt` before defaults are used, and restored durations outside the settings ranges fall back to the product defaults. Saving settings resets the current session only when a timer duration or the long-break cycle changed. If the app panics, the message and a backtrace are appended to `crash.log` in the same folder (restarted once it passes 256 KB); nothing else is written there and nothing leaves the machine.

Both windows are declared with `"create": false` and built in `setup()` after the timer state is registered, so a page that loads quickly can never query the timer before it exists.

Timer state will use explicit Rust enums/structs for mode, phase, run state, and persisted timestamps. Elapsed time must be derived from timestamps/deadlines rather than a JavaScript interval, so it remains correct while the window is hidden, inactive, or the machine sleeps.

## Tray behavior

Closing the main window prevents the close action and hides the window. The process remains alive until an explicit Quit tray action is selected. The tray exposes Show, Start/Resume, Pause, mode selection, Skip, Settings, and Quit.

## Planned milestones

1. Verification on Windows, including sleep/wake and restart behavior.
2. Build and test the Windows installer so notification identity is correct.
3. Verify full-screen reminders, alert sound, and multi-monitor behavior on Windows hardware.
