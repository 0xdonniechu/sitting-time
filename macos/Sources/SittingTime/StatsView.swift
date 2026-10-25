import Charts
import SwiftUI
import SittingCore

/// Weekly overview window: grouped bar chart + per-day rows.
struct StatsView: View {
    // From .environment(store): see MenuBarView.
    @Environment(SittingStore.self) private var store

    var body: some View {
        let _ = store.tickCount
        let week = store.weekData()
        let totalSit = week.reduce(0) { $0 + $1.sittingSeconds }
        let totalStand = week.reduce(0) { $0 + $1.standingSeconds }
        VStack(alignment: .leading, spacing: 12) {
            Text("7 ngày qua")
                .font(.title2).bold()
            Text("Ngồi \(formatDuration(totalSit)) • Đứng \(formatDuration(totalStand))")
                .foregroundStyle(.secondary)

            Chart(week) { day in
                BarMark(
                    x: .value("Ngày", day.label),
                    y: .value("Giờ", day.sittingSeconds / 3600)
                )
                .foregroundStyle(by: .value("Trạng thái", "Ngồi"))
                BarMark(
                    x: .value("Ngày", day.label),
                    y: .value("Giờ", day.standingSeconds / 3600)
                )
                .foregroundStyle(by: .value("Trạng thái", "Đứng"))
            }
            .chartForegroundStyleScale(["Ngồi": .orange, "Đứng": .green])
            .chartYAxisLabel("giờ")
            .frame(height: 220)

            Divider()

            ForEach(week.reversed()) { day in
                HStack {
                    Text(day.label)
                        .frame(width: 64, alignment: .leading)
                    Spacer()
                    Text("Ngồi \(formatDuration(day.sittingSeconds))")
                    Text("Đứng \(formatDuration(day.standingSeconds))")
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
