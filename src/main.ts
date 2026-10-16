import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { disable, enable, isEnabled } from "@tauri-apps/plugin-autostart";
import { isPermissionGranted, requestPermission } from "@tauri-apps/plugin-notification";
import "@fontsource-variable/inter";
import "./styles.css";

type TimerMode = "pomodoro" | "standUp";
type SessionKind = "focus" | "shortBreak" | "longBreak" | "sitting" | "move";
type TimerStatus = "idle" | "running" | "paused";

interface TimerSnapshot {
  selectedMode: TimerMode;
  session: SessionKind;
  status: TimerStatus;
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
}

const weekdayNames = ["Chủ Nhật", "Thứ Hai", "Thứ Ba", "Thứ Tư", "Thứ Năm", "Thứ Sáu", "Thứ Bảy"];
const monthAbbreviations = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

const sessionLabels: Record<SessionKind, string> = {
  focus: "Focus",
  shortBreak: "Short Break",
  longBreak: "Long Break",
  sitting: "Sitting",
  move: "Move",
};

const app = document.querySelector<HTMLDivElement>("#app");
if (!app) throw new Error("App root was not found");

app.innerHTML = `
  <section class="shell" aria-label="Productivity timer">
    <header class="topbar">
      <div>
        <p class="eyebrow">SITTINGTIME</p>
        <h1 id="mode-title">Pomodoro</h1>
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
        <button class="icon-button" id="settings-button" aria-label="Open settings">
          <!-- Lucide "settings" icon, lucide-static v0.460.0, ISC License, (c) Lucide Contributors -->
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/>
            <circle cx="12" cy="12" r="3"/>
          </svg>
        </button>
      </div>
    </header>

    <div class="timer-panel" aria-live="polite">
      <div class="timer" id="timer">25:00</div>
      <div class="progress" aria-hidden="true"><span id="progress-fill"></span></div>
      <div class="session-label" id="session-label">Focus</div>
      <div class="status" id="status">Ready</div>
      <div class="cycle" id="cycle">Session 1 of 4</div>
    </div>

    <div class="controls">
      <button class="primary-button" id="start-button">Start</button>
      <button class="secondary-button" id="skip-button">Skip</button>
    </div>

    <div class="mode-selector" role="group" aria-label="Timer mode">
      <button class="mode-button active" data-mode="pomodoro">Pomodoro</button>
      <button class="mode-button" data-mode="standUp">Stand Up</button>
    </div>

    <p class="tray-hint">Closing this window keeps the timer running in the tray.</p>
  </section>

  <section class="settings-view hidden" id="settings-view" aria-label="Settings">
    <header class="settings-header">
      <button class="back-button" id="settings-back" aria-label="Back">‹</button>
      <h2>Settings</h2>
      <span class="header-spacer"></span>
    </header>
    <form id="settings-form">
      <div class="settings-group">
        <h3>Stand Up</h3>
        <label class="setting-row"><span>Sitting</span><span class="number-field"><input name="sittingMinutes" type="number" min="1" max="240" required><em>min</em></span></label>
        <label class="setting-row"><span>Movement</span><span class="number-field"><input name="movementMinutes" type="number" min="1" max="240" required><em>min</em></span></label>
      </div>
      <div class="settings-group">
        <h3>Pomodoro</h3>
        <label class="setting-row"><span>Focus</span><span class="number-field"><input name="focusMinutes" type="number" min="1" max="240" required><em>min</em></span></label>
        <label class="setting-row"><span>Short break</span><span class="number-field"><input name="shortBreakMinutes" type="number" min="1" max="240" required><em>min</em></span></label>
        <label class="setting-row"><span>Long break</span><span class="number-field"><input name="longBreakMinutes" type="number" min="1" max="240" required><em>min</em></span></label>
        <label class="setting-row"><span>Long break every</span><span class="number-field"><input name="focusSessionsBeforeLongBreak" type="number" min="1" max="12" required><em>sessions</em></span></label>
      </div>
      <div class="settings-group">
        <h3>General</h3>
        <label class="toggle-row"><span>Launch at login</span><input name="launchAtLogin" type="checkbox"><i></i></label>
        <label class="toggle-row"><span>Notifications</span><input name="notificationsEnabled" type="checkbox"><i></i></label>
        <label class="toggle-row"><span>Full-screen reminders</span><input name="fullscreenRemindersEnabled" type="checkbox"><i></i></label>
        <label class="toggle-row"><span>Alert sound</span><input name="alertSoundEnabled" type="checkbox"><i></i></label>
        <label class="toggle-row"><span>Health facts on reminders</span><input name="healthFactsEnabled" type="checkbox"><i></i></label>
        <label class="toggle-row"><span>Start minimized to tray</span><input name="startMinimizedToTray" type="checkbox"><i></i></label>
      </div>
      <p class="settings-message" id="settings-message"></p>
      <button class="preview-button" id="preview-reminder" type="button">Preview reminder</button>
      <button class="save-button" type="submit">Save settings</button>
    </form>
  </section>
`;

