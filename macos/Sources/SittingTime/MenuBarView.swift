import AppKit
import SwiftUI
import SittingCore

/// The popover: big timer, phase switcher, today's totals, footer actions.
/// Hosted in an NSPopover (see AppDelegate), so the stats window opens through
/// the `openStats` closure: `openWindow` needs a SwiftUI scene environment.
struct MenuBarView: View {
    // Observed through .environment(store); the body also reads tickCount
    // so the view re-renders every second (see SittingStore.tickCount).
    @Environment(SittingStore.self) private var store
    let openStats: () -> Void

    var body: some View {
        let _ = store.tickCount
        let today = store.liveToday()
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.phase.title)
                        .font(.headline)
                    Text(formatElapsed(store.openElapsed))
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                }
                Spacer()
                Image(systemName: store.phase.symbol)
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
            }

            if store.autoPaused {
                Text("Tự tạm nghỉ vì không dùng máy — sẽ tiếp tục khi bạn quay lại.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker("Trạng thái", selection: Binding(
                get: { store.phase },
                set: { store.setPhase($0) }
            )) {
                ForEach(SitPhase.allCases, id: \.self) { phase in
                    Text(phase.shortTitle).tag(phase)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Button(store.phase == .paused ? "Tiếp tục" : "Tạm nghỉ") {
                store.togglePause()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)

            Divider()

            Text("Hôm nay")
                .font(.subheadline).bold()
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    Label("Ngồi", systemImage: SitPhase.sitting.symbol)
                    Text(formatDuration(today.sittingSeconds)).monospacedDigit()
                }
                GridRow {
                    Label("Đứng", systemImage: SitPhase.standing.symbol)
                    Text(formatDuration(today.standingSeconds)).monospacedDigit()
                }
                GridRow {
                    Label("Nghỉ", systemImage: SitPhase.paused.symbol)
                    Text(formatDuration(today.pausedSeconds)).monospacedDigit()
                }
            }
            .font(.callout)

            if store.settings.standGoalMinutes > 0 {
                let goal = TimeInterval(store.settings.standGoalMinutes * 60)
                ProgressView(value: min(1, today.standingSeconds / goal)) {
                    Text("Mục tiêu đứng \(formatDuration(goal))")
                        .font(.caption)
                }
            }

            Text("Nghỉ \(today.breakCount) lần • Ngồi lâu nhất \(formatDuration(today.longestSitSeconds))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            HStack {
                Button("Thống kê") { openStats() }
                Button("Cài đặt…") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                Spacer()
                Button("Thoát") { NSApplication.shared.terminate(nil) }
            }
            .buttonStyle(.link)
        }
        .padding(14)
        .frame(width: 300)
    }
}
