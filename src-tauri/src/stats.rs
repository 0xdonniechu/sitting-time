//! Screen Time-style activity statistics, ported from the macOS `DayRecord`
//! model. Tracks sitting / standing / rest seconds per UTC+7 calendar day,
//! with per-hour buckets, break counts and longest-sit stretches.
//!
//! The timer engine stays the source of truth for the countdown; this module
//! only attributes elapsed wall-clock time reported by the caller. Gaps over
//! two minutes between attributions (sleep, hibernate) are discarded instead
//! of polluting the stats, mirroring macOS — the timer's own deadline
//! catch-up behaviour is untouched.

use crate::lunar::{civil_from_days, utc7_day_count};
use crate::timer::{Posture, SessionKind, TimerStatus};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

/// Attribution bucket for a stretch of wall-clock time. Paused covers manual
/// pauses as well as rest breaks: anything that is not sitting or standing.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum Phase {
    Sitting,
    Standing,
    Paused,
}

/// Maps the engine state to an attribution bucket. An idle engine tracks
/// nothing: attributing rest while the timer was never started would inflate
/// every day with phantom hours. Work sessions follow the posture; breaks
/// always count as rest, like macOS.
pub fn phase_for(status: TimerStatus, session: SessionKind, posture: Posture) -> Option<Phase> {
    match status {
        TimerStatus::Idle => None,
        TimerStatus::Paused => Some(Phase::Paused),
        TimerStatus::Running => Some(match session {
            SessionKind::Focus | SessionKind::Sitting => match posture {
                Posture::Sitting => Phase::Sitting,
                Posture::Standing => Phase::Standing,
            },
            SessionKind::Move | SessionKind::ShortBreak | SessionKind::LongBreak => Phase::Paused,
        }),
    }
}

/// One hour's totals within a day (hour 0-23, UTC+7).
#[derive(Clone, Debug, Default, PartialEq, Eq, Deserialize, Serialize)]
#[serde(rename_all = "camelCase", default)]
pub struct HourRecord {
    pub sitting_seconds: u64,
    pub standing_seconds: u64,
    pub paused_seconds: u64,
}

/// One UTC+7 calendar day. `hourly` always holds 24 buckets in files written
/// by this module; readers tolerate shorter vectors from older files.
#[derive(Clone, Debug, Default, PartialEq, Eq, Deserialize, Serialize)]
#[serde(rename_all = "camelCase", default)]
pub struct DayRecord {
    pub date_key: String,
    pub sitting_seconds: u64,
    pub standing_seconds: u64,
    pub paused_seconds: u64,
    pub break_count: u32,
    pub longest_sit_seconds: u64,
    pub hourly: Vec<HourRecord>,
}

impl DayRecord {
    fn fresh(date_key: String) -> Self {
        Self {
            date_key,
            sitting_seconds: 0,
            standing_seconds: 0,
            paused_seconds: 0,
            break_count: 0,
            longest_sit_seconds: 0,
            hourly: vec![HourRecord::default(); 24],
        }
    }

    pub fn tracked_seconds(&self) -> u64 {
        self.sitting_seconds + self.standing_seconds + self.paused_seconds
    }
}

/// One day of the weekly chart.
#[derive(Clone, Debug, PartialEq, Eq, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct WeekDay {
    pub date_key: String,
    pub label: String,
    pub sitting_seconds: u64,
    pub standing_seconds: u64,
    pub paused_seconds: u64,
}

impl WeekDay {
    pub fn tracked_seconds(&self) -> u64 {
        self.sitting_seconds + self.standing_seconds + self.paused_seconds
    }
}

/// Gaps longer than this between attributions are discarded (sleep): the
/// unknown interval never lands in any bucket.
const SLEEP_GAP_MS: i64 = 120_000;
const DAY_MS: i64 = 86_400_000;
const HOUR_MS: i64 = 3_600_000;
const UTC7_OFFSET_MS: i64 = 7 * 3_600_000;

