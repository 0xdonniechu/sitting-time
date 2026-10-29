import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { openUrl } from "@tauri-apps/plugin-opener";
import { disable, enable, isEnabled } from "@tauri-apps/plugin-autostart";
import { isPermissionGranted, requestPermission } from "@tauri-apps/plugin-notification";
import "@fontsource-variable/inter";
import "./styles.css";
import { t, type Language } from "./strings";

type TimerMode = "pomodoro" | "standUp";
type SessionKind = "focus" | "shortBreak" | "longBreak" | "sitting" | "move";
type TimerStatus = "idle" | "running" | "paused";
type Posture = "sitting" | "standing";
type ViewName = "dash" | "settings" | "stats" | "about" | "welcome";

interface TimerSnapshot {
  selectedMode: TimerMode;
  session: SessionKind;
  status: TimerStatus;
  posture: Posture;
  remainingSeconds: number;
  totalSeconds: number;
  completedFocusSessions: number;
  focusSessionsBeforeLongBreak: number;
}

interface SettingsPayload {
  sittingMinutes: number;
  movementMinutes: number;
  focusMinutes: number;
  shortBreakMinutes: number;
  longBreakMinutes: number;
  focusSessionsBeforeLongBreak: number;
  launchAtLogin: boolean;
  notificationsEnabled: boolean;
  fullscreenRemindersEnabled: boolean;
  alertSoundEnabled: boolean;
  healthFactsEnabled: boolean;
  startMinimizedToTray: boolean;
  language: Language;
  standGoalMinutes: number;
  welcomed: boolean;
}

interface CalendarDay {
  solarDay: number;
  solarMonth: number;
  solarYear: number;
  weekday: number;
  isoWeek: number;
  lunarDay: number;
  lunarMonth: number;
  lunarYear: number;
  lunarLeap: boolean;
  lunarYearName: string;
  zodiacAnimal: string;
}

interface DayRecord {
  dateKey: string;
  sittingSeconds: number;
  standingSeconds: number;
  pausedSeconds: number;
  breakCount: number;
  longestSitSeconds: number;
  hourly: { sittingSeconds: number; standingSeconds: number; pausedSeconds: number }[];
}

interface WeekDay {
  dateKey: string;
  label: string;
  sittingSeconds: number;
  standingSeconds: number;
  pausedSeconds: number;
}

interface StatsSnapshot {
  today: DayRecord;
  week: WeekDay[];
}

interface AppInfo {
  version: string;
  author: string;
  authorUrl: string;
  bugUrl: string;
  donateUrl: string;
  repoUrl: string;
}

const weekdayNames = ["Chủ Nhật", "Thứ Hai", "Thứ Ba", "Thứ Tư", "Thứ Năm", "Thứ Sáu", "Thứ Bảy"];
const monthAbbreviations = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

// Lucide icons (lucide-static, ISC License, (c) Lucide Contributors).
const GEAR_SVG = `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/><circle cx="12" cy="12" r="3"/></svg>`;
const CHART_SVG = `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 3v16a2 2 0 0 0 2 2h16"/><path d="M7 13v4"/><path d="M12 9v8"/><path d="M17 5v12"/></svg>`;
const INFO_SVG = `<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/></svg>`;

// Desk-work pictograms ported from the macOS DeskPictogram (100x78 canvas,
// same primitives, y-flipped for SVG): a person at a desk with a monitor
// arm, seated on an office chair or standing at a raised desk.
const SIT_SVG = `<svg viewBox="0 0 100 78" aria-hidden="true"><g fill="none" stroke="currentColor" stroke-linecap="round"><line x1="24" y1="26" x2="30" y2="44" stroke-width="13"/><line x1="28" y1="30" x2="53" y2="39.5" stroke-width="7.5"/><line x1="30" y1="46" x2="48" y2="46" stroke-width="10"/><line x1="48" y1="46" x2="48" y2="67" stroke-width="9"/><line x1="44" y1="71" x2="54" y2="71" stroke-width="5"/><line x1="9" y1="51" x2="12" y2="32" stroke-width="7"/><line x1="21" y1="52" x2="21" y2="64" stroke-width="4"/><line x1="21" y1="64" x2="9" y2="72" stroke-width="3"/><line x1="21" y1="64" x2="21" y2="73" stroke-width="3"/><line x1="21" y1="64" x2="33" y2="72" stroke-width="3"/><line x1="84" y1="44" x2="84" y2="32" stroke-width="3"/><line x1="84" y1="32" x2="74" y2="24" stroke-width="3"/></g><g fill="currentColor"><circle cx="23" cy="17" r="8.5"/><circle cx="9" cy="73" r="2.5"/><circle cx="21" cy="74" r="2.5"/><circle cx="33" cy="73" r="2.5"/><circle cx="84" cy="32" r="2.6"/><circle cx="74" cy="24" r="2.4"/><rect x="8" y="47" width="26" height="5" rx="2"/><rect x="53" y="44" width="36" height="4" rx="1.5"/><rect x="67" y="48" width="5" height="24" rx="1"/><rect x="55" y="71.5" width="32" height="3.5" rx="1.5"/><rect x="68" y="14" width="6" height="14" rx="1.5"/></g></svg>`;
const STAND_SVG = `<svg viewBox="0 0 100 78" aria-hidden="true"><g fill="none" stroke="currentColor" stroke-linecap="round"><line x1="25" y1="27" x2="27" y2="45" stroke-width="13"/><line x1="28" y1="31" x2="53" y2="33.5" stroke-width="8"/><line x1="25" y1="45" x2="20" y2="69" stroke-width="9"/><line x1="29" y1="45" x2="34" y2="69" stroke-width="9"/><line x1="14" y1="72" x2="26" y2="72" stroke-width="5"/><line x1="28" y1="72" x2="40" y2="72" stroke-width="5"/><line x1="84" y1="34" x2="84" y2="22" stroke-width="3"/><line x1="84" y1="22" x2="74" y2="14" stroke-width="3"/></g><g fill="currentColor"><circle cx="24" cy="14" r="8.5"/><circle cx="84" cy="22" r="2.6"/><circle cx="74" cy="14" r="2.4"/><rect x="53" y="34" width="36" height="4" rx="1.5"/><rect x="67" y="38" width="5" height="34" rx="1"/><rect x="55" y="71.5" width="32" height="3.5" rx="1.5"/><rect x="68" y="4" width="6" height="14" rx="1.5"/></g></svg>`;

