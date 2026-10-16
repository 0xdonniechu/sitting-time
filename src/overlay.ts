import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import "@fontsource-variable/inter";
import "./overlay.css";

interface ReminderAlert {
  title: string;
  body: string;
  showFullscreen: boolean;
  playSound: boolean;
}

const reminder = document.querySelector<HTMLElement>("#reminder")!;
const title = document.querySelector<HTMLElement>("#reminder-title")!;
const body = document.querySelector<HTMLElement>("#reminder-body")!;
let dismissTimer: number | undefined;

function playChime(): void {
  const AudioContextClass = window.AudioContext;
  const context = new AudioContextClass();
  const gain = context.createGain();
  gain.connect(context.destination);
  gain.gain.setValueAtTime(0.0001, context.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.18, context.currentTime + 0.025);
  gain.gain.exponentialRampToValueAtTime(0.0001, context.currentTime + 0.72);

  [659.25, 880].forEach((frequency, index) => {
    const oscillator = context.createOscillator();
    oscillator.type = "sine";
    oscillator.frequency.value = frequency;
    oscillator.connect(gain);
    oscillator.start(context.currentTime + index * 0.12);
    oscillator.stop(context.currentTime + 0.72);
  });

  window.setTimeout(() => void context.close(), 900);
}

async function dismiss(): Promise<void> {
  window.clearTimeout(dismissTimer);
  reminder.classList.remove("active");
  window.setTimeout(() => void invoke("dismiss_reminder"), 260);
}

void listen<ReminderAlert>("reminder-alert", (event) => {
  const alert = event.payload;
  if (alert.playSound) playChime();
  if (!alert.showFullscreen) return;

  title.textContent = alert.title === "Time to stand up" ? "It’s time to stand up" : alert.title;
  body.textContent = alert.body;
  reminder.classList.remove("active");
  requestAnimationFrame(() => reminder.classList.add("active"));
  window.clearTimeout(dismissTimer);
  dismissTimer = window.setTimeout(() => void dismiss(), 6000);
});

document.addEventListener("click", () => void dismiss());
document.addEventListener("keydown", (event) => {
  if (event.key === "Escape" || event.key === "Enter" || event.key === " ") void dismiss();
});
