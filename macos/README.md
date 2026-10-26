# SittingTime (macOS port)

Menu bar app that keeps sitters standing up on rhythm: a countdown work
session (default 45:00), then a chime + full-screen flash telling you to
stand up and move for 5:00, then a new session starts on its own. Sitting
and standing inside sessions are both recorded, with per-day and trailing
7-day sit/stand totals. One goal: never sit still for hours — the leading
cause of back pain, spinal degeneration, and herniated discs among office
workers and devs. English by default, Vietnamese as a download in Settings;
no account, data stays on this Mac.

> Origin note: this native macOS (Swift) port started as a cumulative
> sit/stand/rest tracker, built from the repo's name and purpose while the
> original repo was still private. The repo owner then converged it onto the
> Tauri build's model: session timers (Stand Up 45/5, Pomodoro 25/5/15),
> with sit/stand posture inside sessions feeding the same sit/stand stats.

## Features

- **Countdown sessions**: Stand Up (work 45 → move 5, repeating) or Pomodoro
  (focus 25 → short break 5, long break 15 after every 4 sessions); every
  minute value is editable in Settings. Sessions advance on their own —
  nothing to press.
- **Chime + flash at every session end**: end of work reminds you to stand up
  and move, end of break reminds you to start the next session. Black
  full-screen flash + 1 random quote (20 s, any click/key dismisses, never
  steals focus); with flash off you only get the banner. 20 s with a quote,
  6 s without (like the Tauri build).
- **Live menu bar**: icon follows session/posture + countdown clock (fixed-width
  digits, no jitter; the icon canvas is fixed size so pausing/skipping never
  shifts the open popover).
- **Popover**: big clock, session progress, Sit/Stand switch, Pause/Resume,
  Skip (jump sessions), Stand Up/Pomodoro switcher, today's totals, standing
  goal progress, stand-up count, longest sit.
- **Auto-pause**: after N minutes without mouse/keyboard (default 5′);
  auto-resumes when you return.
- **Standing goal**: one notification when you hit the daily mark (default 60′).
- **Correct sleep/rollover**: sleep gaps are excluded from stats and freeze the
  session; stretches crossing midnight split across both days; sessions and
  sit stretches continue past midnight.
- **7-day stats**: sit/stand bar chart + per-day rows, with a back-to-dashboard
  button.
- **Settings**: every threshold, sound, launch at login, notification
  permission, reveal/clear data, downloadable language, support link.
- **English + downloadable Vietnamese**: English ships in the binary; Vietnamese
  downloads on demand from Settings and stays a small cache file. Applies to
  popover, stats, settings, and reminders; any missing string falls back to
  English.
- **Secondary calendar**: two-column tile in the popover — solar day/month
  beside the secondary day/month, ISO week + lunar year (Can Chi in its
  five-element color + monochrome zodiac icon) on top. Vietnamese lunar,
  Chinese, Hebrew, Islamic, Buddhist, or off; hover the tile for the full date.
- **Health quotes**: 365 English facts (first ~105 from the Tauri build),
  Vietnamese in the language pack; each flash shows 1 random quote — not one
  quote per day.
- **Buy me a coffee**: pill in the popover footer + Support section in Settings.
- **No dock**: the app lives on the menu bar only (`LSUIElement`).

## Build & run

Requires: macOS 14+, Xcode (Swift 6).

```bash
./scripts/build-app.sh   # tests + 0-warning release build + icon paint + .app assemble (ad-hoc signed)
open dist/SittingTime.app
./scripts/build-dmg.sh   # build-app.sh + dist/SittingTime.dmg (drag into Applications)
```

A raw dev run (`swift run`) works but shows a dock icon for lack of a bundle;
the `.app` is the real way to run. "Launch at login" only works from the `.app`
file too.

Data: `~/Library/Application Support/SittingTime/` (`records.json`, `settings.json`).

## Testing

- `swift test`: 59 tests (Swift Testing) — state machine on a fake clock
  (countdown, silent Stand Up/Pomodoro transitions, silent skip, pause freezing
  the session, posture logging sit/stand hours, mode switch, minute edits
  restarting the right session, auto-pause/resume, sleep, midnight rollover,
  goals, checkpoints without double-counting or clock jumps), English
  formatting, legacy settings (with the old `sitReminderMinutes` key) still
  loading, Vietnamese pack (key coverage, placeholder fill, plural rules,
  English fallback per string), sub-calendars (Tet, leap month, Yom Kippur,
  Adar I/II, Ramadan, Buddhist year, Can Chi elements, zodiac animals), 365
  quotes (exact count, unique, max 160 chars, random picks inside the set)
  and the flash hook (fires exactly once per session end, honors both
  toggles, silent banner while flash shows).
- Icon: the paint script self-checks pixels (white chair, teal background,
  orange dot, transparent corner) and verifies the `.icns` reads back all
  7 image sizes.
- GUI checks on a real machine (screenshots + system window list): menu bar
  ticking every second and continuing past the 30 s checkpoint mark (`0:39`
  at second 40); popover and stats window showing synced numbers, updating
  every second; checkpoint writing `records.json` right (30.00 s after
  `kill -9` at second 40); a second copy quitting itself (single instance);
  no new crashes.