const app = document.querySelector<HTMLDivElement>("#app");
if (!app) throw new Error("App root was not found");

app.innerHTML = `
  <section class="shell" id="view-dash" aria-label="Productivity timer">
    <header class="topbar">
      <div>
        <p class="eyebrow">SITTINGTIME</p>
        <h1><span id="mode-title">Pomodoro</span> <small class="mode-after" id="mode-after"></small></h1>
      </div>
      <div class="topbar-side">
        <div class="week-label" id="week-label" aria-hidden="true">
          <span class="week-number" id="week-number"></span>
          <span class="week-month" id="week-month"></span>
        </div>
        <div class="calendar" id="today" role="img">
          <span class="calendar-head" aria-hidden="true"></span>
          <span class="calendar-day" id="today-solar" aria-hidden="true"></span>
          <span class="calendar-lunar" id="today-lunar" aria-hidden="true"></span>
        </div>
        <img class="zodiac-icon" id="zodiac-icon" alt="" aria-hidden="true">
      </div>
    </header>

    <div class="timer-panel" aria-live="polite">
      <div class="timer" id="timer">25:00</div>
      <div class="progress" aria-hidden="true"><span id="progress-fill"></span></div>
      <div class="session-label" id="session-label">Focus</div>
      <div class="status" id="status">Ready</div>
      <div class="cycle" id="cycle">Session 1 of 4</div>
    </div>

    <div class="posture-selector" role="group" aria-label="Posture">
      <button class="posture-button active" data-posture="sitting" aria-pressed="true">${SIT_SVG}<span data-i18n="postureSit">Sit</span></button>
      <button class="posture-button" data-posture="standing" aria-pressed="false">${STAND_SVG}<span data-i18n="postureStand">Stand</span></button>
    </div>

    <div class="controls">
      <button class="primary-button" id="start-button">Start</button>
      <button class="secondary-button" id="skip-button">Skip</button>
    </div>

    <div class="mode-selector" role="group" aria-label="Timer mode">
      <button class="mode-button active" data-mode="pomodoro">Pomodoro</button>
      <button class="mode-button" data-mode="standUp">Stand Up</button>
    </div>

    <div class="today-section">
      <h2 data-i18n="today">Today</h2>
      <div class="today-rows">
        <div class="today-row"><span class="dot dot-sit"></span><span data-i18n="sitting">Sitting</span><b id="today-sitting">0</b></div>
        <div class="today-row"><span class="dot dot-stand"></span><span data-i18n="standing">Standing</span><b id="today-standing">0</b></div>
        <div class="today-row"><span class="dot dot-rest"></span><span data-i18n="rest">Rest</span><b id="today-rest">0</b></div>
      </div>
      <div class="goal-progress hidden" id="goal-progress">
        <div class="goal-bar" aria-hidden="true"><span id="goal-fill"></span></div>
        <p id="goal-label"></p>
      </div>
      <p class="breaks-line" id="breaks-line"></p>
    </div>

    <footer class="icon-footer">
      <button class="footer-button" id="footer-stats" aria-label="Statistics">${CHART_SVG}</button>
      <button class="footer-button" id="footer-settings" aria-label="Settings">${GEAR_SVG}</button>
      <button class="footer-button" id="footer-about" aria-label="About">${INFO_SVG}</button>
      <span class="footer-spacer"></span>
      <button class="coffee-pill" id="coffee-pill">Buy me a coffee</button>
    </footer>

    <p class="tray-hint" data-i18n="trayHint">Closing this window keeps the timer running in the tray.</p>
  </section>

  <section class="sub-view hidden" id="view-settings" aria-label="Settings">
    <header class="settings-header">
      <button class="back-button" id="settings-back" aria-label="Back">‹</button>
      <h2 data-i18n="settings">Settings</h2>
      <span class="header-spacer"></span>
    </header>
    <form id="settings-form">
      <div class="settings-group">
        <h3 data-i18n="groupStandUp">Stand Up</h3>
        <label class="setting-row"><span data-i18n="rowSitting">Sitting</span><span class="number-field"><input name="sittingMinutes" type="number" min="1" max="240" required><em data-i18n="unitMin">min</em></span></label>
        <label class="setting-row"><span data-i18n="rowMovement">Movement</span><span class="number-field"><input name="movementMinutes" type="number" min="1" max="240" required><em data-i18n="unitMin">min</em></span></label>
      </div>
      <div class="settings-group">
        <h3 data-i18n="groupPomodoro">Pomodoro</h3>
        <label class="setting-row"><span data-i18n="rowFocus">Focus</span><span class="number-field"><input name="focusMinutes" type="number" min="1" max="240" required><em data-i18n="unitMin">min</em></span></label>
        <label class="setting-row"><span data-i18n="rowShortBreak">Short break</span><span class="number-field"><input name="shortBreakMinutes" type="number" min="1" max="240" required><em data-i18n="unitMin">min</em></span></label>
        <label class="setting-row"><span data-i18n="rowLongBreak">Long break</span><span class="number-field"><input name="longBreakMinutes" type="number" min="1" max="240" required><em data-i18n="unitMin">min</em></span></label>
        <label class="setting-row"><span data-i18n="rowLongBreakEvery">Long break every</span><span class="number-field"><input name="focusSessionsBeforeLongBreak" type="number" min="1" max="12" required><em data-i18n="unitSessions">sessions</em></span></label>
      </div>
      <div class="settings-group">
        <h3 data-i18n="groupGeneral">General</h3>
        <label class="toggle-row"><span data-i18n="toggleLaunch">Launch at login</span><input name="launchAtLogin" type="checkbox"><i></i></label>
        <label class="toggle-row"><span data-i18n="toggleNotifications">Notifications</span><input name="notificationsEnabled" type="checkbox"><i></i></label>
        <label class="toggle-row"><span data-i18n="toggleFullscreen">Full-screen reminders</span><input name="fullscreenRemindersEnabled" type="checkbox"><i></i></label>
        <label class="toggle-row"><span data-i18n="toggleSound">Alert sound</span><input name="alertSoundEnabled" type="checkbox"><i></i></label>
        <label class="toggle-row"><span data-i18n="toggleFacts">Health facts on reminders</span><input name="healthFactsEnabled" type="checkbox"><i></i></label>
        <label class="toggle-row"><span data-i18n="toggleMinimized">Start minimized to tray</span><input name="startMinimizedToTray" type="checkbox"><i></i></label>
      </div>
      <div class="settings-group">
        <h3 data-i18n="groupGoal">Goal</h3>
        <label class="setting-row"><span data-i18n="rowGoal">Standing goal (0 = off)</span><span class="number-field"><input name="standGoalMinutes" type="number" min="0" max="600" required><em data-i18n="unitGoalMin">min/day</em></span></label>
      </div>
      <div class="settings-group">
        <h3 data-i18n="groupLanguage">Language</h3>
        <label class="setting-row"><span data-i18n="groupLanguage">Language</span><span class="select-field"><select name="language"><option value="en">English</option><option value="vi">Tiếng Việt</option></select></span></label>
      </div>
      <div class="settings-group">
        <h3 data-i18n="groupSupport">Support</h3>
        <button class="link-row" id="settings-donate" type="button"><span data-i18n="buyCoffee">Buy me a coffee</span><span aria-hidden="true">›</span></button>
      </div>
      <p class="settings-message" id="settings-message"></p>
      <button class="preview-button" id="preview-reminder" type="button" data-i18n="previewReminder">Preview reminder</button>
      <button class="save-button" type="submit" data-i18n="saveSettings">Save settings</button>
      <p class="footer-note" id="settings-version"></p>
    </form>
  </section>

  <section class="sub-view hidden" id="view-stats" aria-label="Statistics">
    <header class="settings-header">
      <button class="back-button" id="stats-back" aria-label="Back">‹</button>
      <h2 data-i18n="stats">Statistics</h2>
      <span class="header-spacer"></span>
    </header>
    <div class="scope-selector" role="group" aria-label="Scope">
      <button class="mode-button active" data-scope="day" data-i18n="statsDay">Day</button>
      <button class="mode-button" data-scope="week" data-i18n="statsWeek">Week</button>
    </div>
    <p class="stats-total" id="stats-total">0</p>
    <p class="stats-average hidden" id="stats-average"></p>
    <div class="stats-empty hidden" id="stats-empty" data-i18n="noActivity">No activity yet</div>
    <div id="stats-chart"></div>
    <div class="legend" id="stats-legend"></div>
    <div id="stats-rows"></div>
    <div class="danger-zone">
      <button class="preview-button" id="reset-today" type="button" data-i18n="clearToday">Clear today's data</button>
      <button class="danger-button" id="clear-history" type="button" data-i18n="eraseHistory">Erase all history</button>
    </div>
  </section>

  <section class="sub-view hidden" id="view-welcome" aria-label="Welcome">
    <div class="welcome-body">
      <figure class="welcome-meme"><img src="./tom-cruise-programmers.png" alt="Meme contrasting Tom Cruise at 60 clinging to an aircraft with a programmer at 30 holding their sore lower back." /></figure>
      <h2 class="welcome-title" data-i18n="welcomeTitle">Your spine keeps the score</h2>
      <p class="welcome-text" data-i18n="welcomeBody">SittingTime reminds you to stand up every 45 minutes. The meme is funny, back pain isn't.</p>
      <button class="save-button" id="welcome-start" type="button" data-i18n="welcomeStart">Get started</button>
    </div>
  </section>

  <section class="sub-view hidden" id="view-about" aria-label="About">
    <header class="settings-header">
      <button class="back-button" id="about-back" aria-label="Back">‹</button>
      <h2 data-i18n="about">About</h2>
      <span class="header-spacer"></span>
    </header>
    <div class="about-body">
      <h3>SittingTime</h3>
      <p class="about-version" id="about-version"></p>
      <p class="about-madeby"><span data-i18n="madeBy">Developed by</span> <button class="text-link" id="about-author">0xdonniechu</button><span data-i18n="missionSuffix">, on a mission to save spines and discs.</span></p>
      <p class="about-star"><span data-i18n="starNote">If this app helps your spine and discs, please star it on</span> <button class="text-link" id="about-star" data-i18n="starRepo">GitHub</button> <span data-i18n="starThanks">, thank you!</span></p>
      <button class="preview-button" id="about-bug" type="button" data-i18n="reportBug">Report a Bug</button>
      <button class="coffee-pill wide" id="about-donate" type="button" data-i18n="buyCoffee">Buy me a coffee</button>
      <p class="footer-note" id="about-note"></p>
    </div>
  </section>
`;

