import AppKit
import SwiftUI
import SittingCore

/// The popover: live countdown, session progress, posture switcher, today's
/// totals, footer actions. Hosted in an NSPopover (see AppDelegate), so the
/// stats and settings windows open through closures: `openWindow` needs a
/// SwiftUI scene environment, and the Settings scene action never fires from here.
struct MenuBarView: View {
    // Observed through .environment(store); the body also reads tickCount
    // so the view re-renders every second (see SittingStore.tickCount).
    @Environment(SittingStore.self) private var store
    let openStats: () -> Void
    let openSettings: () -> Void

    var body: some View {
        let _ = store.tickCount
        let lang = store.settings.language
        let strings = Strings(lang)
        let today = store.liveToday()
        let now = Date()
        let tile = subCalendarDate(for: now, calendar: store.settings.subCalendar, language: lang)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.statusTitle)
                        .font(.headline)
                    Text(formatElapsed(store.sessionRemaining))
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                }
                Spacer()
                if let tile {
                    let labels = solarLabels(for: now)
                    CalendarTile(
                        solarDay: labels.day, solarMonth: labels.month,
                        week: labels.week, secondary: tile
                    )
                }
            }

            ProgressView(value: store.sessionProgress)

            if store.autoPaused {
                Text(strings.autoPausedNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker(strings.statusPickerLabel, selection: Binding(
                get: { store.posture },
                set: { store.setPosture($0) }
            )) {
                ForEach(Posture.allCases, id: \.self) { posture in
                    Text(posture.attribution.shortTitle(in: lang)).tag(posture)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            // Equal widths so the pair sits symmetric about the row center.
            HStack(spacing: 8) {
                Spacer()
                Button(store.paused ? strings.resumeButton : strings.pauseButton) {
                    store.togglePause()
                }
                .buttonStyle(.borderedProminent)
                .frame(width: 110)
                Button(strings.skipButton) {
                    store.skipSession()
                }
                .buttonStyle(.bordered)
                .frame(width: 110)
                Spacer()
            }

            Picker(strings.modeLabel, selection: Binding(
                get: { store.settings.sessionMode },
                set: { store.setMode($0) }
            )) {
                ForEach(SessionMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Divider()

            Text(strings.todaySection)
                .font(.subheadline).bold()
            HStack {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                    GridRow {
                        Label {
                            Text(strings.phaseShort(.sitting))
                        } icon: {
                            DeskIcon(deskRaised: false, size: 15)
                        }
                        Text(formatDuration(today.sittingSeconds, language: lang)).monospacedDigit()
                    }
                    GridRow {
                        Label {
                            Text(strings.phaseShort(.standing))
                        } icon: {
                            DeskIcon(deskRaised: true, size: 15)
                        }
                        Text(formatDuration(today.standingSeconds, language: lang)).monospacedDigit()
                    }
                    GridRow {
                        Label(strings.phaseShort(.paused), systemImage: SitPhase.paused.symbol)
                        Text(formatDuration(today.pausedSeconds, language: lang)).monospacedDigit()
                    }
                }
                .font(.callout)
                Spacer()
                StatusIcon()
                    .foregroundStyle(.secondary)
            }

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

            // Icon footer: text links ran together into one blue blob.
            // Tooltips keep the localized labels discoverable on hover.
            HStack(spacing: 16) {
                Button(action: openStats) {
                    Image(systemName: "chart.bar")
                }
                .help(strings.statsButton)
                Button(action: openSettings) {
                    Image(systemName: "gearshape")
                }
                .help(strings.settingsButton)
                Spacer(minLength: 0)
                Link(destination: AppInfo.donateURL) {
                    HStack(spacing: 3) {
                        Text("Buy me a")
                        Image(systemName: "cup.and.saucer")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.accentColor))
                    .fixedSize(horizontal: true, vertical: false)
                }
                .help("Buy me a coffee")
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Image(systemName: "power")
                }
                .help(strings.quitButton)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .font(.system(size: 14))
        }
        .padding(14)
        .frame(width: 300)
    }
}

/// The big status glyph beside today's totals: the desk icon while working
/// (laptop rises when standing), the plain session symbol otherwise. Every
/// branch shares one fixed frame, so session and posture switches never move
/// the popover.
private struct StatusIcon: View {
    @Environment(SittingStore.self) private var store

    var body: some View {
        Group {
            if !store.paused, store.session.isWork {
                DeskIcon(deskRaised: store.posture == .standing, size: 28)
            } else {
                Image(systemName: store.statusSymbol)
                    .font(.system(size: 28))
                    .frame(width: 28 * deskPictogramAspect, height: 28)
            }
        }
    }
}

/// Calendar tile pinned to the top-right: week + branch + zodiac animal
/// on one tracked-out caps line, then two compact columns — solar day over
/// month, lunar day over month. The branch wears its element color (red
/// Ngọ + horse for Bính Ngọ). One quiet card — hairline border, soft
/// shadow. Adaptive to light and dark; hovering shows the full date.
struct CalendarTile: View {
    let solarDay: String
    let solarMonth: String
    let week: String
    let secondary: SubCalendarDate

    @Environment(\.colorScheme) private var scheme

    private var dayColor: Color {
        scheme == .dark
            ? Color(red: 0.45, green: 0.82, blue: 0.77)
            : Color(red: 0.04, green: 0.42, blue: 0.39)
    }

    /// Five-element ink for the Can Chi year; numbered years stay secondary.
    private func yearColor(_ element: YearElement?) -> Color {
        let dark = scheme == .dark
        switch element {
        case nil:
            return .secondary
        case .wood:
            return dark ? Color(red: 0.42, green: 0.77, blue: 0.45) : Color(red: 0.18, green: 0.49, blue: 0.20)
        case .fire:
            return dark ? Color(red: 0.95, green: 0.45, blue: 0.38) : Color(red: 0.72, green: 0.14, blue: 0.12)
        case .earth:
            return dark ? Color(red: 0.82, green: 0.68, blue: 0.25) : Color(red: 0.52, green: 0.40, blue: 0.05)
        case .metal:
            return dark ? Color(red: 0.75, green: 0.75, blue: 0.78) : Color(red: 0.42, green: 0.42, blue: 0.44)
        case .water:
            return dark ? Color(red: 0.40, green: 0.65, blue: 0.95) : Color(red: 0.08, green: 0.36, blue: 0.72)
        }
    }

    private var eyebrow: some View {
        HStack(spacing: 3) {
            Text(week)
                .tracking(0.4)
                .foregroundStyle(.secondary)
            if let icon = ZodiacArt.image(for: secondary.yearAnimal) {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 11, height: 11)
                    .foregroundStyle(yearColor(secondary.yearElement))
            } else {
                Text("·")
                    .foregroundStyle(.secondary)
            }
            Text(secondary.yearLabel)
                .tracking(0.4)
                .foregroundStyle(yearColor(secondary.yearElement))
        }
        .font(.system(size: 8.5, weight: .semibold))
    }

    var body: some View {
        VStack(spacing: 2) {
            eyebrow
            // Columns hug content and sit adjacent; the group centers in
            // the tile (never stretched apart to the edges).
            HStack(alignment: .center, spacing: 4) {
                VStack(spacing: 2) {
                    Text(solarDay)
                        .font(.system(size: 24, weight: .semibold))
                        .monospacedDigit()
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor))
                        .frame(width: 20, height: 1)
                    Text(solarMonth)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 28)
                // Fixed separator, never a bare Divider: Divider greedily
                // eats offered height and inflates the tile inside the
                // popover (seen stretched ~2.5x in production).
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(width: 1, height: 44)
                VStack(spacing: 2) {
                    Text(secondary.day)
                        .font(.system(size: 24, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(dayColor)
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor))
                        .frame(width: 20, height: 1)
                    Text(secondary.sub)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 28)
            }
        }
        // Hug content vertically no matter what the popover offers.
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        .accessibilityLabel(secondary.accessibleLabel)
        .help(secondary.accessibleLabel)
    }
}