const modeTitle = document.querySelector<HTMLElement>("#mode-title")!;
const timer = document.querySelector<HTMLElement>("#timer")!;
const progressFill = document.querySelector<HTMLElement>("#progress-fill")!;
const sessionLabel = document.querySelector<HTMLElement>("#session-label")!;
const status = document.querySelector<HTMLElement>("#status")!;
const cycle = document.querySelector<HTMLElement>("#cycle")!;
const startButton = document.querySelector<HTMLButtonElement>("#start-button")!;
const skipButton = document.querySelector<HTMLButtonElement>("#skip-button")!;
const settingsButton = document.querySelector<HTMLButtonElement>("#settings-button")!;
const shell = document.querySelector<HTMLElement>(".shell")!;
const settingsView = document.querySelector<HTMLElement>("#settings-view")!;
const settingsForm = document.querySelector<HTMLFormElement>("#settings-form")!;
const settingsMessage = document.querySelector<HTMLElement>("#settings-message")!;

let currentState: TimerSnapshot | null = null;
let refreshTimer: number | undefined;
let refreshInFlight = false;
let standUpCycleText = "";
let calendarTimer: number | undefined;

const today = document.querySelector<HTMLElement>("#today")!;
const todaySolar = document.querySelector<HTMLElement>("#today-solar")!;
const todayLunar = document.querySelector<HTMLElement>("#today-lunar")!;
const weekLabel = document.querySelector<HTMLElement>("#week-label")!;
const weekNumber = document.querySelector<HTMLElement>("#week-number")!;
const weekMonth = document.querySelector<HTMLElement>("#week-month")!;

