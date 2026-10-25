import AppKit
import SwiftUI
import SittingCore

/// The popover: big timer, phase switcher, today's totals, quote of the day,
/// footer actions. Hosted in an NSPopover (see AppDelegate), so the stats
/// window opens through the `openStats` closure: `openWindow` needs a
/// SwiftUI scene environment.
struct MenuBarView: View {
    // Observed through .environment(store); the body also reads tickCount
    // so the view re-renders every second (see SittingStore.tickCount).
    @Environment(SittingStore.self) private var store
    let openStats: () -> Void

    var body: some View {
        let _ = store.tickCount
        let lang = store.settings.language
        let strings = Strings(lang)
        let today = store.liveToday()
        let tile = subCalendarDate(for: Date(), calendar: store.settings.subCalendar, language: lang)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.phase.title(in: lang))
                        .font(.headline)
                    Text(formatElapsed(store.openElapsed))
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Image(systemName: store.phase.symbol)
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    if let tile {
                        CalendarTile(date: tile)
                    }
                }
            }

            if store.autoPaused {
                Text(strings.autoPausedNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker(strings.statusPickerLabel, selection: Binding(
                get: { store.phase },
                set: { store.setPhase($0) }
            )) {
                ForEach(SitPhase.allCases, id: \.self) { phase in
                    Text(phase.shortTitle(in: lang)).tag(phase)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Button(store.phase == .paused ? strings.resumeButton : strings.pauseButton) {
                store.togglePause()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)

            Divider()

            Text(strings.todaySection)
                .font(.subheadline).bold()
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    Label(strings.phaseShort(.sitting), systemImage: SitPhase.sitting.symbol)
                    Text(formatDuration(today.sittingSeconds, language: lang)).monospacedDigit()
                }
                GridRow {
                    Label(strings.phaseShort(.standing), systemImage: SitPhase.standing.symbol)
                    Text(formatDuration(today.standingSeconds, language: lang)).monospacedDigit()
                }
                GridRow {
                    Label(strings.phaseShort(.paused), systemImage: SitPhase.paused.symbol)
                    Text(formatDuration(today.pausedSeconds, language: lang)).monospacedDigit()
                }
            }
            .font(.callout)

            if store.settings.standGoalMinutes > 0 {
                let goal = TimeInterval(store.settings.standGoalMinutes * 60)
                ProgressView(value: min(1, today.standingSeconds / goal)) {
                    Text(strings.goalProgress(formatDuration(goal, language: lang)))
                        .font(.caption)
                }
            }

            Text(strings.breaksLine(count: today.breakCount, longest: formatDuration(today.longestSitSeconds, language: lang)))
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            HStack {
                Button(strings.statsButton) { openStats() }
                Button(strings.settingsButton) {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                Spacer()
                Button(strings.quitButton) { NSApplication.shared.terminate(nil) }
            }
            .buttonStyle(.link)
        }
        .padding(14)
        .frame(width: 300)
    }
}

/// Small red tile with the secondary-calendar day, like the Tauri app's
/// calendar tile. Hovering shows the full date.
struct CalendarTile: View {
    let date: SubCalendarDate

    var body: some View {
        VStack(spacing: 0) {
            Text(date.day)
                .font(.system(size: 18, weight: .bold))
            Text(date.sub)
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 6).fill(.red))
        .accessibilityLabel(date.accessibleLabel)
        .help(date.accessibleLabel)
    }
}