/// Closed segments per UTC+7 day key. The open segment lives in the skipped
/// runtime fields below, so a restart never resumes a stale stretch: the
/// first attribution after load sees a huge gap and starts fresh.
#[derive(Clone, Debug, Default, Deserialize, Serialize)]
#[serde(rename_all = "camelCase", default)]
pub struct StatsStore {
    records: BTreeMap<String, DayRecord>,
    #[serde(skip)]
    today_key: String,
    #[serde(skip)]
    current_phase: Option<Phase>,
    #[serde(skip)]
    segment_start_ms: u64,
    #[serde(skip)]
    last_ms: u64,
    #[serde(skip)]
    has_last: bool,
    /// Start of the current uninterrupted sitting stretch; spans session
    /// boundaries while the phase stays Sitting.
    #[serde(skip)]
    stretch_start_ms: Option<u64>,
    /// Day key the standing goal already fired for (resets on day change).
    /// Persisted so a restart does not re-fire the same day's notification.
    goal_day: Option<String>,
}

impl StatsStore {
    fn record(&mut self, key: &str) -> &mut DayRecord {
        if !self.records.contains_key(key) {
            self.records
                .insert(key.to_string(), DayRecord::fresh(key.to_string()));
        }
        self.records.get_mut(key).expect("record just inserted")
    }

    /// Close the open segment at `now_ms` and open a new one with `phase`
    /// (`None` = engine idle: track nothing). Handles day rollover and the
    /// sleep-gap discard. The countdown is untouched.
    pub fn set_phase(&mut self, now_ms: u64, phase: Option<Phase>) {
        let day = day_key(now_ms);
        if self.today_key != day {
            // today_key is runtime-only, so "" means "no previous day" (fresh
            // load): keep the persisted goal state instead of clearing it.
            let first_day = self.today_key.is_empty();
            let midnight = day_start_ms(now_ms);
            if self.current_phase.is_some() && !first_day {
                // Close [segment_start, midnight) into the old day.
                self.close_current(midnight.min(now_ms));
            }
            self.today_key = day;
            if !first_day {
                self.goal_day = None;
            }
            if self.current_phase == Some(Phase::Sitting) {
                // A stretch never spans calendar days: the old day kept its
                // share up to midnight, and the new day measures only its own.
                self.stretch_start_ms = Some(midnight);
            }
        }
        let gapped = self.gap_discarded(now_ms);
        self.close_current(now_ms);
        self.current_phase = phase;
        match phase {
            Some(Phase::Sitting) => {
                self.segment_start_ms = now_ms;
                if gapped || self.stretch_start_ms.is_none() {
                    // Sleep ends the stretch, like macOS clearing the stretch
                    // clock on wake.
                    self.stretch_start_ms = Some(now_ms);
                }
            }
            Some(_) => {
                self.segment_start_ms = now_ms;
                self.stretch_start_ms = None;
            }
            None => {
                self.stretch_start_ms = None;
            }
        }
        self.last_ms = now_ms;
        self.has_last = true;
    }

    /// A finished work session counts as one stand-up break. Manual skips call
    /// `set_phase`, never this: a skipped session is not a completed one.
    pub fn note_auto_break(&mut self) {
        if self.today_key.is_empty() {
            return;
        }
        let key = self.today_key.clone();
        let record = self.record(&key);
        record.break_count = record.break_count.saturating_add(1);
    }

    /// Today's record merged with the open segment: what the UI shows.
    /// Read-only; the open stretch keeps accruing.
    pub fn live_today(&self, now_ms: u64) -> DayRecord {
        let key = day_key(now_ms);
        let mut record = self
            .records
            .get(&key)
            .cloned()
            .unwrap_or_else(|| DayRecord::fresh(key));
        if self.current_phase.is_some() && self.today_key == record.date_key {
            let from = self.effective_start(now_ms);
            let stretch = if self.gap_discarded(now_ms) {
                None
            } else {
                self.stretch_start_ms
            };
            credit_range(&mut record, self.current_phase, from, now_ms, stretch);
        }
        record
    }