let lang: Language = "en";
let currentState: TimerSnapshot | null = null;
let currentSettings: SettingsPayload | null = null;
let appInfo: AppInfo | null = null;
let statsCache: StatsSnapshot | null = null;
let statsScope: "day" | "week" = "day";
let refreshTimer: number | undefined;
let refreshInFlight = false;
let calendarTimer: number | undefined;
let pollCount = 0;

const views: Record<ViewName, HTMLElement> = {
  dash: document.querySelector<HTMLElement>("#view-dash")!,
  settings: document.querySelector<HTMLElement>("#view-settings")!,
  stats: document.querySelector<HTMLElement>("#view-stats")!,
  about: document.querySelector<HTMLElement>("#view-about")!,
  welcome: document.querySelector<HTMLElement>("#view-welcome")!,
};

function showView(name: ViewName): void {
  (Object.keys(views) as ViewName[]).forEach((key) => {
    views[key].classList.toggle("hidden", key !== name);
  });
  if (name === "stats") void refreshStats();
}

const modeTitle = document.querySelector<HTMLElement>("#mode-title")!;
const modeAfter = document.querySelector<HTMLElement>("#mode-after")!;
const timerEl = document.querySelector<HTMLElement>("#timer")!;
const progressFill = document.querySelector<HTMLElement>("#progress-fill")!;
const sessionLabel = document.querySelector<HTMLElement>("#session-label")!;
const statusEl = document.querySelector<HTMLElement>("#status")!;
const cycleEl = document.querySelector<HTMLElement>("#cycle")!;
const startButton = document.querySelector<HTMLButtonElement>("#start-button")!;
const skipButton = document.querySelector<HTMLButtonElement>("#skip-button")!;
const settingsForm = document.querySelector<HTMLFormElement>("#settings-form")!;
const settingsMessage = document.querySelector<HTMLElement>("#settings-message")!;
const today = document.querySelector<HTMLElement>("#today")!;
const todaySolar = document.querySelector<HTMLElement>("#today-solar")!;
const todayLunar = document.querySelector<HTMLElement>("#today-lunar")!;
const zodiacIcon = document.querySelector<HTMLImageElement>("#zodiac-icon")!;
// The macOS art set has no fallback glyph: a missing file hides the icon
// instead of showing a broken image (macOS shows text only in that case).
zodiacIcon.addEventListener("error", () => zodiacIcon.classList.add("hidden"));
const weekLabel = document.querySelector<HTMLElement>("#week-label")!;
const weekNumber = document.querySelector<HTMLElement>("#week-number")!;
const weekMonth = document.querySelector<HTMLElement>("#week-month")!;
const todaySitting = document.querySelector<HTMLElement>("#today-sitting")!;
const todayStanding = document.querySelector<HTMLElement>("#today-standing")!;
const todayRest = document.querySelector<HTMLElement>("#today-rest")!;
const breaksLine = document.querySelector<HTMLElement>("#breaks-line")!;
const goalProgress = document.querySelector<HTMLElement>("#goal-progress")!;
const goalFill = document.querySelector<HTMLElement>("#goal-fill")!;
const goalLabel = document.querySelector<HTMLElement>("#goal-label")!;
const statsTotal = document.querySelector<HTMLElement>("#stats-total")!;
const statsAverage = document.querySelector<HTMLElement>("#stats-average")!;
const statsEmpty = document.querySelector<HTMLElement>("#stats-empty")!;
const statsChart = document.querySelector<HTMLElement>("#stats-chart")!;
const statsLegend = document.querySelector<HTMLElement>("#stats-legend")!;
const statsRows = document.querySelector<HTMLElement>("#stats-rows")!;

