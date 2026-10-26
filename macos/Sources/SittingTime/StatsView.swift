import Charts
import SwiftUI
import SittingCore

/// Screen Time-style statistics window: Day/Week scope, big total, stacked
/// bars (hourly for the day, daily for the week), category legend, rows.
struct StatsView: View {
    // From .environment(store): see MenuBarView.
    @Environment(SittingStore.self) private var store
    @State private var scope: Scope = .day

    /// Closes the window and reopens the popover dash. Nil hides the button.
    var onReturnToDash: (() -> Void)?

    enum Scope: Hashable {
        case day
        case week
    }

    init(scope: Scope = .day, onReturnToDash: (() -> Void)? = nil) {
        _scope = State(initialValue: scope)
        self.onReturnToDash = onReturnToDash
    }

    var body: some View {
        ScrollView {
            StatsContentView(store: store, scope: $scope, onReturnToDash: onReturnToDash)
        }
        .frame(width: 560)
    }
}

/// The scroll body as a standalone view: it takes the store directly (plain
/// property — @Observable tracking still works), so previews can render it
/// without a ScrollView (which draws blank in ImageRenderer).
struct StatsContentView: View {
    let store: SittingStore
    @Binding var scope: StatsView.Scope
    var onReturnToDash: (() -> Void)?

    var body: some View {
        let _ = store.tickCount
        let lang = store.settings.language
        let strings = Strings(lang)
        let week = store.weekData()
        let today = store.liveToday()
        let sit: TimeInterval = scope == .day
            ? today.sittingSeconds : week.reduce(0) { $0 + $1.sittingSeconds }
        let stand: TimeInterval = scope == .day
            ? today.standingSeconds : week.reduce(0) { $0 + $1.standingSeconds }
        let rest: TimeInterval = scope == .day
            ? today.pausedSeconds : week.reduce(0) { $0 + $1.pausedSeconds }
        let total = sit + stand + rest
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let onReturnToDash {
                    Button(action: onReturnToDash) {
                        Label(strings.backButton, systemImage: "chevron.left")
                    }
                    .buttonStyle(.link)
                }
                Spacer()
                Picker("", selection: $scope) {
                    Text(strings.statsDay).tag(StatsView.Scope.day)
                    Text(strings.statsWeek).tag(StatsView.Scope.week)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            Text(strings.statsPanelTitle)
                .font(.title2).bold()
            Text(formatDuration(total, language: lang))
                .font(.system(size: 34, weight: .semibold))
            if scope == .week {
                Text(strings.statsDailyAverage(formatDuration(total / 7, language: lang)))
                    .foregroundStyle(.secondary)
            }

            if total <= 0 {
                Text(strings.statsNoActivity)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if scope == .day {
                dayChart(today: today, strings: strings)
            } else {
                weekChart(week: week, strings: strings)
            }

            legendRow(color: .orange, label: strings.chartSitting, seconds: sit, lang: lang)
            legendRow(color: .green, label: strings.chartStanding, seconds: stand, lang: lang)
            legendRow(color: .gray, label: strings.chartRest, seconds: rest, lang: lang)

            Divider()

            if scope == .week {
                Text(strings.weekTitle)
                    .font(.headline)
                ForEach(week.reversed()) { day in
                    dayRow(day: day, lang: lang)
                }
            } else {
                Text(strings.todayLabel)
                    .font(.headline)
                Text(strings.breaksLine(
                    count: today.breakCount,
                    longest: formatDuration(today.longestSitSeconds, language: lang)
                ))
                .font(.callout)
                .foregroundStyle(.secondary)
                if store.settings.standGoalMinutes > 0 {
                    let goal = TimeInterval(store.settings.standGoalMinutes * 60)
                    ProgressView(value: min(1, today.standingSeconds / goal)) {
                        Text(strings.goalProgress(formatDuration(goal, language: lang)))
                            .font(.caption)
                    }
                }
            }
        }
        .padding(20)
    }

    private func dayChart(today: DayRecord, strings: Strings) -> some View {
        Chart(0..<24, id: \.self) { hour in
            let bucket = today.hourly[hour]
            BarMark(
                x: .value(strings.chartHour, hour),
                y: .value(strings.chartHour, bucket.sittingSeconds / 3600)
            )
            .foregroundStyle(by: .value(strings.statusPickerLabel, strings.chartSitting))
            BarMark(
                x: .value(strings.chartHour, hour),
                y: .value(strings.chartHour, bucket.standingSeconds / 3600)
            )
            .foregroundStyle(by: .value(strings.statusPickerLabel, strings.chartStanding))
            BarMark(
                x: .value(strings.chartHour, hour),
                y: .value(strings.chartHour, bucket.pausedSeconds / 3600)
            )
            .foregroundStyle(by: .value(strings.statusPickerLabel, strings.chartRest))
        }
        .chartForegroundStyleScale([
            strings.chartSitting: .orange,
            strings.chartStanding: .green,
            strings.chartRest: .gray,
        ])
        .chartXAxis {
            AxisMarks(values: [0, 6, 12, 18])
        }
        .chartYAxisLabel(strings.yAxisHours)
        .chartLegend(.hidden)
        .frame(height: 200)
    }

    private func weekChart(week: [WeekDay], strings: Strings) -> some View {
        Chart(week) { day in
            BarMark(
                x: .value(strings.chartDay, day.label),
                y: .value(strings.chartHour, day.sittingSeconds / 3600)
            )
            .foregroundStyle(by: .value(strings.statusPickerLabel, strings.chartSitting))
            BarMark(
                x: .value(strings.chartDay, day.label),
                y: .value(strings.chartHour, day.standingSeconds / 3600)
            )
            .foregroundStyle(by: .value(strings.statusPickerLabel, strings.chartStanding))
            BarMark(
                x: .value(strings.chartDay, day.label),
                y: .value(strings.chartHour, day.pausedSeconds / 3600)
            )
            .foregroundStyle(by: .value(strings.statusPickerLabel, strings.chartRest))
        }
        .chartForegroundStyleScale([
            strings.chartSitting: .orange,
            strings.chartStanding: .green,
            strings.chartRest: .gray,
        ])
        .chartYAxisLabel(strings.yAxisHours)
        .chartLegend(.hidden)
        .frame(height: 200)
    }

    private func legendRow(color: Color, label: String, seconds: TimeInterval, lang: AppLanguage) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
            Spacer()
            Text(formatDuration(seconds, language: lang))
                .monospacedDigit()
        }
        .font(.callout)
    }

    private func dayRow(day: WeekDay, lang: AppLanguage) -> some View {
        HStack {
            Text(day.label)
                .frame(width: 64, alignment: .leading)
            GeometryReader { geo in
                HStack(spacing: 1) {
                    let total = day.trackedSeconds
                    if total > 0 {
                        if day.sittingSeconds > 0 {
                            Rectangle()
                                .fill(.orange)
                                .frame(width: geo.size.width * day.sittingSeconds / total)
                        }
                        if day.standingSeconds > 0 {
                            Rectangle()
                                .fill(.green)
                                .frame(width: geo.size.width * day.standingSeconds / total)
                        }
                        if day.pausedSeconds > 0 {
                            Rectangle()
                                .fill(.gray)
                                .frame(width: geo.size.width * day.pausedSeconds / total)
                        }
                    } else {
                        Rectangle()
                            .fill(.quaternary)
                    }
                }
            }
            .frame(height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            Spacer()
            Text(formatDuration(day.trackedSeconds, language: lang))
                .frame(width: 120, alignment: .trailing)
        }
        .font(.callout)
        .monospacedDigit()
    }
}
