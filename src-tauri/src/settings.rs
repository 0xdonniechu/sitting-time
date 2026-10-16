use crate::timer::{
    TimerEngine, TimerSettings, MAX_DURATION_MINUTES, MAX_SESSIONS_BEFORE_LONG_BREAK,
    MIN_DURATION_MINUTES, MIN_SESSIONS_BEFORE_LONG_BREAK,
};
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
        let range = MIN_DURATION_MINUTES..=MAX_DURATION_MINUTES;
        if durations.iter().any(|minutes| !range.contains(minutes)) {
            return Err(format!(
                "Durations must be between {MIN_DURATION_MINUTES} and {MAX_DURATION_MINUTES} minutes"
            ));
        }
        let cycle = MIN_SESSIONS_BEFORE_LONG_BREAK..=MAX_SESSIONS_BEFORE_LONG_BREAK;
        if !cycle.contains(&self.focus_sessions_before_long_break) {
            return Err(format!(
                "Long-break cycle must be between {MIN_SESSIONS_BEFORE_LONG_BREAK} and {MAX_SESSIONS_BEFORE_LONG_BREAK} sessions"
            ));
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

/// Loads saved state. A file that exists but cannot be parsed is copied to
/// `state.json.corrupt` first, so the next save does not destroy the only copy.
pub fn load(path: &Path) -> PersistedAppState {
    let mut state = match fs::read_to_string(path) {
        Ok(contents) => serde_json::from_str(&contents).unwrap_or_else(|_| {
            let _ = fs::copy(path, path.with_extension("json.corrupt"));
            PersistedAppState::default()
        }),
        Err(_) => PersistedAppState::default(),
    };
    state.timer.sanitize();
    state
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
    // Write a sibling file and rename it over the old one, so a crash mid-write
    // leaves the previous state intact instead of a truncated file.
    let temp_path = path.with_extension("json.tmp");
    fs::write(&temp_path, contents).map_err(|error| error.to_string())?;
    fs::rename(&temp_path, path).map_err(|error| error.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::timer::TimerMode;
    use std::path::PathBuf;

    fn temp_state_path(name: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!("sitting-time-test-{name}-{}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        dir.join("state.json")
    }

    #[test]
    fn save_then_load_round_trips() {
        let path = temp_state_path("round-trip");
        let mut timer = TimerEngine::default();
        timer.set_mode(TimerMode::StandUp);
        let general = GeneralSettings {
            start_minimized_to_tray: true,
            ..GeneralSettings::default()
        };
        save(&path, &timer, &general).unwrap();
        let restored = load(&path);
        assert_eq!(restored.timer.snapshot(), timer.snapshot());
        assert!(restored.general.start_minimized_to_tray);
        assert!(!path.with_extension("json.tmp").exists());
        let _ = fs::remove_dir_all(path.parent().unwrap());
    }

    #[test]
    fn unreadable_state_is_kept_as_corrupt_copy() {
        let path = temp_state_path("corrupt");
        fs::create_dir_all(path.parent().unwrap()).unwrap();
        fs::write(&path, "{ not json").unwrap();
        let restored = load(&path);
        assert_eq!(restored.timer.snapshot(), TimerEngine::default().snapshot());
        let backup = path.with_extension("json.corrupt");
        assert_eq!(fs::read_to_string(backup).unwrap(), "{ not json");
        let _ = fs::remove_dir_all(path.parent().unwrap());
    }

    #[test]
    fn missing_state_loads_defaults_without_backup() {
        let path = temp_state_path("missing");
        let restored = load(&path);
        assert_eq!(restored.timer.snapshot(), TimerEngine::default().snapshot());
        assert!(!path.with_extension("json.corrupt").exists());
    }
}