const sessionKeys: Record<SessionKind, string> = {
  focus: "sessionFocus",
  shortBreak: "sessionShortBreak",
  longBreak: "sessionLongBreak",
  sitting: "sessionSitting",
  move: "sessionMove",
};

/** Rewrites every static label for the active language. Dynamic content
 * re-renders through render()/renderStats(). */
function applyI18n(): void {
  document.querySelectorAll<HTMLElement>("[data-i18n]").forEach((el) => {
    const key = el.dataset.i18n;
    delete el.dataset.armed;
    if (key) el.textContent = t(lang, key);
  });
  document.querySelector<HTMLButtonElement>("#footer-stats")!.setAttribute("aria-label", t(lang, "stats"));
  document.querySelector<HTMLButtonElement>("#footer-settings")!.setAttribute("aria-label", t(lang, "settings"));
  document.querySelector<HTMLButtonElement>("#footer-about")!.setAttribute("aria-label", t(lang, "about"));
  if (currentState) render(currentState);
  if (!views.stats.classList.contains("hidden")) renderStats();
  if (!views.about.classList.contains("hidden")) renderAbout();
}

function renderCalendar(day: CalendarDay): void {
  const solar = `${weekdayNames[day.weekday]}, ${day.solarDay}/${day.solarMonth}/${day.solarYear}`;
  const month = day.lunarLeap ? `${day.lunarMonth} nhuận` : `${day.lunarMonth}`;
  const full = `${solar} (tuần ${day.isoWeek}) · Âm lịch ${day.lunarDay}/${month} năm ${day.lunarYearName}`;
  weekNumber.textContent = `W${day.isoWeek}`;
  weekMonth.textContent = monthAbbreviations[day.solarMonth - 1];
  todaySolar.textContent = String(day.solarDay);
  todayLunar.textContent = `${day.lunarDay}/${day.lunarMonth}${day.lunarLeap ? "N" : ""}`;
  zodiacIcon.classList.remove("hidden");
  zodiacIcon.src = `./zodiac/${day.zodiacAnimal}.png`;
  today.title = full;
  weekLabel.title = full;
  zodiacIcon.title = full;
  today.setAttribute("aria-label", full);
}