    /// Last 7 days ending today, oldest first. Missing days are zeros; today
    /// is live. Labels follow `vietnamese` ("Hôm nay", "CN", "T2".."T7") or
    /// English ("Today", "Sun".."Sat").
    pub fn week(&self, now_ms: u64, vietnamese: bool) -> Vec<WeekDay> {
        let today_count = utc7_day_count(now_ms);
        let today = self.live_today(now_ms);
        (0..7)
            .map(|back| {
                let count = today_count - (6 - back);
                let key = key_for_day_count(count);
                if back == 6 {
                    WeekDay {
                        date_key: key,
                        label: if vietnamese {
                            "Hôm nay".to_string()
                        } else {
                            "Today".to_string()
                        },
                        sitting_seconds: today.sitting_seconds,
                        standing_seconds: today.standing_seconds,
                        paused_seconds: today.paused_seconds,
                    }
                } else {
                    let stored = self.records.get(&key);
                    WeekDay {
                        date_key: key,
                        label: weekday_label(count, vietnamese),
                        sitting_seconds: stored.map(|record| record.sitting_seconds).unwrap_or(0),
                        standing_seconds: stored.map(|record| record.standing_seconds).unwrap_or(0),
                        paused_seconds: stored.map(|record| record.paused_seconds).unwrap_or(0),
                    }
                }
            })
            .collect()
    }

    /// Clears today's record and restarts the open segment now. The session
    /// clock keeps running: clearing data is not a session reset.
    pub fn reset_today(&mut self, now_ms: u64) {
        let key = day_key(now_ms);
        self.today_key = key.clone();
        self.records.insert(key.clone(), DayRecord::fresh(key));
        self.restart_open_segment(now_ms);
    }

    /// Deletes all history and restarts the open segment now.
    pub fn clear_history(&mut self, now_ms: u64) {
        self.records.clear();
        self.today_key = day_key(now_ms);
        self.restart_open_segment(now_ms);
    }

    fn restart_open_segment(&mut self, now_ms: u64) {
        // A reset restarts the stretch too: pre-reset seconds must not leak
        // back into longest-sit through the still-running stretch.
        self.stretch_start_ms = match self.current_phase {
            Some(Phase::Sitting) => Some(now_ms),
            _ => None,
        };
        if self.current_phase.is_some() {
            self.segment_start_ms = now_ms;
        }
        self.last_ms = now_ms;
        self.has_last = true;
        self.goal_day = None;
    }

    pub fn goal_notified_for(&self) -> Option<&str> {
        self.goal_day.as_deref()
    }

    pub fn mark_goal_notified(&mut self, day_key: String) {
        self.goal_day = Some(day_key);
    }

    fn gap_discarded(&self, now_ms: u64) -> bool {
        self.has_last && (now_ms as i64).saturating_sub(self.last_ms as i64) > SLEEP_GAP_MS
    }

    /// Whether the stretch ending now spans a sleep gap: callers check this
    /// before `set_phase` (which refreshes the clock) to decide if anything
    /// that happened "during" the gap — e.g. auto-advanced sessions — counts.
    pub fn gap_since_last(&self, now_ms: u64) -> bool {
        self.gap_discarded(now_ms)
    }

    /// Start of the open segment after the sleep-gap discard: a gap over two
    /// minutes means the machine slept, so the unknown interval is dropped
    /// and attribution resumes now.
    fn effective_start(&self, now_ms: u64) -> u64 {
        if !self.has_last || self.gap_discarded(now_ms) {
            now_ms
        } else {
            self.segment_start_ms
        }
    }

    fn close_current(&mut self, up_to_ms: u64) {
        let phase = self.current_phase;
        if phase.is_none() || self.today_key.is_empty() {
            return;
        }
        let from = self.effective_start(up_to_ms);
        if up_to_ms <= from {
            return;
        }
        let stretch = if self.gap_discarded(up_to_ms) {
            None
        } else {
            self.stretch_start_ms
        };
        let key = self.today_key.clone();
        let record = self.record(&key);
        let credited = credit_range(record, phase, from, up_to_ms, stretch);
        // Carry sub-second remainders in the open segment so whole-second
        // rounding never bleeds time across many small segments.
        self.segment_start_ms = from.saturating_add(credited * 1_000);
    }
}

