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
  startMinimizedToTray: boolean;
}

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
      <button class="icon-button" id="settings-button" aria-label="Open settings">
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <path d="M12 15.25A3.25 3.25 0 1 0 12 8.75a3.25 3.25 0 0 0 0 6.5Z"/>
          <path d="M19 13.1v-2.2l-2.02-.72a5.2 5.2 0 0 0-.5-1.2l.92-1.94-1.55-1.55-1.94.92a5.2 5.2 0 0 0-1.2-.5L12 3.9H9.8l-.72 2.02a5.2 5.2 0 0 0-1.2.5l-1.94-.92-1.55 1.55.92 1.94a5.2 5.2 0 0 0-.5 1.2l-2.02.72v2.2l2.02.72c.12.42.29.82.5 1.2l-.92 1.94 1.55 1.55 1.94-.92c.38.21.78.38 1.2.5l.72 2.02H12l.72-2.02c.42-.12.82-.29 1.2-.5l1.94.92 1.55-1.55-.92-1.94c.21-.38.38-.78.5-1.2L19 13.1Z"/>
        </svg>
      </button>
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
  }
});

void invoke<SettingsPayload>("get_settings").then(setStandUpCycleText, console.error);
void refreshFromRust();
