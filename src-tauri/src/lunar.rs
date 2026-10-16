//! Today's solar date and Vietnamese lunar date, in the fixed UTC+7 time zone
//! the Vietnamese calendar is defined in. The lunar conversion is Hồ Ngọc Đức's
//! algorithm (based on Meeus, "Astronomical Algorithms").

use serde::Serialize;
use std::f64::consts::PI;
use std::time::{SystemTime, UNIX_EPOCH};

const TIME_ZONE_HOURS: f64 = 7.0;
const JULIAN_DAY_OF_UNIX_EPOCH: i64 = 2_440_588;
const CAN: [&str; 10] = ["Giáp", "Ất", "Bính", "Đinh", "Mậu", "Kỷ", "Canh", "Tân", "Nhâm", "Quý"];
const CHI: [&str; 12] = ["Tý", "Sửu", "Dần", "Mão", "Thìn", "Tỵ", "Ngọ", "Mùi", "Thân", "Dậu", "Tuất", "Hợi"];

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CalendarDay {
    pub solar_day: u32,
    pub solar_month: u32,
    pub solar_year: i32,
    /// 0 = Sunday.
    pub weekday: u32,
    pub lunar_day: u32,
    pub lunar_month: u32,
    pub lunar_year: i32,
    pub lunar_leap: bool,
    pub lunar_year_name: String,
}

pub fn today() -> CalendarDay {
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis()
        .try_into()
        .unwrap_or(u64::MAX);
    calendar_day(now)
}

pub fn calendar_day(epoch_ms: u64) -> CalendarDay {
    let local_seconds = (epoch_ms / 1_000) as i64 + TIME_ZONE_HOURS as i64 * 3_600;
    let days = local_seconds.div_euclid(86_400);
    let (solar_year, solar_month, solar_day) = civil_from_days(days);
    let lunar = solar_to_lunar(days + JULIAN_DAY_OF_UNIX_EPOCH, solar_year);
    CalendarDay {
        solar_day,
        solar_month,
        solar_year,
        weekday: (days + 4).rem_euclid(7) as u32,
        lunar_day: lunar.day,
        lunar_month: lunar.month,
        lunar_year: lunar.year,
        lunar_leap: lunar.leap,
        lunar_year_name: year_name(lunar.year),
    }
}

fn year_name(year: i32) -> String {
    let can = CAN[(year + 6).rem_euclid(10) as usize];
    let chi = CHI[(year + 8).rem_euclid(12) as usize];
    format!("{can} {chi}")
}

/// Howard Hinnant's days-since-1970 to proleptic Gregorian (year, month, day).
fn civil_from_days(days: i64) -> (i32, u32, u32) {
    let z = days + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z.rem_euclid(146_097);
    let yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let day = (doy - (153 * mp + 2) / 5 + 1) as u32;
    let month = if mp < 10 { mp + 3 } else { mp - 9 } as u32;
    let year = (yoe + era * 400 + i64::from(month <= 2)) as i32;
    (year, month, day)
}

fn jd_from_date(day: i64, month: i64, year: i64) -> i64 {
    let a = (14 - month) / 12;
    let y = year + 4_800 - a;
    let m = month + 12 * a - 3;
    let jd = day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32_045;
    if jd < 2_299_161 {
        day + (153 * m + 2) / 5 + 365 * y + y / 4 - 32_083
    } else {
        jd
    }
}