/// Credit [from_ms, up_to_ms) into the record with `phase`. Splits at UTC+7
/// hour boundaries; a segment straddling midnight is clamped to its own day
/// by the caller (rollover closes at midnight first). Returns the whole
/// seconds credited.
fn credit_range(
    record: &mut DayRecord,
    phase: Option<Phase>,
    from_ms: u64,
    up_to_ms: u64,
    stretch_start_ms: Option<u64>,
) -> u64 {
    let Some(phase) = phase else { return 0 };
    if up_to_ms <= from_ms {
        return 0;
    }
    let seconds = (up_to_ms - from_ms) / 1_000;
    if seconds == 0 {
        return 0;
    }
    match phase {
        Phase::Sitting => record.sitting_seconds += seconds,
        Phase::Standing => record.standing_seconds += seconds,
        Phase::Paused => record.paused_seconds += seconds,
    }
    if phase == Phase::Sitting {
        // The stretch may predate this segment (it spans session
        // boundaries); sleep gaps reset the stretch to None upstream, so the
        // full stretch length is always safe to measure here.
        if let Some(start) = stretch_start_ms {
            let stretch = up_to_ms.saturating_sub(start) / 1_000;
            record.longest_sit_seconds = record.longest_sit_seconds.max(stretch);
        }
    }
    let mut hours = record.hourly.clone();
    hours.resize_with(24, HourRecord::default);
    hours.truncate(24);
    let day_end = day_end_ms(from_ms);
    let end = up_to_ms.min(day_end);
    let mut cursor = from_ms;
    while cursor < end {
        let chunk_end = hour_end_ms(cursor).min(day_end).min(end);
        if chunk_end <= cursor {
            break;
        }
        let chunk = (chunk_end - cursor) / 1_000;
        let hour = hour_of(cursor) as usize;
        if hour < 24 {
            match phase {
                Phase::Sitting => hours[hour].sitting_seconds += chunk,
                Phase::Standing => hours[hour].standing_seconds += chunk,
                Phase::Paused => hours[hour].paused_seconds += chunk,
            }
        }
        cursor = chunk_end;
    }
    record.hourly = hours;
    seconds
}

/// `"yyyy-MM-dd"` in UTC+7.
pub fn day_key(epoch_ms: u64) -> String {
    let (year, month, day) = civil_from_days(utc7_day_count(epoch_ms));
    format!("{year:04}-{month:02}-{day:02}")
}

fn key_for_day_count(day_count: i64) -> String {
    let (year, month, day) = civil_from_days(day_count);
    format!("{year:04}-{month:02}-{day:02}")
}

/// Start of the UTC+7 day holding `epoch_ms`, as epoch ms.
fn day_start_ms(epoch_ms: u64) -> u64 {
    (utc7_day_count(epoch_ms) * DAY_MS - UTC7_OFFSET_MS).max(0) as u64
}

fn day_end_ms(epoch_ms: u64) -> u64 {
    day_start_ms(epoch_ms).saturating_add(DAY_MS as u64)
}

fn hour_of(epoch_ms: u64) -> u32 {
    (((epoch_ms as i64 + UTC7_OFFSET_MS).rem_euclid(DAY_MS)) / HOUR_MS) as u32
}

fn hour_end_ms(epoch_ms: u64) -> u64 {
    let start_of_day = day_start_ms(epoch_ms);
    start_of_day.saturating_add((hour_of(epoch_ms) as u64 + 1) * (HOUR_MS as u64))
}

