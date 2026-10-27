# SittingTime

A lightweight Windows-first sitting and focus utility built with Tauri 2, Rust, and vanilla TypeScript.

The current milestone includes the tray shell and a working Rust timer state machine. The compact UI renders live `MM:SS` state, while Rust owns deadlines, pause/resume behavior, session transitions, and tray actions.

## Mac version

A native macOS port (Swift, menu-bar only, no dependencies) lives in [`macos/`](macos/). See [`macos/README.md`](macos/README.md) for full details, build instructions, and testing.

- Flexible work modes: Stand Up (45 work / 5 move) or Pomodoro (25 / 5 / 15) — every minute value editable, plus a daily standing goal.
- Full history log: per-day sit/stand/rest records with 7-day totals and charts.
- A random health quote (of 365) plus chime and full-screen flash on every session change.
- Optional secondary calendar (Vietnamese lunar, Chinese, Hebrew, Islamic, Buddhist) with Can Chi and zodiac on the popover tile.
- Bilingual UI: English built in, Vietnamese as a small download.

| Popover (Stand Up) | Popover (Pomodoro) |
| --- | --- |
| ![Popover in Stand Up mode](macos/Resources/screenshots/popover-standup.png) | ![Popover in Pomodoro mode](macos/Resources/screenshots/popover-pomodoro.png) |

| Statistics (Day) | Statistics (Week) |
| --- | --- |
| ![Statistics day view](macos/Resources/screenshots/stats-day.png) | ![Statistics week view](macos/Resources/screenshots/stats-week.png) |

| Settings (sessions) | Settings (display) |
| --- | --- |
| ![Settings sessions](macos/Resources/screenshots/settings-sessions.png) | ![Settings display](macos/Resources/screenshots/settings-display.png) |

## Development

```bash
npm install
npm run tauri dev
```

For a production build:

```bash
npm run tauri build
```

Windows development requires Rust/Cargo, Microsoft C++ Build Tools, WebView2, and Node.js.

The project pins Rust `1.96.0` because some Windows systems with Smart App Control currently block Rust `1.97.1` build executables during Cargo compilation.

## Project layout

- `src/` — minimal frontend renderer
- `src-tauri/src/timer.rs` — deadline-based timer state machine
- `src-tauri/src/lib.rs` — Tauri commands, worker, and tray behavior
- `src-tauri/tauri.conf.json` — window and bundle configuration
- `SPEC.md` — product and architecture specification
- `AGENTS.md` — implementation rules for future changes

## Current scope

- Pomodoro and Stand Up cycles use their product defaults.
- Start, pause/resume, skip, reset command, mode switching, and live seconds work.
- Inter Variable is bundled locally for consistent macOS-inspired typography on Windows.
- The visible countdown polls Rust snapshots; JavaScript does not calculate elapsed time.
- Closing the window keeps both the process and timer alive.
- Settings, active timer state and per-day statistics persist to a local `state.json` file.
- Screen Time-style Statistics (Day/Week, hourly bars, break counts, longest sit) with a configurable daily standing goal.
- Bilingual UI (English/Vietnamese), About panel, "Buy me a coffee" link, zodiac animal on the calendar tile.
- Switching Stand Up / Pomodoro keeps the running session.
- Native session notifications and optional launch-at-login use official Tauri plugins.
- Optional full-screen reminders provide a brief screen flash, centered session message, and independently configurable alert sound.
- Full-screen reminders can show a short bilingual (Vietnamese/English) health fact with an emoji; on by default and can be turned off in Settings.
- Start-minimized-to-tray is configurable.

On Windows, notification identity is correct for an installed build. During `tauri dev`, Windows may attribute development notifications to PowerShell.
