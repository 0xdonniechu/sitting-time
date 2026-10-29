use serde::{Deserialize, Serialize};
use std::time::{SystemTime, UNIX_EPOCH};

pub const MIN_DURATION_MINUTES: u64 = 1;
pub const MAX_DURATION_MINUTES: u64 = 240;
pub const MIN_SESSIONS_BEFORE_LONG_BREAK: u32 = 1;
pub const MAX_SESSIONS_BEFORE_LONG_BREAK: u32 = 12;

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

/// Sitting or standing while a work session runs. Breaks always count as
/// rest, never as standing: standing means working upright at the desk
/// (macOS parity).
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum Posture {
    #[default]
    Sitting,
    Standing,
}

#[derive(Clone, Debug, PartialEq, Eq, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct TimerSettings {
    pub sitting_seconds: u64,
    pub movement_seconds: u64,
    pub focus_seconds: u64,
    pub short_break_seconds: u64,
    pub long_break_seconds: u64,
    pub focus_sessions_before_long_break: u32,
}

impl TimerSettings {
    pub fn is_valid(&self) -> bool {
        let durations = (MIN_DURATION_MINUTES * 60)..=(MAX_DURATION_MINUTES * 60);
        [
            self.sitting_seconds,
            self.movement_seconds,
            self.focus_seconds,
            self.short_break_seconds,
            self.long_break_seconds,
        ]
        .iter()
        .all(|seconds| durations.contains(seconds))
            && (MIN_SESSIONS_BEFORE_LONG_BREAK..=MAX_SESSIONS_BEFORE_LONG_BREAK)
                .contains(&self.focus_sessions_before_long_break)
    }
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
    pub posture: Posture,
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
    /// Live body state, never persisted: a restart always comes back
    /// sitting, like macOS.
    #[serde(skip)]
    posture: Posture,
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
            posture: Posture::Sitting,
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
        if self.settings == settings {
            return;
        }
        self.settings = settings;
        self.reset_current_session();
    }

    /// Restored state is untrusted: invalid durations could make `tick` loop forever.
    pub fn sanitize(&mut self) {
        if self.settings.is_valid() {
            return;
        }
        self.settings = TimerSettings::default();
        self.completed_focus_sessions = 0;
        self.reset_current_session();
    }

    pub fn snapshot(&self) -> TimerSnapshot {
        let now = epoch_ms();
        let remaining_ms = self.current_remaining_ms(now);
        TimerSnapshot {
            selected_mode: self.selected_mode,
            session: self.session,
            status: self.status,
            posture: self.posture,
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

    /// Switches sitting/standing attribution. The session clock keeps running.
    pub fn set_posture(&mut self, posture: Posture) {
        self.posture = posture;
    }

    pub fn reset_current_session(&mut self) {
        self.status = TimerStatus::Idle;
        self.deadline_epoch_ms = None;
        self.remaining_ms = self.session_duration_seconds() * 1_000;
    }

    /// Switches Stand Up / Pomodoro keeping the running session, like macOS:
    /// work stays work, break stays break, and the clock keeps running. A
    /// Pomodoro long break becomes Move in Stand Up (which has no long
    /// break); the focus count resets to zero in Stand Up and carries over
    /// to Pomodoro. When the carried elapsed time already exceeds the new
    /// length, the next tick auto-advances.
    pub fn set_mode(&mut self, mode: TimerMode) {
        if self.selected_mode == mode {
            return;
        }

        let now = epoch_ms();
        let elapsed_ms = self
            .session_duration_seconds()
            .saturating_mul(1_000)
            .saturating_sub(self.current_remaining_ms(now));
        self.selected_mode = mode;
        self.session = match (mode, self.session) {
            (TimerMode::StandUp, SessionKind::Focus | SessionKind::Sitting) => {
                SessionKind::Sitting
            }
            (TimerMode::StandUp, _) => SessionKind::Move,
            (TimerMode::Pomodoro, SessionKind::Sitting | SessionKind::Focus) => SessionKind::Focus,
            (TimerMode::Pomodoro, SessionKind::Move | SessionKind::ShortBreak) => {
                SessionKind::ShortBreak
            }
            (TimerMode::Pomodoro, SessionKind::LongBreak) => SessionKind::LongBreak,
        };
        if mode == TimerMode::StandUp {
            self.completed_focus_sessions = 0;
        }
        let duration_ms = self.session_duration_seconds().saturating_mul(1_000);
        let remaining_ms = duration_ms.saturating_sub(elapsed_ms);
        match self.status {
            TimerStatus::Running => {
                self.remaining_ms = remaining_ms;
                self.deadline_epoch_ms = Some(now.saturating_add(remaining_ms));
            }
            TimerStatus::Paused => {
                self.remaining_ms = remaining_ms;
                self.deadline_epoch_ms = None;
            }
            TimerStatus::Idle => {
                self.remaining_ms = duration_ms;
                self.deadline_epoch_ms = None;
            }
        }
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
                if self
                    .completed_focus_sessions
                    .is_multiple_of(self.settings.focus_sessions_before_long_break)
                {
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

pub(crate) fn epoch_ms() -> u64 {
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
    fn posture_defaults_to_sitting_and_switches() {
        let mut engine = TimerEngine::default();
        assert_eq!(engine.snapshot().posture, Posture::Sitting);
        engine.set_posture(Posture::Standing);
        assert_eq!(engine.snapshot().posture, Posture::Standing);
        engine.set_posture(Posture::Sitting);
        assert_eq!(engine.snapshot().posture, Posture::Sitting);
    }

    #[test]
    fn posture_resets_to_sitting_on_load() {
        // Posture is the body's live state, not persisted: like macOS, a
        // restart always comes back sitting.
        let mut engine = TimerEngine::default();
        engine.set_posture(Posture::Standing);
        let json = serde_json::to_string(&engine).unwrap();
        assert!(!json.contains("posture"));
        let restored: TimerEngine = serde_json::from_str(&json).unwrap();
        assert_eq!(restored.snapshot().posture, Posture::Sitting);
    }

    fn running_engine(mode: TimerMode) -> TimerEngine {
        let mut engine = TimerEngine::default();
        engine.set_mode(mode);
        engine.start();
        engine
    }

    #[test]
    fn unchanged_settings_keep_running_session() {
        let mut engine = running_engine(TimerMode::StandUp);
        let deadline = engine.deadline_epoch_ms;
        engine.update_settings(TimerSettings::default());
        assert_eq!(engine.status, TimerStatus::Running);
        assert_eq!(engine.deadline_epoch_ms, deadline);
    }

    #[test]
    fn changed_settings_reset_session() {
        let mut engine = running_engine(TimerMode::StandUp);
        let settings = TimerSettings {
            sitting_seconds: 30 * 60,
            ..TimerSettings::default()
        };
        engine.update_settings(settings);
        let snapshot = engine.snapshot();
        assert_eq!(snapshot.status, TimerStatus::Idle);
        assert_eq!(snapshot.remaining_seconds, 30 * 60);
    }

    #[test]
    fn tick_catches_up_from_deadline_after_sleep() {
        let mut engine = running_engine(TimerMode::StandUp);
        let missed_deadline = epoch_ms() - 60_000;
        engine.deadline_epoch_ms = Some(missed_deadline);
        assert!(engine.tick());
        assert_eq!(engine.session, SessionKind::Move);
        assert_eq!(engine.status, TimerStatus::Running);
        assert_eq!(engine.deadline_epoch_ms, Some(missed_deadline + 5 * 60 * 1_000));
    }

    #[test]
    fn fourth_focus_session_leads_to_long_break() {
        let mut engine = TimerEngine::default();
        let mut breaks = Vec::new();
        for _ in 0..4 {
            engine.skip();
            breaks.push(engine.session);
            engine.skip();
        }
        assert_eq!(
            breaks,
            [
                SessionKind::ShortBreak,
                SessionKind::ShortBreak,
                SessionKind::ShortBreak,
                SessionKind::LongBreak
            ]
        );
    }

    #[test]
    fn sanitize_replaces_invalid_restored_settings() {
        let mut engine = running_engine(TimerMode::StandUp);
        engine.settings = TimerSettings {
            sitting_seconds: 0,
            movement_seconds: 0,
            focus_sessions_before_long_break: 0,
            ..TimerSettings::default()
        };
        engine.deadline_epoch_ms = Some(epoch_ms() - 60_000);
        engine.sanitize();
        assert_eq!(engine.settings, TimerSettings::default());
        assert_eq!(engine.status, TimerStatus::Idle);
        assert!(!engine.tick());
        assert_eq!(engine.snapshot().remaining_seconds, 45 * 60);
    }

    #[test]
    fn sanitize_keeps_valid_running_state() {
        let mut engine = running_engine(TimerMode::Pomodoro);
        let deadline = engine.deadline_epoch_ms;
        engine.sanitize();
        assert_eq!(engine.status, TimerStatus::Running);
        assert_eq!(engine.deadline_epoch_ms, deadline);
    }

    #[test]
    fn mode_change_keeps_the_running_session() {
        let mut engine = running_engine(TimerMode::StandUp);
        // Ten minutes into a 45-minute sit.
        engine.deadline_epoch_ms = Some(epoch_ms() + (45 * 60 - 600) * 1_000);
        engine.set_mode(TimerMode::Pomodoro);
        let snapshot = engine.snapshot();
        assert_eq!(snapshot.session, SessionKind::Focus);
        assert_eq!(snapshot.status, TimerStatus::Running);
        // Carried elapsed: about 15:00 left of a 25-minute focus.
        assert!((880..=900).contains(&snapshot.remaining_seconds));
    }

    #[test]
    fn mode_change_maps_break_to_break() {
        let mut engine = running_engine(TimerMode::Pomodoro);
        engine.skip();
        assert_eq!(engine.session, SessionKind::ShortBreak);
        engine.start();
        engine.set_mode(TimerMode::StandUp);
        let snapshot = engine.snapshot();
        assert_eq!(snapshot.session, SessionKind::Move);
        assert_eq!(snapshot.status, TimerStatus::Running);
    }

    #[test]
    fn mode_change_resets_completed_count_only_in_stand_up() {
        let mut engine = TimerEngine::default();
        engine.skip();
        engine.skip();
        assert_eq!(engine.snapshot().completed_focus_sessions, 1);
        engine.set_mode(TimerMode::StandUp);
        assert_eq!(engine.snapshot().completed_focus_sessions, 0);
        engine.set_mode(TimerMode::Pomodoro);
        engine.skip();
        engine.skip();
        assert_eq!(engine.snapshot().completed_focus_sessions, 1);
    }

    #[test]
    fn mode_change_while_idle_starts_fresh() {
        let mut engine = TimerEngine::default();
        engine.set_mode(TimerMode::StandUp);
        let snapshot = engine.snapshot();
        assert_eq!(snapshot.session, SessionKind::Sitting);
        assert_eq!(snapshot.status, TimerStatus::Idle);
        assert_eq!(snapshot.remaining_seconds, 45 * 60);
    }

    #[test]
    fn mode_change_overshoot_advances_on_next_tick() {
        let mut engine = running_engine(TimerMode::StandUp);
        // Thirty minutes into a 45-minute sit, then switch to a 25-minute
        // focus: the carried elapsed already exceeds the new length.
        engine.deadline_epoch_ms = Some(epoch_ms() + 15 * 60 * 1_000);
        engine.set_mode(TimerMode::Pomodoro);
        assert_eq!(engine.snapshot().remaining_seconds, 0);
        assert!(engine.tick());
        assert_eq!(engine.session, SessionKind::ShortBreak);
    }
}