- Reminder flash end-to-end for real: 1-minute reminder scheduled, at minute
  60 the flash window appears full-screen (screenSaver layer) with a random
  quote, then dismisses itself (window gone); 3 runs showed 3 different
  quotes. SwiftUI windows self-shrink to content so the flash view must be
  framed exactly to screen size, and translucent backgrounds don't work on
  this window so it uses solid black.
- Not yet checked (needs one real mouse click from you): popover buttons,
  first-run notification permission dialog, reminder banners, the Quit
  button, and click-to-dismiss the flash — automation on this machine can't
  see/click menu bar app windows, so that waits for you. Saving on quit has
  a checkpoint safety net: worst case loses the last 30 s if killed.

## Layout

```
Package.swift                    # Swift 6, macOS 14+, no dependencies
Sources/SittingCore/             # pure testable logic (no AppKit/SwiftUI)
  SittingStore.swift             # session state machine + timer + idle + rollover + sleep
  Session.swift                  # SessionMode/Kind/Posture (Stand Up, Pomodoro, Sit/Stand)
  DayRecord.swift                # one day's record (sit/stand/rest, stand-ups, longest sit)
  AppSettings.swift              # per-session minutes + thresholds + clamping
  Persistence.swift              # JSON under Application Support, errors to stderr
  IdleMonitor.swift              # HIDIdleTime via IOKit (read-only)
  ReminderCenter.swift           # UserNotifications wrapper (live/silent)
  LoginItemManager.swift         # SMAppService
  SitPhase.swift / Formatting.swift
  AppLanguage.swift              # built-in English / downloadable Vietnamese + 5 sub-calendars (+ off)
  Strings.swift                  # default English strings + Vietnamese pack lookup by key
  LanguagePack.swift             # download/install/remove lang-vi.json, per-string English fallback
  SubCalendar.swift              # sub-calendar dates via Foundation (lunar = Chinese at UTC+7)
  HealthQuotes.swift             # 365 English quotes + index; Vietnamese lives in the pack
Sources/SittingTime/             # SwiftUI: menu bar, popover, stats (Charts), settings
  FlashCenter.swift              # black full-screen flash window + message/quote card
  ZodiacArt.swift                # monochrome zodiac loader, element-tinted
Tests/SittingTimeTests/          # 59 tests with FakeClock/FakeIdle/SpyNotify
scripts/build-app.sh             # test → release → icon → sign .app
scripts/build-dmg.sh             # build-app.sh + drag-to-Applications .dmg
scripts/generate-icon.swift      # paint icon + self-check + hand-assembled .icns
Resources/Info.plist             # LSUIElement, id com.0xdonniechu.sittingtime
Resources/LanguagePacks/vi.json  # Vietnamese pack (downloaded from public URL, never bundled)
Resources/Zodiac/*.png           # 12 monochrome zodiac icons (transparent, element-tinted)
```

## Locked decisions

- English UI by default; Vietnamese is a download in Settings (never bundled,
  keeps installs small), each missing string falls back to English. Personal
  app, not part of the Ambysto suite, so no suite bar spec.
- Timer follows **self-advancing countdown sessions** (like the Tauri build),
  not open-ended accumulation: Stand Up 45/5, Pomodoro 25/5/15 after every 4
  focus sessions; every session end chimes + flashes. Sit/stand posture inside
  work sessions feeds the sit/stand stats; breaks, pauses, and auto-pause all
  count as rest.
- “Stand-up” count = completed work sessions (skips don't count); the
  continuous sit stretch only breaks on standing/pausing — sitting through a
  break still counts as one stretch.
- Editing the minutes of the currently running session restarts it; editing
  other fields leaves it alone (Tauri rule). Switching modes starts a fresh
  work session.
- Idle reads `HIDIdleTime` (IOKit) because `kCGAnyInputEventType` can't be
  imported into Swift on the current SDK.
- No `iconutil` (`Invalid Iconset` errors in this build environment despite a
  valid iconset) — the `.icns` is assembled directly per Apple's format.
- The icon pixel check normalizes to 8-bit sRGB before reading: when the
  process can see a display, `lockFocus` renders 16-bit and `getPixel`
  returns garbage (once misread as a flake under load — really sandbox-pass
  / outside-sandbox-fail, confirmed).
- Single instance: `.lock` file via `flock` — a second copy quits itself so
  hours never double-count and `records.json` never gets trampled.
- Hand-written AppKit status item (`NSStatusItem` + `refreshStatusItem` each
  tick): `MenuBarExtra` renders its label once and freezes, and `TimelineView`
  hard-locks the main thread (proven by bisect). SwiftUI views in the
  popover/stats observe the store through `.environment` and also read
  `tickCount`, because every other input stands still while sitting — without
  it views render once and freeze (caught by screenshot).
- Two independent clocks: the session clock counts down, the segment clock
  logs hours; the 30 s checkpoint only restarts the segment so the countdown
  never jumps; `liveToday()` adds exactly the open segment so nothing
  double-counts (locked by test).
- The menu bar clock uses `monospacedDigitSystemFont` so the item never
  resizes (jitters) as digit widths change; every status image is centered
  in one fixed-size canvas so pausing/skipping never shifts the open popover.
- The Settings button opens a hand-made `NSPanel` (like Stats): the Settings
  scene's `showSettingsWindow:` action never fires from the popover while the
  app is inactive.
