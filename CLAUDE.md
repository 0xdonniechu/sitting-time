# SittingTime: a tray-first Stand Up and Pomodoro timer for Windows

## What it does
A small Tauri 2 tray app. Rust owns timer state, deadlines, persistence, notifications and the tray.
Vanilla TypeScript only renders Rust snapshots and sends commands. It never places network calls,
has no accounts and no server. A bug costs a missed or wrong reminder, a timer that drifts after
sleep or restart, or lost local settings in `state.json`. The implementation rules are in
`AGENTS.md`; product behaviour is in `SPEC.md`.

## Verify
- Unit: `cargo test --manifest-path src-tauri/Cargo.toml`
- Lint: `cargo clippy --manifest-path src-tauri/Cargo.toml --all-targets -- -D warnings` (0 warnings)
- Frontend: `npm run build` (tsc strict + vite)
- Package: `npm run tauri build`, required after a change to `tauri.conf.json`, capabilities,
  plugins, icons or `Cargo.toml`.
- Owner-only, on real Windows hardware (agents write "not run: owner-only"):
  tray menu actions, close hides and Quit exits, restart restores a running timer,
  sleep/wake accuracy, notification identity in the installed build, full-screen reminder and
  alert sound, multi-monitor, Smart App Control with the pinned toolchain.

## HARD: the main session does it directly, then hard-reviewer
- `src-tauri/src/timer.rs` state machine: deadlines, `tick` catch-up, `advance_session`,
  pause/resume, skip, mode switch, the long-break cycle.
- Persistence: the `state.json` format, `settings::load`/`save`, the legacy-path migration.
  Anything that could drop or overwrite a user's saved settings.
- The Rust/TS contract: `TimerSnapshot`, `SettingsPayload`, command names, event names.
- Tray-first lifecycle: close hides the window, only Quit exits.
- `rust-toolchain.toml`, `capabilities/`, CSP and plugin permissions.

## MEDIUM: builder builds, reviewer reviews
- Settings UI wiring, notifications, the reminder overlay, autostart, tray menu entries.
- A new Tauri command or event outside the timer core.
- A bug with a clear cause outside the HARD areas.

## EASY: transcriber or builder, no review
- Wording, CSS, icons, README and SPEC prose, renames, log cleanup.

## Rules
- Never silently change the product defaults (Stand Up 45/5, Pomodoro 25/5/15, long break
  every 4) or the validation ranges (1-240 minutes, 1-12 sessions). Flag it and ask.
- JavaScript never computes elapsed time. This grep must stay at 0 hits:
  `grep -rnE "Date\.now|performance\.now|setInterval|new Date" src/`
- No React, Vue, Next.js, Tailwind, state libraries, SQLite, auth, telemetry, remote APIs or a
  backend server (see `AGENTS.md`). A new dependency is a question, not a decision.
- Git: account `0xdonniechu`, author `0xdonniechu <211609259+0xdonniechu@users.noreply.github.com>`.
  One branch per change (`fix/...`, `feat/...`), merged to `main` only when the owner asks.
  No remote yet; do not create one or push without being asked.
- Issue tracker: Plane, once this folder is bound (`claude mcp add -s local ...`). Not bound yet.
