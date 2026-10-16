# SittingTime

A lightweight Windows-first sitting and focus utility built with Tauri 2, Rust, and vanilla TypeScript.

The current milestone includes the tray shell and a working Rust timer state machine. The compact UI renders live `MM:SS` state, while Rust owns deadlines, pause/resume behavior, session transitions, and tray actions.

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
- Settings and active timer state persist to a local `state.json` file.
- Native session notifications and optional launch-at-login use official Tauri plugins.
- Optional full-screen reminders provide a brief screen flash, centered session message, and independently configurable alert sound.
- Full-screen reminders can show a short bilingual (Vietnamese/English) health fact with an emoji; on by default and can be turned off in Settings.
- Start-minimized-to-tray is configurable.

On Windows, notification identity is correct for an installed build. During `tauri dev`, Windows may attribute development notifications to PowerShell.
