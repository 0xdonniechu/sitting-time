use crate::timer::{TimerEngine, TimerSettings};
use serde::{Deserialize, Serialize};
use std::{fs, path::Path};

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase", default)]
pub struct GeneralSettings {
    pub launch_at_login: bool,
    pub notifications_enabled: bool,
    pub fullscreen_reminders_enabled: bool,
    pub alert_sound_enabled: bool,
    pub start_minimized_to_tray: bool,
}

impl Default for GeneralSettings {
    fn default() -> Self {
        Self {
            launch_at_login: false,
            notifications_enabled: true,
            fullscreen_reminders_enabled: true,
            alert_sound_enabled: true,
            start_minimized_to_tray: false,
        }
    }
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SettingsPayload {
    pub sitting_minutes: u64,
    pub movement_minutes: u64,
    pub focus_minutes: u64,
    pub short_break_minutes: u64,
    pub long_break_minutes: u64,
    pub focus_sessions_before_long_break: u32,
    pub launch_at_login: bool,
    pub notifications_enabled: bool,
    pub fullscreen_reminders_enabled: bool,
    pub alert_sound_enabled: bool,
    pub start_minimized_to_tray: bool,
}

impl SettingsPayload {
    pub fn validate(&self) -> Result<(), String> {
        let durations = [
            self.sitting_minutes,
            self.movement_minutes,
            self.focus_minutes,
            self.short_break_minutes,
            self.long_break_minutes,
        ];
        if durations.iter().any(|minutes| !(1..=240).contains(minutes)) {
            return Err("Durations must be between 1 and 240 minutes".to_string());
        }
        if !(1..=12).contains(&self.focus_sessions_before_long_break) {
            return Err("Long-break cycle must be between 1 and 12 sessions".to_string());
        }
        Ok(())
    }

    pub fn timer_settings(&self) -> TimerSettings {
        TimerSettings {
            sitting_seconds: self.sitting_minutes * 60,
            movement_seconds: self.movement_minutes * 60,
            focus_seconds: self.focus_minutes * 60,
            short_break_seconds: self.short_break_minutes * 60,
            long_break_seconds: self.long_break_minutes * 60,
            focus_sessions_before_long_break: self.focus_sessions_before_long_break,
        }
    }

    pub fn general_settings(&self) -> GeneralSettings {
        GeneralSettings {
            launch_at_login: self.launch_at_login,
            notifications_enabled: self.notifications_enabled,
            fullscreen_reminders_enabled: self.fullscreen_reminders_enabled,
            alert_sound_enabled: self.alert_sound_enabled,
            start_minimized_to_tray: self.start_minimized_to_tray,
        }
    }
}

pub fn payload(timer: &TimerEngine, general: &GeneralSettings) -> SettingsPayload {
    let settings = timer.settings();
    SettingsPayload {
        sitting_minutes: settings.sitting_seconds / 60,
        movement_minutes: settings.movement_seconds / 60,
        focus_minutes: settings.focus_seconds / 60,
        short_break_minutes: settings.short_break_seconds / 60,
        long_break_minutes: settings.long_break_seconds / 60,
        focus_sessions_before_long_break: settings.focus_sessions_before_long_break,
        launch_at_login: general.launch_at_login,
        notifications_enabled: general.notifications_enabled,
        fullscreen_reminders_enabled: general.fullscreen_reminders_enabled,
        alert_sound_enabled: general.alert_sound_enabled,
        start_minimized_to_tray: general.start_minimized_to_tray,
    }
}

#[derive(Clone, Debug, Default, Deserialize, Serialize)]
#[serde(rename_all = "camelCase", default)]
pub struct PersistedAppState {
    pub timer: TimerEngine,
    pub general: GeneralSettings,
}

pub fn load(path: &Path) -> PersistedAppState {
    fs::read_to_string(path)
        .ok()
        .and_then(|contents| serde_json::from_str(&contents).ok())
        .unwrap_or_default()
}

pub fn save(path: &Path, timer: &TimerEngine, general: &GeneralSettings) -> Result<(), String> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|error| error.to_string())?;
    }
    let value = PersistedAppState {
        timer: timer.clone(),
        general: general.clone(),
    };
    let contents = serde_json::to_string_pretty(&value).map_err(|error| error.to_string())?;
    fs::write(path, contents).map_err(|error| error.to_string())
}
