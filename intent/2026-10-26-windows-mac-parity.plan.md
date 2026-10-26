# Plan: Windows parity với macOS v1.1.x

Intent: `intent/2026-10-26-windows-mac-parity.md`. Branch:
`feat/windows-stats-about-parity` (stack trên 365-facts commit, chưa push).

## Files (theo thứ tự làm)

1. `src-tauri/src/stats.rs` (mới) — `Phase` (Sitting/Standing/Paused),
   `HourRecord`, `DayRecord` (totals + breakCount + longestSit + hourly[24]),
   `WeekDay`, `StatsStore` (records map, open segment, stretch clock,
   goal-notified day). Day key `yyyy-MM-dd` múi UTC+7 (khớp calendar tile).
   Gap > 120 s giữa hai lần attribute thì bỏ (ngủ/treo máy), chỉ stats bỏ,
   timer giữ nguyên deadline catch-up theo SPEC. Unit tests: day key/hour
   UTC+7, rollover nửa đêm, split theo giờ, gap discard, longest-sit qua
   break, breakCount, reset/clear, serde default tương thích.
2. `src-tauri/src/settings.rs` — `GeneralSettings` + `language: AppLanguage`
   (`"en"` default, `"vi"`), `stand_goal_minutes: u32` (default 60, validate
   0..=600, validate language trong `SettingsPayload::validate`).
   `PersistedAppState` + `stats: StatsStore`; `save()` nhận thêm stats.
   Test migration kiểu pre-facts: state cũ thiếu key vẫn load, default đúng.
3. `src-tauri/src/timer.rs` — `set_mode` giữ session như Mac: work stays
   work (Sitting/Focus → Sitting/Focus), break stays break (Move/ShortBreak/
   LongBreak → Move/ShortBreak/LongBreak, LongBreak→Move khi sang StandUp),
   elapsed mang sang, running giữ running (deadline tính lại), về StandUp
   reset completed về 0, sang Pomodoro giữ nguyên. Sửa test
   `mode_change_resets_to_sitting` thành contract mới + thêm test elapsed.
4. `src-tauri/src/lunar.rs` — `CalendarDay` + `zodiac_animal: ZodiacAnimal`
   (12 chi từ can-chi hiện có; test branch mapping).
5. `src-tauri/src/lib.rs` — `AppState` + `stats: Mutex<StatsStore>`;
   helper `tick_and_sync` (tick + đếm breakCount khi work session tự
   advance + attribute phase + persist khi transition); `mutate_timer`
   attribute lại phase sau mỗi action; worker: sync + checkpoint 30 s +
   goal notify 1 lần/ngày. Commands mới: `get_stats` (today live + week 7
   ngày, label theo language), `reset_today`, `clear_history`,
   `get_app_info` (version/author/bug/donate URLs).
6. `src/strings.ts` (mới) — bảng EN (từ `Strings.swift`) + VI (từ
   `vi.json`, key không phải `quote.*`), `t()` + `{arg}` + plural
   breaksLine one/other, `formatDuration` khớp Mac (giờ/phút/giây + plural
   EN, không plural VI).
7. `src/main.ts` — dash: Today section, goal progress, footer
   (Stats/Settings/About + coffee pill); views Stats (Day/Week, total lớn,
   CSS bars 24h/7d, legend, rows, confirm reset/erase), Settings (+ Goal,
   Language, Support/donate, footer note), About (version/author/bug);
   điều hướng shell↔3 views; zodiac emoji cạnh lunar; áp language toàn UI.
8. `src/styles.css` — style views/rows/bars/footer/pill, light+dark,
   giữ minimal hiện có (không gradient chữ mới, không emoji làm icon chrome,
   tôn trọng prefers-reduced-motion đã có).
9. Version 0.3.5 → 0.4.0 (`Cargo.toml`, `tauri.conf.json`, `package.json`);
   `SPEC.md` + `README.md` mô tả stats/about/goal/language/zodiac.
10. Commit: rust (stats+settings+timer+lunar+lib), frontend (strings+main+css),
    docs/version. Không push/merge.

## Risks

- Contract Rust/TS đổi (`SettingsPayload` thêm key, snapshot stats mới):
  frontend gửi/nhận thiếu key → TS type + `get_settings` mặc định Rust
  đỡ. Bắt bằng `npm run build` (tsc strict) + test round-trip settings.
- `state.json` cũ: mọi struct mới `#[serde(default)]`; test load file cũ.
- Timer keep-session sai elapsed → test deterministic bằng deadline_epoch
  giả (kiểu test `tick_catches_up_from_deadline_after_sleep` có sẵn).
- Attribution sai phase/giờ → test stats với timestamp cố định UTC+7.
- jaroWinkler… không. Không có network trong app (CSP giữ nguyên).

## Proof (định nghĩa xong)

- Harness `cargo test` cho timer/settings/lunar/stats/facts (module pure,
  code thật): tất cả pass. Full `cargo test`/`clippy` trong repo cần
  webkit2gtk + toolchain Windows → ghi "not run" trung thực nếu thiếu.
- `npm run build` (tsc strict + vite) xanh.
- `grep -rnE "Date\.now|performance\.now|setInterval|new Date" src/` —
  chỉ còn polling `setTimeout` có sẵn (0 hit cho elapsed logic).
- Independent review PASS trên diff của branch.
- Owner-only trên Windows thật: tray actions, full-screen reminder, installer (ghi not run).

## Review (round 1: FAIL — 1 MAJOR + 4 MINOR, đã sửa hết)

1. MAJOR: `goal_day` từng `#[serde(skip)]` nên restart re-fire goal — đã
   persist trong `state.json` (file cũ thiếu key vẫn load = un-notified).
2. Rollover không reset `stretch_start_ms`, longest-sit ngày mới phình —
   đã restart stretch tại midnight (ngày cũ giữ phần đến midnight).
3. `tick_and_sync` đếm tối đa 1 break mỗi tick catch-up — đã gate bằng
   `gap_since_last`: gap ngủ = 0 break (như Mac), không gap thì tối đa 1
   transition nên 1 break/1 work session là chính xác.
4. `validate()` thiếu language check theo plan — đã thêm exhaustive match
   chốt contract (enum nên deserialize đã loại input lạ).
5. MINOR đòi revert `ESNext.Disposable` trong tsconfig — BÁC, có bằng chứng:
   `@tauri-apps/api` 2.12.4 khai báo `[Symbol.asyncDispose]`
   (`core.d.ts:422`), thiếu lib là `npm run build` gãy TS2550 (đã quan sát).