/// Julian day of the k-th new moon after 1900-01-01 (time of day included).
fn new_moon(k: i64) -> f64 {
    let k = k as f64;
    let t = k / 1_236.85;
    let t2 = t * t;
    let t3 = t2 * t;
    let dr = PI / 180.0;
    let mut jd1 = 2_415_020.759_33 + 29.530_588_68 * k + 0.000_117_8 * t2 - 0.000_000_155 * t3;
    jd1 += 0.000_33 * ((166.56 + 132.87 * t - 0.009_173 * t2) * dr).sin();
    let m = 359.224_2 + 29.105_356_08 * k - 0.000_033_3 * t2 - 0.000_003_47 * t3;
    let mpr = 306.025_3 + 385.816_918_06 * k + 0.010_730_6 * t2 + 0.000_012_36 * t3;
    let f = 21.296_4 + 390.670_506_46 * k - 0.001_652_8 * t2 - 0.000_002_39 * t3;
    let mut c1 = (0.173_4 - 0.000_393 * t) * (m * dr).sin() + 0.002_1 * (2.0 * dr * m).sin();
    c1 = c1 - 0.406_8 * (mpr * dr).sin() + 0.016_1 * (dr * 2.0 * mpr).sin();
    c1 -= 0.000_4 * (dr * 3.0 * mpr).sin();
    c1 = c1 + 0.010_4 * (dr * 2.0 * f).sin() - 0.005_1 * (dr * (m + mpr)).sin();
    c1 = c1 - 0.007_4 * (dr * (m - mpr)).sin() + 0.000_4 * (dr * (2.0 * f + m)).sin();
    c1 = c1 - 0.000_4 * (dr * (2.0 * f - m)).sin() - 0.000_6 * (dr * (2.0 * f + mpr)).sin();
    c1 = c1 + 0.001_0 * (dr * (2.0 * f - mpr)).sin() + 0.000_5 * (dr * (2.0 * mpr + m)).sin();
    let delta_t = if t < -11.0 {
        0.001 + 0.000_839 * t + 0.000_226_1 * t2 - 0.000_008_45 * t3 - 0.000_000_081 * t * t3
    } else {
        -0.000_278 + 0.000_265 * t + 0.000_262 * t2
    };
    jd1 + c1 - delta_t
}

/// Local day number of the k-th new moon.
fn new_moon_day(k: i64) -> i64 {
    (new_moon(k) + 0.5 + TIME_ZONE_HOURS / 24.0).floor() as i64
}

/// Sun's longitude in radians, normalised to [0, 2π), at a Julian day.
fn sun_longitude(jdn: f64) -> f64 {
    let t = (jdn - 2_451_545.0) / 36_525.0;
    let t2 = t * t;
    let dr = PI / 180.0;
    let m = 357.529_10 + 35_999.050_30 * t - 0.000_155_9 * t2 - 0.000_000_48 * t * t2;
    let l0 = 280.466_45 + 36_000.769_83 * t + 0.000_303_2 * t2;
    let mut dl = (1.914_600 - 0.004_817 * t - 0.000_014 * t2) * (dr * m).sin();
    dl = dl + (0.019_993 - 0.000_101 * t) * (dr * 2.0 * m).sin() + 0.000_290 * (dr * 3.0 * m).sin();
    let l = (l0 + dl) * dr;
    l - PI * 2.0 * (l / (PI * 2.0)).floor()
}

/// Sun longitude sector (0..=11, 30° each) at the start of a local day.
fn sun_sector(day_number: i64) -> i64 {
    (sun_longitude(day_number as f64 - 0.5 - TIME_ZONE_HOURS / 24.0) / PI * 6.0).floor() as i64
}

/// Day number of the start of lunar month 11 (the month holding the winter solstice).
fn lunar_month_11(year: i64) -> i64 {
    let off = jd_from_date(31, 12, year) - 2_415_021;
    let k = (off as f64 / 29.530_588_853).floor() as i64;
    let nm = new_moon_day(k);
    if sun_sector(nm) >= 9 {
        new_moon_day(k - 1)
    } else {
        nm
    }
}

/// Months after month 11 at which the leap month falls.
fn leap_month_offset(a11: i64) -> i64 {
    let k = ((a11 as f64 - 2_415_021.076_998_695) / 29.530_588_853 + 0.5).floor() as i64;
    let mut i = 1;
    let mut arc = sun_sector(new_moon_day(k + i));
    loop {
        let last = arc;
        i += 1;
        arc = sun_sector(new_moon_day(k + i));
        if arc == last || i >= 14 {
            break;
        }
    }
    i - 1
}

struct LunarDate {
    day: u32,
    month: u32,
    year: i32,
    leap: bool,
}

