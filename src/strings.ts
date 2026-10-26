// Bundled UI strings: English ships as the default, Vietnamese mirrors the
// macOS language pack (same voice, same keys where they exist). No download:
// both tables ride in the bundle so the UI works fully offline.

export type Language = "en" | "vi";

type Table = Record<string, string>;

const en: Table = {
  appName: "SittingTime",
  modePomodoro: "Pomodoro",
  modeStandUp: "Stand Up",
  start: "Start",
  pause: "Pause",
  resume: "Resume",
  skip: "Skip",
  back: "Dashboard",
  statusReady: "Ready",
  statusRunning: "In progress",
  statusPaused: "Paused",
  somethingWrong: "Something went wrong",
  sessionFocus: "Focus",
  sessionShortBreak: "Short Break",
  sessionLongBreak: "Long Break",
  sessionSitting: "Sitting",
  sessionMove: "Move",
  cycleSession: "Session {i} of {n}",
  standUpCycle: "{sitting} min work · {movement} min move",
  trayHint: "Closing this window keeps the timer running in the tray.",
  today: "Today",
  sitting: "Sitting",
  standing: "Standing",
  rest: "Rest",
  breaksLineOne: "1 stand-up • Longest sit {longest}",
  breaksLineOther: "{count} stand-ups • Longest sit {longest}",
  goalProgress: "Standing goal {goal}",
  stats: "Statistics",
  settings: "Settings",
  about: "About",
  aboutTitle: "About SittingTime",
  madeBy: "Made by",
  reportBug: "Report a Bug",
  footerNote: "SittingTime {version} • Data stays on this machine: no account, no tracking.",
  buyCoffee: "Buy me a coffee",
  groupStandUp: "Stand Up",
  groupPomodoro: "Pomodoro",
  groupGeneral: "General",
  groupGoal: "Goal",
  groupLanguage: "Language",
  groupSupport: "Support",
  rowSitting: "Sitting",
  rowMovement: "Movement",
  rowFocus: "Focus",
  rowShortBreak: "Short break",
  rowLongBreak: "Long break",
  rowLongBreakEvery: "Long break every",
  unitMin: "min",
  unitSessions: "sessions",
  toggleLaunch: "Launch at login",
  toggleNotifications: "Notifications",
  toggleFullscreen: "Full-screen reminders",
  toggleSound: "Alert sound",
  toggleFacts: "Health facts on reminders",
  toggleMinimized: "Start minimized to tray",
  rowGoal: "Standing goal (0 = off)",
  unitGoalMin: "min/day",
  languageEnglish: "English",
  languageVietnamese: "Tiếng Việt",
  previewReminder: "Preview reminder",
  saveSettings: "Save settings",
  saving: "Saving…",
  saved: "Saved",
  couldNotOpen: "Could not open settings",
  statsDay: "Day",
  statsWeek: "Week",
  dailyAverage: "Daily Average {duration}",
  noActivity: "No activity yet",
  last7days: "Last 7 days",
  clearToday: "Clear today's data",
  eraseHistory: "Erase all history",
  confirmClearToday: "Clear today's data? Click again to delete.",
  confirmEraseHistory: "Erase all history? Click again to delete.",
  chartSitting: "Sitting",
  chartStanding: "Standing",
  chartRest: "Rest",
  yAxisHours: "hours",
  unitHourOne: "1 hour",
  unitHourOther: "{n} hours",
  unitMinuteOne: "1 minute",
  unitMinuteOther: "{n} minutes",
  unitSecondOne: "1 second",
  unitSecondOther: "{n} seconds",
};