async function refreshCalendar(): Promise<void> {
  window.clearTimeout(calendarTimer);
  try {
    renderCalendar(await invoke<CalendarDay>("get_calendar_day"));
  } catch (error) {
    console.error(error);
  } finally {
    calendarTimer = window.setTimeout(refreshCalendar, 60_000);
  }
}

function standUpCycleText(): string {
  const sitting = currentSettings?.sittingMinutes ?? 45;
  const movement = currentSettings?.movementMinutes ?? 5;
  return t(lang, "standUpCycle", { sitting, movement });
}

/// "after 45 minutes" beside the mode title: the work-session length of the
/// active mode, following the settings. Plain minutes, never compounding
/// into hours; clock format here would read as a time of day.
function modeAfterText(isPomodoro: boolean): string {
  const minutes = isPomodoro
    ? (currentSettings?.focusMinutes ?? 25)
    : (currentSettings?.sittingMinutes ?? 45);
  if (lang === "en" && minutes === 1) return t(lang, "modeAfterOne");
  return t(lang, "modeAfterOther", { n: minutes });
}

function formatTime(seconds: number): string {
  const safeSeconds = Math.max(0, Math.floor(seconds));
  const minutes = Math.floor(safeSeconds / 60);
  const remainder = safeSeconds % 60;
  if (minutes >= 60) {
    const hours = Math.floor(minutes / 60);
    return `${hours}:${String(minutes % 60).padStart(2, "0")}:${String(remainder).padStart(2, "0")}`;
  }
  return `${String(minutes).padStart(2, "0")}:${String(remainder).padStart(2, "0")}`;
}

function breaksText(record: DayRecord): string {
  const longest = formatTime(record.longestSitSeconds);
  if (lang === "en" && record.breakCount === 1) {
    return t(lang, "breaksLineOne", { count: 1, longest });
  }
  return t(lang, "breaksLineOther", { count: record.breakCount, longest });
}

function renderToday(): void {
  const record = statsCache?.today;
  todaySitting.textContent = formatTime(record?.sittingSeconds ?? 0);
  todayStanding.textContent = formatTime(record?.standingSeconds ?? 0);
  todayRest.textContent = formatTime(record?.pausedSeconds ?? 0);
  breaksLine.textContent = record ? breaksText(record) : "";
  const goal = currentSettings?.standGoalMinutes ?? 0;
  if (goal > 0 && record) {
    goalProgress.classList.remove("hidden");
    const ratio = Math.min(1, record.standingSeconds / (goal * 60));
    goalFill.style.width = `${ratio * 100}%`;
    goalLabel.textContent = t(lang, "goalProgress", { goal: formatTime(goal * 60) });
  } else {
    goalProgress.classList.add("hidden");
  }
}

function render(state: TimerSnapshot): void {
  currentState = state;
  const isPomodoro = state.selectedMode === "pomodoro";
  const currentFocusNumber = (state.completedFocusSessions % state.focusSessionsBeforeLongBreak) + 1;
  const done = state.totalSeconds > 0 ? 1 - state.remainingSeconds / state.totalSeconds : 0;

  document.body.dataset.session = state.session;
  progressFill.style.width = `${Math.min(100, Math.max(0, done * 100))}%`;
  modeTitle.textContent = isPomodoro ? t(lang, "modePomodoro") : t(lang, "modeStandUp");
  modeAfter.textContent = modeAfterText(isPomodoro);
  timerEl.textContent = formatTime(state.remainingSeconds);
  sessionLabel.textContent = t(lang, sessionKeys[state.session]);
  statusEl.textContent =
    state.status === "running"
      ? t(lang, "statusRunning")
      : state.status === "paused"
        ? t(lang, "statusPaused")
        : t(lang, "statusReady");
  cycleEl.textContent = isPomodoro
    ? t(lang, "cycleSession", { i: currentFocusNumber, n: state.focusSessionsBeforeLongBreak })
    : standUpCycleText();
  startButton.textContent =
    state.status === "running"
      ? t(lang, "pause")
      : state.status === "paused"
        ? t(lang, "resume")
        : t(lang, "start");
  skipButton.textContent = t(lang, "skip");

  document.querySelectorAll<HTMLButtonElement>(".mode-button[data-mode]").forEach((button) => {
    button.classList.toggle("active", button.dataset.mode === state.selectedMode);
  });
  document.querySelectorAll<HTMLButtonElement>(".posture-button[data-posture]").forEach((button) => {
    const active = button.dataset.posture === state.posture;
    button.classList.toggle("active", active);
    button.setAttribute("aria-pressed", active ? "true" : "false");
  });
  renderToday();
}

async function refreshStats(): Promise<void> {
  try {
    statsCache = await invoke<StatsSnapshot>("get_stats");
  } catch (error) {
    console.error(error);
    return;
  }
  renderToday();
  if (!views.stats.classList.contains("hidden")) renderStats();
}

const BAR_COLORS = { sitting: "#e8830c", standing: "#2da44e", rest: "#9aa0a6" };

function legendRow(labelKey: string, color: string, seconds: number): string {
  return `<div class="legend-row"><span class="dot" style="background:${color}"></span><span>${t(lang, labelKey)}</span><b>${formatTime(seconds)}</b></div>`;
}