fn solar_to_lunar(day_number: i64, solar_year: i32) -> LunarDate {
    let year = i64::from(solar_year);
    let mut k = ((day_number as f64 - 2_415_021.076_998_695) / 29.530_588_853).floor() as i64 + 1;
    let mut month_start = new_moon_day(k);
    // The reference steps back only once; a new moon just after local midnight
    // (e.g. 2054-05-08 00:00 UTC+7) needs a second step, or the day reads as 0.
    while month_start > day_number {
        k -= 1;
        month_start = new_moon_day(k);
    }
    let mut a11 = lunar_month_11(year);
    let mut b11 = a11;
    let mut lunar_year;
    if a11 >= month_start {
        lunar_year = year;
        a11 = lunar_month_11(year - 1);
    } else {
        lunar_year = year + 1;
        b11 = lunar_month_11(year + 1);
    }
    let lunar_day = day_number - month_start + 1;
    let diff = (month_start - a11) / 29;
    let mut leap = false;
    let mut lunar_month = diff + 11;
    if b11 - a11 > 365 {
        let leap_diff = leap_month_offset(a11);
        if diff >= leap_diff {
            lunar_month = diff + 10;
            leap = diff == leap_diff;
        }
    }
    if lunar_month > 12 {
        lunar_month -= 12;
    }
    if lunar_month >= 11 && diff < 4 {
        lunar_year -= 1;
    }
    LunarDate {
        day: lunar_day as u32,
        month: lunar_month as u32,
        year: lunar_year as i32,
        leap,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Epoch milliseconds for 00:00 local (UTC+7) on a solar date.
    fn local_midnight(year: i64, month: i64, day: i64) -> u64 {
        let days = jd_from_date(day, month, year) - JULIAN_DAY_OF_UNIX_EPOCH;
        ((days * 86_400 - 7 * 3_600) * 1_000) as u64
    }

    fn lunar(year: i64, month: i64, day: i64) -> (u32, u32, i32, bool) {
        let d = calendar_day(local_midnight(year, month, day));
        (d.lunar_day, d.lunar_month, d.lunar_year, d.lunar_leap)
    }

    #[test]
    fn tet_dates_match_the_vietnamese_calendar() {
        let tet = [
            (1985, 1, 21),
            (2007, 2, 17),
            (2020, 1, 25),
            (2021, 2, 12),
            (2022, 2, 1),
            (2023, 1, 22),
            (2024, 2, 10),
            (2025, 1, 29),
            (2026, 2, 17),
            (2027, 2, 6),
            // New moon 2030-02-02 ~16:07 UTC: 23:07 in UTC+7 (Tết Feb 2), 00:07
            // in UTC+8 (Chinese New Year Feb 3). Like 1985 and 2007, the calendars split.
            (2030, 2, 2),
        ];
        for (year, month, day) in tet {
            assert_eq!(lunar(year, month, day), (1, 1, year as i32, false), "Tết {year}");
            let eve = calendar_day(local_midnight(year, month, day) - 86_400_000);
            assert!(
                !(eve.lunar_day == 1 && eve.lunar_month == 1),
                "day before Tết {year} must not be 1/1"
            );
        }
    }

    #[test]
    fn leap_months_are_marked() {
        assert_eq!(lunar(2020, 5, 23), (1, 4, 2020, true));
        assert_eq!(lunar(2023, 3, 22), (1, 2, 2023, true));
        assert_eq!(lunar(2025, 7, 25), (1, 6, 2025, true));
    }

    #[test]
    fn new_moon_just_after_midnight_does_not_give_day_zero() {
        assert_eq!(lunar(2054, 5, 7), (30, 3, 2054, false));
        assert_eq!(lunar(2054, 5, 8).0, 1);
        assert_eq!(lunar(2062, 4, 9), (30, 2, 2062, false));
    }

    #[test]
    fn year_names_follow_can_chi() {
        assert_eq!(year_name(2026), "Bính Ngọ");
        assert_eq!(year_name(1985), "Ất Sửu");
        assert_eq!(year_name(2020), "Canh Tý");
    }

    #[test]
    fn solar_date_switches_at_local_midnight() {
        let before = calendar_day(local_midnight(2026, 10, 16) - 1_000);
        let after = calendar_day(local_midnight(2026, 10, 16));
        assert_eq!((before.solar_day, before.solar_month, before.solar_year), (15, 10, 2026));
        assert_eq!((after.solar_day, after.solar_month, after.solar_year), (16, 10, 2026));
        assert_eq!(after.weekday, 5);
    }
}
