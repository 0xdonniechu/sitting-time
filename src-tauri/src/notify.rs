//! Notification copy in both languages, like the macOS strings table. Pure
//! functions so the wording is unit-tested without the Tauri shell.

use crate::timer::SessionKind;

/// Session-change alert (title, body). English is the default; Vietnamese
/// mirrors the macOS voice.
pub fn session_alert(session: SessionKind, vietnamese: bool) -> (&'static str, &'static str) {
    if vietnamese {
        return match session {
            SessionKind::Focus => (
                "Hết giờ nghỉ, vào phiên mới!",
                "Sẵn sàng cho phiên tập trung mới",
            ),
            SessionKind::ShortBreak => ("Xong phiên tập trung!", "Nghỉ ngắn một chút cho khỏe"),
            SessionKind::LongBreak => ("Xong một vòng tập trung!", "Nghỉ dài cho khỏe"),
            SessionKind::Sitting => ("Hết giờ vận động!", "Quay lại làm việc thôi"),
            SessionKind::Move => ("Đến giờ đứng dậy!", "Đi lại vài phút cho khỏe"),
        };
    }
    match session {
        SessionKind::Focus => ("Break complete", "Ready for another focus session"),
        SessionKind::ShortBreak => ("Focus session complete", "Take a short break"),
        SessionKind::LongBreak => ("Focus cycle complete", "Take a long break"),
        SessionKind::Sitting => ("Break complete", "You can return to work"),
        SessionKind::Move => ("Time to stand up", "Move around for a few minutes"),
    }
}

/// `"1 hour"`, `"2 hours 5 minutes"` (or `"1 giờ"`, `"2 giờ 5 phút"`):
/// compact goal size for the notification and the progress label.
pub fn format_goal(minutes: u32, vietnamese: bool) -> String {
    let hours = minutes / 60;
    let rest = minutes % 60;
    if vietnamese {
        match (hours, rest) {
            (0, _) => format!("{rest} phút"),
            (_, 0) => format!("{hours} giờ"),
            _ => format!("{hours} giờ {rest} phút"),
        }
    } else {
        let hour_part = match hours {
            0 => None,
            1 => Some("1 hour".to_string()),
            _ => Some(format!("{hours} hours")),
        };
        let minute_part = match rest {
            0 => None,
            1 => Some("1 minute".to_string()),
            _ => Some(format!("{rest} minutes")),
        };
        match (hour_part, minute_part) {
            (None, None) => "0 minutes".to_string(),
            (Some(one), None) | (None, Some(one)) => one,
            (Some(hours), Some(minutes)) => format!("{hours} {minutes}"),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn goal_formatting_matches_both_languages() {
        assert_eq!(format_goal(60, false), "1 hour");
        assert_eq!(format_goal(90, false), "1 hour 30 minutes");
        assert_eq!(format_goal(45, false), "45 minutes");
        assert_eq!(format_goal(1, false), "1 minute");
        assert_eq!(format_goal(60, true), "1 giờ");
        assert_eq!(format_goal(90, true), "1 giờ 30 phút");
        assert_eq!(format_goal(45, true), "45 phút");
    }

    #[test]
    fn alerts_are_filled_in_both_languages() {
        let sessions = [
            SessionKind::Focus,
            SessionKind::ShortBreak,
            SessionKind::LongBreak,
            SessionKind::Sitting,
            SessionKind::Move,
        ];
        for session in sessions {
            for vietnamese in [false, true] {
                let (title, body) = session_alert(session, vietnamese);
                assert!(!title.is_empty() && !body.is_empty());
            }
        }
        assert_eq!(
            session_alert(SessionKind::Move, false).0,
            "Time to stand up"
        );
        assert_eq!(
            session_alert(SessionKind::Move, true).0,
            "Đến giờ đứng dậy!"
        );
    }
}