function renderStats(): void {
  const snapshot = statsCache;
  document.querySelectorAll<HTMLButtonElement>(".mode-button[data-scope]").forEach((button) => {
    button.classList.toggle("active", button.dataset.scope === statsScope);
  });
  if (!snapshot) {
    statsTotal.textContent = formatTime(0);
    return;
  }
  const week = snapshot.week;
  const sit = statsScope === "day" ? snapshot.today.sittingSeconds : week.reduce((sum, day) => sum + day.sittingSeconds, 0);
  const stand = statsScope === "day" ? snapshot.today.standingSeconds : week.reduce((sum, day) => sum + day.standingSeconds, 0);
  const rest = statsScope === "day" ? snapshot.today.pausedSeconds : week.reduce((sum, day) => sum + day.pausedSeconds, 0);
  const total = sit + stand + rest;

  statsTotal.textContent = formatTime(total);
  if (statsScope === "week") {
    statsAverage.classList.remove("hidden");
    statsAverage.textContent = t(lang, "dailyAverage", { duration: formatTime(total / 7) });
  } else {
    statsAverage.classList.add("hidden");
  }
  statsEmpty.classList.toggle("hidden", total > 0);
  statsChart.innerHTML = "";
  statsRows.innerHTML = "";

  if (total > 0) {
    if (statsScope === "day") {
      statsChart.appendChild(renderDayChart(snapshot.today));
      const breaks = document.createElement("p");
      breaks.className = "breaks-line";
      breaks.textContent = breaksText(snapshot.today);
      statsRows.appendChild(breaks);
      const goal = currentSettings?.standGoalMinutes ?? 0;
      if (goal > 0) {
        const wrap = document.createElement("div");
        wrap.className = "goal-progress";
        const ratio = Math.min(1, snapshot.today.standingSeconds / (goal * 60));
        wrap.innerHTML = `<div class="goal-bar" aria-hidden="true"><span style="width:${ratio * 100}%"></span></div><p>${t(lang, "goalProgress", { goal: formatTime(goal * 60) })}</p>`;
        statsRows.appendChild(wrap);
      }
    } else {
      statsChart.appendChild(renderWeekChart(week));
      const title = document.createElement("h3");
      title.className = "rows-title";
      title.textContent = t(lang, "last7days");
      statsRows.appendChild(title);
      [...week].reverse().forEach((day) => statsRows.appendChild(renderWeekRow(day)));
    }
  }

  statsLegend.innerHTML =
    legendRow("chartSitting", BAR_COLORS.sitting, sit) +
    legendRow("chartStanding", BAR_COLORS.standing, stand) +
    legendRow("chartRest", BAR_COLORS.rest, rest);
}

function renderDayChart(today: DayRecord): HTMLElement {
  const wrap = document.createElement("div");
  wrap.className = "bars";
  const hours = today.hourly.length === 24 ? today.hourly : Array.from({ length: 24 }, () => ({ sittingSeconds: 0, standingSeconds: 0, pausedSeconds: 0 }));
  const max = Math.max(1, ...hours.map((h) => h.sittingSeconds + h.standingSeconds + h.pausedSeconds));
  hours.forEach((hour) => {
    const col = document.createElement("div");
    col.className = "bar-col";
    const total = hour.sittingSeconds + hour.standingSeconds + hour.pausedSeconds;
    if (total > 0) {
      ([
        ["sittingSeconds", BAR_COLORS.sitting],
        ["standingSeconds", BAR_COLORS.standing],
        ["pausedSeconds", BAR_COLORS.rest],
      ] as const).forEach(([key, color]) => {
        if (hour[key] > 0) {
          const seg = document.createElement("span");
          seg.style.height = `${(hour[key] / max) * 100}%`;
          seg.style.background = color;
          col.appendChild(seg);
        }
      });
    }
    wrap.appendChild(col);
  });
  const axis = document.createElement("div");
  axis.className = "bars-axis";
  [0, 6, 12, 18].forEach((hour) => {
    const tick = document.createElement("span");
    tick.textContent = String(hour);
    tick.style.left = `${(hour / 24) * 100}%`;
    axis.appendChild(tick);
  });
  const unit = document.createElement("p");
  unit.className = "bars-unit";
  unit.textContent = t(lang, "yAxisHours");
  wrap.appendChild(axis);
  wrap.appendChild(unit);
  return wrap;
}

function renderWeekChart(week: WeekDay[]): HTMLElement {
  const wrap = document.createElement("div");
  wrap.className = "bars week-bars";
  const max = Math.max(1, ...week.map((day) => day.sittingSeconds + day.standingSeconds + day.pausedSeconds));
  week.forEach((day) => {
    const col = document.createElement("div");
    col.className = "bar-col";
    col.title = `${day.label}: ${formatTime(day.sittingSeconds + day.standingSeconds + day.pausedSeconds)}`;
    const total = day.sittingSeconds + day.standingSeconds + day.pausedSeconds;
    if (total > 0) {
      ([
        [day.sittingSeconds, BAR_COLORS.sitting],
        [day.standingSeconds, BAR_COLORS.standing],
        [day.pausedSeconds, BAR_COLORS.rest],
      ] as const).forEach(([value, color]) => {
        if (value > 0) {
          const seg = document.createElement("span");
          seg.style.height = `${(value / max) * 100}%`;
          seg.style.background = color;
          col.appendChild(seg);
        }
      });
    }
    const label = document.createElement("span");
    label.className = "bar-label";
    label.textContent = day.label;
    col.appendChild(label);
    wrap.appendChild(col);
  });
  return wrap;
}