/// 0 = Sunday, from the UTC+7 day count (1970-01-01 was a Thursday).
fn weekday_label(day_count: i64, vietnamese: bool) -> String {
    match (day_count + 4).rem_euclid(7) {
        0 if vietnamese => "CN".to_string(),
        0 => "Sun".to_string(),
        1 if vietnamese => "T2".to_string(),
        1 => "Mon".to_string(),
        2 if vietnamese => "T3".to_string(),
        2 => "Tue".to_string(),
        3 if vietnamese => "T4".to_string(),
        3 => "Wed".to_string(),
        4 if vietnamese => "T5".to_string(),
        4 => "Thu".to_string(),
        5 if vietnamese => "T6".to_string(),
        5 => "Fri".to_string(),
        _ if vietnamese => "T7".to_string(),
        _ => "Sat".to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// 2026-10-26T12:00:00+07:00, a Monday noon.
    const BASE: u64 = 1_792_990_800_000;
    const MIN: u64 = 60_000;

    /// Simulates the 200 ms worker loop: re-attribute every minute so normal
    /// time passage never trips the sleep-gap discard (production calls
    /// `set_phase` several times a second while the app lives).
    fn drive(store: &mut StatsStore, from_ms: u64, to_ms: u64, phase: Option<Phase>) {
        let mut at = from_ms;
        while at < to_ms {
            at = (at + MIN).min(to_ms);
            store.set_phase(at, phase);
        }
    }

    #[test]
    fn day_key_and_hour_use_utc7() {
        assert_eq!(day_key(BASE), "2026-10-26");
        assert_eq!(hour_of(BASE), 12);
        let midnight = BASE - 12 * 3_600_000;
        assert_eq!(day_key(midnight), "2026-10-26");
        assert_eq!(hour_of(midnight), 0);
        assert_eq!(day_key(midnight - 1), "2026-10-25");
        assert_eq!(hour_of(midnight - 1), 23);
    }

    #[test]
    fn idle_tracks_nothing() {
        use crate::timer::Posture;
        assert_eq!(
            phase_for(TimerStatus::Idle, SessionKind::Focus, Posture::Sitting),
            None
        );
        assert_eq!(
            phase_for(TimerStatus::Idle, SessionKind::Move, Posture::Standing),
            None
        );
        assert_eq!(
            phase_for(TimerStatus::Paused, SessionKind::Focus, Posture::Standing),
            Some(Phase::Paused)
        );
    }

    #[test]
    fn work_follows_posture_and_breaks_are_rest() {
        use crate::timer::Posture;
        assert_eq!(
            phase_for(TimerStatus::Running, SessionKind::Focus, Posture::Sitting),
            Some(Phase::Sitting)
        );
        assert_eq!(
            phase_for(TimerStatus::Running, SessionKind::Focus, Posture::Standing),
            Some(Phase::Standing)
        );
        assert_eq!(
            phase_for(TimerStatus::Running, SessionKind::Sitting, Posture::Sitting),
            Some(Phase::Sitting)
        );
        assert_eq!(
            phase_for(TimerStatus::Running, SessionKind::Sitting, Posture::Standing),
            Some(Phase::Standing)
        );
        // Breaks always count as rest, never as standing: standing means
        // working upright at the desk (macOS parity).
        for session in [
            SessionKind::Move,
            SessionKind::ShortBreak,
            SessionKind::LongBreak,
        ] {
            for posture in [Posture::Sitting, Posture::Standing] {
                assert_eq!(
                    phase_for(TimerStatus::Running, session, posture),
                    Some(Phase::Paused),
                    "{session:?} with {posture:?} must be rest"
                );
            }
        }
    }

    #[test]
    fn sitting_accrues_and_merges_live() {
        let mut store = StatsStore::default();
        store.set_phase(BASE, Some(Phase::Sitting));
        drive(&mut store, BASE, BASE + 10 * MIN, Some(Phase::Sitting));
        let live = store.live_today(BASE + 10 * MIN);
        assert_eq!(live.sitting_seconds, 600);
        assert_eq!(live.date_key, "2026-10-26");
        // Closing the segment persists the same totals.
        store.set_phase(BASE + 10 * MIN, Some(Phase::Paused));
        let closed = store.live_today(BASE + 10 * MIN);
        assert_eq!(closed.sitting_seconds, 600);
        assert_eq!(closed.paused_seconds, 0);
    }

    #[test]
    fn hourly_buckets_split_at_hour_boundaries() {
        let mut store = StatsStore::default();
        // 11:30 -> 12:30, all sitting.
        let start = BASE - 30 * MIN;
        store.set_phase(start, Some(Phase::Sitting));
        drive(&mut store, start, start + 60 * MIN, Some(Phase::Sitting));
        store.set_phase(start + 60 * MIN, None);
        let today = store.live_today(start + 60 * MIN);
        assert_eq!(today.sitting_seconds, 3_600);
        assert_eq!(today.hourly[11].sitting_seconds, 1_800);
        assert_eq!(today.hourly[12].sitting_seconds, 1_800);
    }

    #[test]
    fn rollover_splits_at_utc7_midnight() {
        let mut store = StatsStore::default();
        let midnight = BASE - 12 * 3_600_000;
        store.set_phase(midnight - 10 * MIN, Some(Phase::Sitting));
        // Ten minutes later, across midnight: 10 min yesterday, 10 min today.
        drive(
            &mut store,
            midnight - 10 * MIN,
            midnight + 10 * MIN,
            Some(Phase::Sitting),
        );
        let yesterday = store.records.get("2026-10-25").cloned().unwrap();
        assert_eq!(yesterday.sitting_seconds, 600);
        let today = store.live_today(midnight + 10 * MIN);
        assert_eq!(today.date_key, "2026-10-26");
        assert_eq!(today.sitting_seconds, 600);
    }

    #[test]
    fn sleep_gap_is_discarded() {
        let mut store = StatsStore::default();
        store.set_phase(BASE, Some(Phase::Sitting));
        // Eight hours later (hibernate): the unknown interval is dropped.
        let wake = BASE + 8 * 3_600_000;
        store.set_phase(wake, Some(Phase::Sitting));
        let today = store.live_today(wake);
        assert_eq!(today.sitting_seconds, 0);
        // Time after the wake accrues normally.
        drive(&mut store, wake, wake + 5 * MIN, Some(Phase::Sitting));
        let later = store.live_today(wake + 5 * MIN);
        assert_eq!(later.sitting_seconds, 300);
    }

    #[test]
    fn longest_sit_spans_sessions_but_not_breaks() {
        let mut store = StatsStore::default();
        store.set_phase(BASE, Some(Phase::Sitting));
        // Session boundary, still sitting: the stretch continues.
        drive(&mut store, BASE, BASE + 20 * MIN, Some(Phase::Sitting));
        drive(
            &mut store,
            BASE + 20 * MIN,
            BASE + 45 * MIN,
            Some(Phase::Sitting),
        );
        store.set_phase(BASE + 45 * MIN, Some(Phase::Paused));
        let today = store.live_today(BASE + 45 * MIN);
        assert_eq!(today.sitting_seconds, 45 * 60);
        assert_eq!(today.longest_sit_seconds, 45 * 60);
        // A later 10-minute sit is shorter than the recorded longest.
        drive(
            &mut store,
            BASE + 45 * MIN,
            BASE + 60 * MIN,
            Some(Phase::Paused),
        );
        drive(
            &mut store,
            BASE + 60 * MIN,
            BASE + 70 * MIN,
            Some(Phase::Sitting),
        );
        let later = store.live_today(BASE + 70 * MIN);
        assert_eq!(later.longest_sit_seconds, 45 * 60);
    }

    #[test]
    fn auto_breaks_count_manual_phases_do_not() {
        let mut store = StatsStore::default();
        store.set_phase(BASE, Some(Phase::Sitting));
        store.note_auto_break();
        store.note_auto_break();
        assert_eq!(store.live_today(BASE).break_count, 2);
    }

    #[test]
    fn reset_today_and_clear_history_keep_the_clock() {
        let mut store = StatsStore::default();
        store.set_phase(BASE, Some(Phase::Sitting));
        store.note_auto_break();
        store.reset_today(BASE + 5 * MIN);
        let today = store.live_today(BASE + 5 * MIN);
        assert_eq!(today.sitting_seconds, 0);
        assert_eq!(today.break_count, 0);
        // The still-running segment accrues again after the reset.
        assert_eq!(store.live_today(BASE + 6 * MIN).sitting_seconds, 60);
        store.clear_history(BASE + 6 * MIN);
        assert!(store.records.is_empty());
        assert_eq!(store.live_today(BASE + 7 * MIN).sitting_seconds, 60);
    }

    #[test]
    fn week_is_seven_days_oldest_first_with_today_live() {
        let mut store = StatsStore::default();
        store.set_phase(BASE, Some(Phase::Sitting));
        let week = store.week(BASE + 60, false);
        assert_eq!(week.len(), 7);
        assert_eq!(week[6].label, "Today");
        assert_eq!(week[6].sitting_seconds, 0);
        // Monday noon: six days back is the previous Tuesday.
        assert_eq!(week[0].label, "Tue");
        assert_eq!(week[5].label, "Sun");
        let vi = store.week(BASE + 60, true);
        assert_eq!(vi[6].label, "Hôm nay");
        assert_eq!(vi[0].label, "T3");
        // Date keys are consecutive.
        assert!(week[0].date_key < week[6].date_key);
        assert_eq!(week[6].date_key, "2026-10-26");
    }

    #[test]
    fn rollover_restarts_the_sitting_stretch() {
        let mut store = StatsStore::default();
        let midnight = BASE - 12 * 3_600_000;
        store.set_phase(midnight - 10 * MIN, Some(Phase::Sitting));
        drive(
            &mut store,
            midnight - 10 * MIN,
            midnight + 10 * MIN,
            Some(Phase::Sitting),
        );
        // The old day keeps its 10 minutes up to midnight; the new day
        // measures only its own 10 minutes, not the whole 20-minute stretch.
        let yesterday = store.records.get("2026-10-25").cloned().unwrap();
        assert_eq!(yesterday.sitting_seconds, 600);
        assert_eq!(yesterday.longest_sit_seconds, 600);
        let today = store.live_today(midnight + 10 * MIN);
        assert_eq!(today.sitting_seconds, 600);
        assert_eq!(today.longest_sit_seconds, 600);
    }

    #[test]
    fn goal_day_survives_a_save_load_round_trip() {
        let mut store = StatsStore::default();
        store.set_phase(BASE, Some(Phase::Standing));
        store.mark_goal_notified("2026-10-26".to_string());
        let json = serde_json::to_string(&store).unwrap();
        assert!(json.contains("goalDay"));
        let restored: StatsStore = serde_json::from_str(&json).unwrap();
        assert_eq!(restored.goal_notified_for(), Some("2026-10-26"));
        // A store saved before goal tracking existed loads un-notified.
        let legacy: StatsStore = serde_json::from_str(r#"{"records":{}}"#).unwrap();
        assert_eq!(legacy.goal_notified_for(), None);
    }

    #[test]
    fn goal_survives_a_same_day_restart() {
        let mut store = StatsStore::default();
        store.set_phase(BASE, Some(Phase::Standing));
        store.mark_goal_notified("2026-10-26".to_string());
        let json = serde_json::to_string(&store).unwrap();
        let mut reloaded: StatsStore = serde_json::from_str(&json).unwrap();
        // First attribution after restart is the same day: the persisted
        // notification stays sent instead of refiring.
        reloaded.set_phase(BASE + 60_000, Some(Phase::Standing));
        assert_eq!(reloaded.goal_notified_for(), Some("2026-10-26"));
        // The next day still rolls over and clears it.
        reloaded.set_phase(BASE + 24 * 3_600_000, Some(Phase::Standing));
        assert_eq!(reloaded.goal_notified_for(), None);
    }

    #[test]
    fn short_hourly_vectors_from_older_files_are_tolerated() {
        let mut record: DayRecord =
            serde_json::from_str(r#"{"dateKey":"2026-10-26","sittingSeconds":60,"hourly":[]}"#)
                .unwrap();
        assert_eq!(record.hourly.len(), 0);
        let credited = credit_range(
            &mut record,
            Some(Phase::Sitting),
            BASE,
            BASE + 2 * MIN,
            None,
        );
        assert_eq!(credited, 120);
        assert_eq!(record.hourly.len(), 24);
        assert_eq!(record.hourly[12].sitting_seconds, 120);
    }
}