const vi: Table = {
  appName: "SittingTime",
  modePomodoro: "Pomodoro",
  modeStandUp: "Stand Up",
  start: "Bắt đầu",
  pause: "Tạm nghỉ",
  resume: "Tiếp tục",
  skip: "Bỏ qua",
  back: "Tổng quan",
  statusReady: "Sẵn sàng",
  statusRunning: "Đang chạy",
  statusPaused: "Tạm nghỉ",
  somethingWrong: "Có lỗi xảy ra",
  sessionFocus: "Tập trung",
  sessionShortBreak: "Nghỉ ngắn",
  sessionLongBreak: "Nghỉ dài",
  sessionSitting: "Ngồi",
  sessionMove: "Vận động",
  cycleSession: "Phiên {i} trên {n}",
  standUpCycle: "{sitting} phút làm việc · {movement} phút vận động",
  trayHint: "Đóng cửa sổ này, timer vẫn chạy dưới khay hệ thống.",
  today: "Hôm nay",
  sitting: "Ngồi",
  standing: "Đứng",
  rest: "Nghỉ",
  breaksLineOne: "Đứng dậy {count} lần • Ngồi lâu nhất {longest}",
  breaksLineOther: "Đứng dậy {count} lần • Ngồi lâu nhất {longest}",
  goalProgress: "Mục tiêu đứng {goal}",
  stats: "Thống kê",
  settings: "Cài đặt",
  about: "Giới thiệu",
  aboutTitle: "Về SittingTime",
  madeBy: "Phát triển bởi",
  reportBug: "Báo lỗi",
  footerNote: "SittingTime {version} • Dữ liệu chỉ nằm trên máy này, không tài khoản, không theo dõi.",
  buyCoffee: "Buy me a coffee",
  groupStandUp: "Stand Up",
  groupPomodoro: "Pomodoro",
  groupGeneral: "Chung",
  groupGoal: "Mục tiêu",
  groupLanguage: "Ngôn ngữ",
  groupSupport: "Ủng hộ",
  rowSitting: "Ngồi làm việc",
  rowMovement: "Vận động",
  rowFocus: "Tập trung",
  rowShortBreak: "Nghỉ ngắn",
  rowLongBreak: "Nghỉ dài",
  rowLongBreakEvery: "Nghỉ dài mỗi",
  unitMin: "phút",
  unitSessions: "phiên",
  toggleLaunch: "Mở cùng máy",
  toggleNotifications: "Thông báo",
  toggleFullscreen: "Nháy toàn màn hình",
  toggleSound: "Âm thanh nhắc nhở",
  toggleFacts: "Hiện fact trên nhắc nhở",
  toggleMinimized: "Mở ẩn dưới khay",
  rowGoal: "Mục tiêu đứng (0 = tắt)",
  unitGoalMin: "phút/ngày",
  languageEnglish: "English",
  languageVietnamese: "Tiếng Việt",
  previewReminder: "Xem trước nhắc nhở",
  saveSettings: "Lưu cài đặt",
  saving: "Đang lưu…",
  saved: "Đã lưu",
  couldNotOpen: "Không mở được cài đặt",
  statsDay: "Ngày",
  statsWeek: "Tuần",
  dailyAverage: "Trung bình ngày {duration}",
  noActivity: "Chưa có hoạt động",
  last7days: "7 ngày qua",
  clearToday: "Xóa dữ liệu hôm nay",
  eraseHistory: "Xóa toàn bộ lịch sử",
  confirmClearToday: "Xóa dữ liệu hôm nay? Bấm lần nữa để xóa.",
  confirmEraseHistory: "Xóa toàn bộ lịch sử? Bấm lần nữa để xóa.",
  chartSitting: "Ngồi",
  chartStanding: "Đứng",
  chartRest: "Nghỉ",
  yAxisHours: "giờ",
  unitHourOne: "{n} giờ",
  unitHourOther: "{n} giờ",
  unitMinuteOne: "{n} phút",
  unitMinuteOther: "{n} phút",
  unitSecondOne: "{n} giây",
  unitSecondOther: "{n} giây",
};

export function t(lang: Language, key: string, args?: Record<string, string | number>): string {
  let template = en[key] ?? key;
  if (lang === "vi" && vi[key] !== undefined) template = vi[key];
  if (!args) return template;
  return template.replace(/\{(\w+)\}/g, (_, name: string) =>
    args[name] !== undefined ? String(args[name]) : `{${name}}`,
  );
}

function unit(lang: Language, value: number, oneKey: string, otherKey: string): string {
  const key = lang === "en" && value === 1 ? oneKey : otherKey;
  return t(lang, key, { n: value });
}

/// `"2 hours 15 minutes"`, `"45 minutes"`, `"30 seconds"` (or the Vietnamese
/// equivalents without plurals). Used for totals and stats, like macOS.
export function formatDuration(seconds: number, lang: Language): string {
  const total = Math.max(0, Math.round(seconds));
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  if (hours > 0 && minutes > 0) {
    return `${unit(lang, hours, "unitHourOne", "unitHourOther")} ${unit(lang, minutes, "unitMinuteOne", "unitMinuteOther")}`;
  }
  if (hours > 0) return unit(lang, hours, "unitHourOne", "unitHourOther");
  if (minutes > 0) return unit(lang, minutes, "unitMinuteOne", "unitMinuteOther");
  return unit(lang, total, "unitSecondOne", "unitSecondOther");
}

/// Zodiac animal glyph for the calendar tile, keyed by the Rust
/// `ZodiacAnimal` serial names.
export const ZODIAC_EMOJI: Record<string, string> = {
  rat: "🐀",
  ox: "🐂",
  tiger: "🐅",
  rabbit: "🐇",
  dragon: "🐉",
  snake: "🐍",
  horse: "🐎",
  goat: "🐐",
  monkey: "🐒",
  rooster: "🐔",
  dog: "🐕",
  pig: "🐖",
};