function renderWeekRow(day: WeekDay): HTMLElement {
  const row = document.createElement("div");
  row.className = "week-row";
  const total = day.sittingSeconds + day.standingSeconds + day.pausedSeconds;
  let bar = `<span class="week-bar-empty"></span>`;
  if (total > 0) {
    const pct = (value: number): string => `${(value / total) * 100}%`;
    bar = `<span class="week-bar">
      <span style="width:${pct(day.sittingSeconds)};background:${BAR_COLORS.sitting}"></span><span style="width:${pct(day.standingSeconds)};background:${BAR_COLORS.standing}"></span><span style="width:${pct(day.pausedSeconds)};background:${BAR_COLORS.rest}"></span>
    </span>`;
  }
  row.innerHTML = `<span class="week-day">${day.label}</span>${bar}<b>${formatTime(total)}</b>`;
  return row;
}

function renderAbout(): void {
  document.querySelector<HTMLElement>("#about-version")!.textContent = appInfo ? `v${appInfo.version}` : "";
  document.querySelector<HTMLElement>("#about-note")!.textContent = appInfo
    ? t(lang, "footerNote", { version: appInfo.version })
    : "";
  document.querySelector<HTMLElement>("#settings-version")!.textContent = appInfo
    ? t(lang, "footerNote", { version: appInfo.version })
    : "";
}

async function runCommand(command: string, args?: Record<string, unknown>): Promise<void> {
  try {
    render(await invoke<TimerSnapshot>(command, args));
  } catch (error) {
    statusEl.textContent = t(lang, "somethingWrong");
    console.error(error);
  }
}

async function refreshFromRust(): Promise<void> {
  if (refreshInFlight) return;
  refreshInFlight = true;
  try {
    render(await invoke<TimerSnapshot>("get_timer_state"));
  } catch (error) {
    console.error(error);
  } finally {
    refreshInFlight = false;
    pollCount += 1;
    // The 250 ms poll also carries the stats refresh (~5 s cadence) so no
    // clock API is needed in the frontend.
    if (pollCount % 20 === 0) void refreshStats();
    refreshTimer = window.setTimeout(refreshFromRust, 250);
  }
}

function field<T extends HTMLInputElement | HTMLSelectElement>(name: string): T {
  return settingsForm.elements.namedItem(name) as T;
}

async function openSettings(): Promise<void> {
  try {
    const settings = await invoke<SettingsPayload>("get_settings");
    currentSettings = settings;
    if (settings.language !== lang) {
      lang = settings.language;
    }
    applyI18n();
    field("sittingMinutes").value = String(settings.sittingMinutes);
    field("movementMinutes").value = String(settings.movementMinutes);
    field("focusMinutes").value = String(settings.focusMinutes);
    field("shortBreakMinutes").value = String(settings.shortBreakMinutes);
    field("longBreakMinutes").value = String(settings.longBreakMinutes);
    field("focusSessionsBeforeLongBreak").value = String(settings.focusSessionsBeforeLongBreak);
    field<HTMLInputElement>("launchAtLogin").checked = settings.launchAtLogin;
    field<HTMLInputElement>("notificationsEnabled").checked = settings.notificationsEnabled;
    field<HTMLInputElement>("fullscreenRemindersEnabled").checked = settings.fullscreenRemindersEnabled;
    field<HTMLInputElement>("alertSoundEnabled").checked = settings.alertSoundEnabled;
    field<HTMLInputElement>("healthFactsEnabled").checked = settings.healthFactsEnabled;
    field<HTMLInputElement>("startMinimizedToTray").checked = settings.startMinimizedToTray;
    field("standGoalMinutes").value = String(settings.standGoalMinutes);
    field<HTMLSelectElement>("language").value = settings.language;
    settingsMessage.textContent = "";
    showView("settings");
  } catch (error) {
    statusEl.textContent = t(lang, "couldNotOpen");
    console.error(error);
  }
}

function armConfirm(button: HTMLButtonElement, labelKey: string, confirmKey: string, action: () => void): void {
  if (button.dataset.armed === "1") {
    delete button.dataset.armed;
    button.textContent = t(lang, labelKey);
    action();
    return;
  }
  button.dataset.armed = "1";
  button.textContent = t(lang, confirmKey);
  window.setTimeout(() => {
    if (button.dataset.armed === "1") {
      delete button.dataset.armed;
      button.textContent = t(lang, labelKey);
    }
  }, 3000);
}

async function openExternal(url: string | undefined): Promise<void> {
  if (!url) return;
  try {
    await openUrl(url);
  } catch (error) {
    console.error(error);
  }
}

startButton.addEventListener("click", () => {
  void runCommand(currentState?.status === "running" ? "pause_timer" : "start_timer");
});

skipButton.addEventListener("click", () => void runCommand("skip_session"));

document.querySelectorAll<HTMLButtonElement>(".mode-button[data-mode]").forEach((button) => {
  button.addEventListener("click", () => {
    void runCommand("select_mode", { mode: button.dataset.mode });
  });
});

document.querySelectorAll<HTMLButtonElement>(".posture-button[data-posture]").forEach((button) => {
  button.addEventListener("click", () => {
    void runCommand("set_posture", { posture: button.dataset.posture });
  });
});

document.querySelectorAll<HTMLButtonElement>(".mode-button[data-scope]").forEach((button) => {
  button.addEventListener("click", () => {
    statsScope = button.dataset.scope === "week" ? "week" : "day";
    renderStats();
  });
});

