use serde::{Deserialize, Serialize};
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum TimerMode {
    Pomodoro,
    StandUp,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum SessionKind {
    Focus,
    ShortBreak,
    LongBreak,
    Sitting,
    Move,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum TimerStatus {
    Idle,
    Running,
    Paused,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct TimerSettings {
    pub sitting_seconds: u64,
    pub movement_seconds: u64,
    pub focus_seconds: u64,
    pub short_break_seconds: u64,
    pub long_break_seconds: u64,
    pub focus_sessions_before_long_break: u32,
}

impl Default for TimerSettings {
    fn default() -> Self {
        Self {
            sitting_seconds: 45 * 60,
            movement_seconds: 5 * 60,
            focus_seconds: 25 * 60,
            short_break_seconds: 5 * 60,
            long_break_seconds: 15 * 60,
            focus_sessions_before_long_break: 4,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct TimerSnapshot {
    pub selected_mode: TimerMode,
    pub session: SessionKind,
    pub status: TimerStatus,
    pub remaining_seconds: u64,
    pub total_seconds: u64,
    pub completed_focus_sessions: u32,
    pub focus_sessions_before_long_break: u32,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct TimerEngine {
    settings: TimerSettings,
    selected_mode: TimerMode,
    session: SessionKind,
    status: TimerStatus,
    remaining_ms: u64,
    deadline_epoch_ms: Option<u64>,
    completed_focus_sessions: u32,
}

impl Default for TimerEngine {
    fn default() -> Self {
        let settings = TimerSettings::default();
        let remaining_ms = settings.focus_seconds * 1_000;
        Self {
            settings,
            selected_mode: TimerMode::Pomodoro,
            session: SessionKind::Focus,
            status: TimerStatus::Idle,
            remaining_ms,
            deadline_epoch_ms: None,
            completed_focus_sessions: 0,
        }
    }
}

impl TimerEngine {
    pub fn settings(&self) -> TimerSettings {
        self.settings.clone()
    }

    pub fn update_settings(&mut self, settings: TimerSettings) {
        self.settings = settings;
        self.reset_current_session();
    }

    pub fn snapshot(&self) -> TimerSnapshot {
        let now = epoch_ms();
        let remaining_ms = self.current_remaining_ms(now);
        TimerSnapshot {
            selected_mode: self.selected_mode,
            session: self.session,
            status: self.status,
            remaining_seconds: remaining_ms.div_ceil(1_000),
            total_seconds: self.session_duration_seconds(),
            completed_focus_sessions: self.completed_focus_sessions,
            focus_sessions_before_long_break: self.settings.focus_sessions_before_long_break,
        }
    }

    pub fn start(&mut self) {
        if self.status == TimerStatus::Running {
            return;
        }

        if self.remaining_ms == 0 {
            self.remaining_ms = self.session_duration_seconds() * 1_000;
        }

        self.status = TimerStatus::Running;
        self.deadline_epoch_ms = Some(epoch_ms().saturating_add(self.remaining_ms));
    }

    pub fn pause(&mut self) {
        if self.status != TimerStatus::Running {
            return;
        }

        self.remaining_ms = self.current_remaining_ms(epoch_ms());
        self.deadline_epoch_ms = None;
        self.status = TimerStatus::Paused;
    }

    pub fn skip(&mut self) {
        let continue_running = self.status == TimerStatus::Running;
        self.advance_session(epoch_ms(), continue_running);
    }

    pub fn reset_current_session(&mut self) {
        self.status = TimerStatus::Idle;
        self.deadline_epoch_ms = None;
        self.remaining_ms = self.session_duration_seconds() * 1_000;
    }

    pub fn set_mode(&mut self, mode: TimerMode) {
        if self.selected_mode == mode {
            return;
        }

        self.selected_mode = mode;
        self.session = match mode {
            TimerMode::Pomodoro => SessionKind::Focus,
            TimerMode::StandUp => SessionKind::Sitting,
        };
        self.status = TimerStatus::Idle;
        self.deadline_epoch_ms = None;
        self.completed_focus_sessions = 0;
        self.remaining_ms = self.session_duration_seconds() * 1_000;
    }

    pub fn tick(&mut self) -> bool {
        if self.status != TimerStatus::Running {
            return false;
        }

        let now = epoch_ms();
        let mut transitioned = false;

        while let Some(deadline) = self.deadline_epoch_ms {
            if now < deadline {
                break;
            }
            self.advance_session(deadline, true);
            transitioned = true;
        }

        transitioned
    }

    fn advance_session(&mut self, next_started_at: u64, continue_running: bool) {
        self.session = match (self.selected_mode, self.session) {
            (TimerMode::StandUp, SessionKind::Sitting) => SessionKind::Move,
            (TimerMode::StandUp, SessionKind::Move) => SessionKind::Sitting,
            (TimerMode::Pomodoro, SessionKind::Focus) => {
                self.completed_focus_sessions = self.completed_focus_sessions.saturating_add(1);
                if self.completed_focus_sessions % self.settings.focus_sessions_before_long_break == 0 {
                    SessionKind::LongBreak
                } else {
                    SessionKind::ShortBreak
                }
            }
            (TimerMode::Pomodoro, SessionKind::ShortBreak | SessionKind::LongBreak) => {
                SessionKind::Focus
            }
            _ => match self.selected_mode {
                TimerMode::Pomodoro => SessionKind::Focus,
                TimerMode::StandUp => SessionKind::Sitting,
            },
        };

        self.remaining_ms = self.session_duration_seconds() * 1_000;
        self.status = if continue_running {
            TimerStatus::Running
        } else {
            TimerStatus::Idle
        };
        self.deadline_epoch_ms = continue_running
            .then_some(next_started_at.saturating_add(self.remaining_ms));
    }

    fn current_remaining_ms(&self, now: u64) -> u64 {
        match (self.status, self.deadline_epoch_ms) {
            (TimerStatus::Running, Some(deadline)) => deadline.saturating_sub(now),
            _ => self.remaining_ms,
        }
    }

    fn session_duration_seconds(&self) -> u64 {
        match self.session {
            SessionKind::Focus => self.settings.focus_seconds,
            SessionKind::ShortBreak => self.settings.short_break_seconds,
            SessionKind::LongBreak => self.settings.long_break_seconds,
            SessionKind::Sitting => self.settings.sitting_seconds,
            SessionKind::Move => self.settings.movement_seconds,
        }
    }
}

fn epoch_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis()
        .try_into()
        .unwrap_or(u64::MAX)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_snapshot_is_focus() {
        let engine = TimerEngine::default();
        let snapshot = engine.snapshot();
        assert_eq!(snapshot.session, SessionKind::Focus);
        assert_eq!(snapshot.remaining_seconds, 25 * 60);
        assert_eq!(snapshot.status, TimerStatus::Idle);
    }

    #[test]
    fn mode_change_resets_to_sitting() {
        let mut engine = TimerEngine::default();
        engine.set_mode(TimerMode::StandUp);
        let snapshot = engine.snapshot();
        assert_eq!(snapshot.session, SessionKind::Sitting);
        assert_eq!(snapshot.remaining_seconds, 45 * 60);
    }
}