function renderCalendar(day: CalendarDay): void {
  const solar = `${weekdayNames[day.weekday]}, ${day.solarDay}/${day.solarMonth}/${day.solarYear}`;
  const month = day.lunarLeap ? `${day.lunarMonth} nhuận` : `${day.lunarMonth}`;
  const full = `${solar} (tuần ${day.isoWeek}) · Âm lịch ${day.lunarDay}/${month} năm ${day.lunarYearName}`;
  weekNumber.textContent = `W${day.isoWeek}`;
  weekMonth.textContent = monthAbbreviations[day.solarMonth - 1];
  todaySolar.textContent = String(day.solarDay);
  todayLunar.textContent = `${day.lunarDay}/${day.lunarMonth}${day.lunarLeap ? "N" : ""}`;
  today.title = full;
  weekLabel.title = full;
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

function setStandUpCycleText(settings: SettingsPayload): void {
  standUpCycleText = `${settings.sittingMinutes} min work · ${settings.movementMinutes} min move`;
  if (currentState) render(currentState);
}

function formatTime(seconds: number): string {
  const safeSeconds = Math.max(0, Math.floor(seconds));
  const minutes = Math.floor(safeSeconds / 60);
  const remainder = safeSeconds % 60;
  return `${String(minutes).padStart(2, "0")}:${String(remainder).padStart(2, "0")}`;
}

function render(state: TimerSnapshot): void {
  currentState = state;
  const isPomodoro = state.selectedMode === "pomodoro";
  const currentFocusNumber = (state.completedFocusSessions % state.focusSessionsBeforeLongBreak) + 1;

  const done = state.totalSeconds > 0 ? 1 - state.remainingSeconds / state.totalSeconds : 0;

  document.body.dataset.session = state.session;
  progressFill.style.width = `${Math.min(100, Math.max(0, done * 100))}%`;
  modeTitle.textContent = isPomodoro ? "Pomodoro" : "Stand Up";
  timer.textContent = formatTime(state.remainingSeconds);
  sessionLabel.textContent = sessionLabels[state.session];
  status.textContent = state.status === "running" ? "In progress" : state.status === "paused" ? "Paused" : "Ready";
  cycle.textContent = isPomodoro ? `Session ${currentFocusNumber} of ${state.focusSessionsBeforeLongBreak}` : standUpCycleText;
  startButton.textContent = state.status === "running" ? "Pause" : state.status === "paused" ? "Resume" : "Start";

  document.querySelectorAll<HTMLButtonElement>(".mode-button").forEach((button) => {
    button.classList.toggle("active", button.dataset.mode === state.selectedMode);
  });
}

async function runCommand(command: string, args?: Record<string, unknown>): Promise<void> {
  try {
    render(await invoke<TimerSnapshot>(command, args));
  } catch (error) {
    status.textContent = "Something went wrong";
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
    refreshTimer = window.setTimeout(refreshFromRust, 250);
  }
}

startButton.addEventListener("click", () => {
  void runCommand(currentState?.status === "running" ? "pause_timer" : "start_timer");
});

skipButton.addEventListener("click", () => void runCommand("skip_session"));

document.querySelectorAll<HTMLButtonElement>(".mode-button").forEach((button) => {
  button.addEventListener("click", () => {
    void runCommand("select_mode", { mode: button.dataset.mode });
  });
});

settingsButton.addEventListener("click", () => {
  void openSettings();
});

function field<T extends HTMLInputElement>(name: string): T {
  return settingsForm.elements.namedItem(name) as T;
}

async function openSettings(): Promise<void> {
  try {
    const settings = await invoke<SettingsPayload>("get_settings");
    setStandUpCycleText(settings);
    field("sittingMinutes").value = String(settings.sittingMinutes);
    field("movementMinutes").value = String(settings.movementMinutes);
    field("focusMinutes").value = String(settings.focusMinutes);
    field("shortBreakMinutes").value = String(settings.shortBreakMinutes);
    field("longBreakMinutes").value = String(settings.longBreakMinutes);
    field("focusSessionsBeforeLongBreak").value = String(settings.focusSessionsBeforeLongBreak);
    field("launchAtLogin").checked = settings.launchAtLogin;
    field("notificationsEnabled").checked = settings.notificationsEnabled;
    field("fullscreenRemindersEnabled").checked = settings.fullscreenRemindersEnabled;
    field("alertSoundEnabled").checked = settings.alertSoundEnabled;
    field("healthFactsEnabled").checked = settings.healthFactsEnabled;
    field("startMinimizedToTray").checked = settings.startMinimizedToTray;
    settingsMessage.textContent = "";
    shell.classList.add("hidden");
    settingsView.classList.remove("hidden");
  } catch (error) {
    status.textContent = "Could not open settings";
    console.error(error);
  }
}

function closeSettings(): void {
  settingsView.classList.add("hidden");
  shell.classList.remove("hidden");
}

document.querySelector<HTMLButtonElement>("#settings-back")!.addEventListener("click", closeSettings);
document.querySelector<HTMLButtonElement>("#preview-reminder")!.addEventListener("click", () => {
  void invoke("preview_reminder");
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
    launchAtLogin: field("launchAtLogin").checked,
    notificationsEnabled: field("notificationsEnabled").checked,
    fullscreenRemindersEnabled: field("fullscreenRemindersEnabled").checked,
    alertSoundEnabled: field("alertSoundEnabled").checked,
    healthFactsEnabled: field("healthFactsEnabled").checked,
    startMinimizedToTray: field("startMinimizedToTray").checked,
  };

  settingsMessage.textContent = "Saving…";
  try {
    const autostartEnabled = await isEnabled();
    if (payload.launchAtLogin && !autostartEnabled) await enable();
    if (!payload.launchAtLogin && autostartEnabled) await disable();
    if (payload.notificationsEnabled && !(await isPermissionGranted())) {
      payload.notificationsEnabled = (await requestPermission()) === "granted";
      field("notificationsEnabled").checked = payload.notificationsEnabled;
    }
    render(await invoke<TimerSnapshot>("save_settings", { settings: payload }));
    setStandUpCycleText(payload);
    settingsMessage.textContent = "Saved";
    window.setTimeout(closeSettings, 450);
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
  }
});

void invoke<SettingsPayload>("get_settings").then(setStandUpCycleText, console.error);
void refreshFromRust();
void refreshCalendar();
