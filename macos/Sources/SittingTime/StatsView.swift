import Charts
import SwiftUI
import SittingCore

/// Weekly overview window: grouped bar chart + per-day rows.
struct StatsView: View {
    // From .environment(store): see MenuBarView.
    @Environment(SittingStore.self) private var store

    var body: some View {
        let _ = store.tickCount
        let lang = store.settings.language
        let strings = Strings(lang)
        let week = store.weekData()
        let totalSit = week.reduce(0) { $0 + $1.sittingSeconds }
        let totalStand = week.reduce(0) { $0 + $1.standingSeconds }
        VStack(alignment: .leading, spacing: 12) {
            Text(strings.weekTitle)
                .font(.title2).bold()
            Text(strings.totalLine(
                sitting: formatDuration(totalSit, language: lang),
                standing: formatDuration(totalStand, language: lang)
            ))
            .foregroundStyle(.secondary)

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
            }
            .chartForegroundStyleScale([strings.chartSitting: .orange, strings.chartStanding: .green])
            .chartYAxisLabel(strings.yAxisHours)
            .frame(height: 220)

            Divider()

            ForEach(week.reversed()) { day in
                HStack {
                    Text(day.label)
                        .frame(width: 64, alignment: .leading)
                    Spacer()
                    Text(strings.daySitting(formatDuration(day.sittingSeconds, language: lang)))
                    Text(strings.dayStanding(formatDuration(day.standingSeconds, language: lang)))
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
                .monospacedDigit()
            }
        }
        .padding(20)
        .frame(width: 480)
    }
}