document.querySelector<HTMLButtonElement>("#footer-stats")!.addEventListener("click", () => showView("stats"));
document.querySelector<HTMLButtonElement>("#footer-settings")!.addEventListener("click", () => void openSettings());
document.querySelector<HTMLButtonElement>("#footer-about")!.addEventListener("click", () => {
  renderAbout();
  showView("about");
});
document.querySelector<HTMLButtonElement>("#coffee-pill")!.addEventListener("click", () => void openExternal(appInfo?.donateUrl));
document.querySelector<HTMLButtonElement>("#settings-back")!.addEventListener("click", () => showView("dash"));
document.querySelector<HTMLButtonElement>("#stats-back")!.addEventListener("click", () => showView("dash"));
document.querySelector<HTMLButtonElement>("#about-back")!.addEventListener("click", () => showView("dash"));
document.querySelector<HTMLButtonElement>("#settings-donate")!.addEventListener("click", () => void openExternal(appInfo?.donateUrl));
document.querySelector<HTMLButtonElement>("#about-donate")!.addEventListener("click", () => void openExternal(appInfo?.donateUrl));
document.querySelector<HTMLButtonElement>("#about-author")!.addEventListener("click", () => void openExternal(appInfo?.authorUrl));
document.querySelector<HTMLButtonElement>("#about-star")!.addEventListener("click", () => void openExternal(appInfo?.repoUrl));
document.querySelector<HTMLButtonElement>("#welcome-start")!.addEventListener("click", () => {
  if (!currentSettings) {
    showView("dash");
    return;
  }
  const payload = { ...currentSettings, welcomed: true };
  void invoke<TimerSnapshot>("save_settings", { settings: payload }).then(
    (snapshot) => {
      currentSettings = payload;
      render(snapshot);
      showView("dash");
    },
    console.error,
  );
});
document.querySelector<HTMLButtonElement>("#about-bug")!.addEventListener("click", () => void openExternal(appInfo?.bugUrl));
document.querySelector<HTMLButtonElement>("#preview-reminder")!.addEventListener("click", () => {
  void invoke("preview_reminder");
});
document.querySelector<HTMLButtonElement>("#reset-today")!.addEventListener("click", (event) => {
  const button = event.currentTarget as HTMLButtonElement;
  armConfirm(button, "clearToday", "confirmClearToday", () => {
    void invoke<StatsSnapshot>("reset_today").then(
      (snapshot) => {
        statsCache = snapshot;
        renderToday();
        renderStats();
      },
      console.error,
    );
  });
});
document.querySelector<HTMLButtonElement>("#clear-history")!.addEventListener("click", (event) => {
  const button = event.currentTarget as HTMLButtonElement;
  armConfirm(button, "eraseHistory", "confirmEraseHistory", () => {
    void invoke<StatsSnapshot>("clear_history").then(
      (snapshot) => {
        statsCache = snapshot;
        renderToday();
        renderStats();
      },
      console.error,
    );
  });
});

settingsForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const payload: SettingsPayload = {
    sittingMinutes: Number(field("sittingMinutes").value),
    movementMinutes: Number(field("movementMinutes").value),
    focusMinutes: Number(field("focusMinutes").value),
    shortBreakMinutes: Number(field("shortBreakMinutes").value),
    longBreakMinutes: Number(field("longBreakMinutes").value),
    focusSessionsBeforeLongBreak: Number(field("focusSessionsBeforeLongBreak").value),
    launchAtLogin: field<HTMLInputElement>("launchAtLogin").checked,
    notificationsEnabled: field<HTMLInputElement>("notificationsEnabled").checked,
    fullscreenRemindersEnabled: field<HTMLInputElement>("fullscreenRemindersEnabled").checked,
    alertSoundEnabled: field<HTMLInputElement>("alertSoundEnabled").checked,
    healthFactsEnabled: field<HTMLInputElement>("healthFactsEnabled").checked,
    startMinimizedToTray: field<HTMLInputElement>("startMinimizedToTray").checked,
    language: field<HTMLSelectElement>("language").value as Language,
    standGoalMinutes: Number(field("standGoalMinutes").value),
    welcomed: currentSettings?.welcomed ?? true,
  };

  settingsMessage.textContent = t(lang, "saving");
  try {
    const autostartEnabled = await isEnabled();
    if (payload.launchAtLogin && !autostartEnabled) await enable();
    if (!payload.launchAtLogin && autostartEnabled) await disable();
    if (payload.notificationsEnabled && !(await isPermissionGranted())) {
      payload.notificationsEnabled = (await requestPermission()) === "granted";
      field<HTMLInputElement>("notificationsEnabled").checked = payload.notificationsEnabled;
    }
    render(await invoke<TimerSnapshot>("save_settings", { settings: payload }));
    currentSettings = payload;
    lang = payload.language;
    applyI18n();
    settingsMessage.textContent = t(lang, "saved");
    window.setTimeout(() => showView("dash"), 450);
  } catch (error) {
    settingsMessage.textContent = String(error);
    console.error(error);
  }
});

void listen<TimerSnapshot>("timer-state", (event) => render(event.payload));
void listen("open-settings", () => {
  void openSettings();
});

document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "visible") {
    window.clearTimeout(refreshTimer);
    void refreshFromRust();
    void refreshCalendar();
    void refreshStats();
  }
});

async function boot(): Promise<void> {
  try {
    appInfo = await invoke<AppInfo>("get_app_info");
  } catch (error) {
    console.error(error);
  }
  try {
    const settings = await invoke<SettingsPayload>("get_settings");
    currentSettings = settings;
    lang = settings.language;
  } catch (error) {
    console.error(error);
  }
  applyI18n();
  renderAbout();
  if (currentSettings && !currentSettings.welcomed) showView("welcome");
  void refreshFromRust();
  void refreshCalendar();
  void refreshStats();
}

void boot();
