import AppKit
import SwiftUI
import SittingCore

struct SettingsView: View {
    // From .environment(store): see MenuBarView. The local @Bindable keeps
    // the $store.settings projections working.
    @Environment(SittingStore.self) private var store
    @State private var loginError: String?
    @State private var notificationsOn: Bool?
    @State private var confirmResetToday = false
    @State private var confirmClearAll = false
    @State private var packDownloading = false
    @State private var packError: String?

    /// Closes the window and reopens the popover dash. Nil hides the button
    /// (the standalone Settings scene has nowhere to return to).
    var onReturnToDash: (() -> Void)?

    var body: some View {
        @Bindable var store = store
        let lang = store.settings.language
        // Checkmarks follow the effective language: a legacy `.vietnamese`
        // setting without the pack shows English as active, not both.
        let effectiveLang = LanguagePacks.resolve(lang)
        let strings = Strings(lang)
        Form {
            if let onReturnToDash {
                Button(action: onReturnToDash) {
                    Label(strings.backButton, systemImage: "chevron.left")
                }
                .buttonStyle(.link)
            }
            Section(strings.sessionSection) {
                Picker(strings.modeLabel, selection: Binding(
                    get: { store.settings.sessionMode },
                    set: { store.setMode($0) }
                )) {
                    ForEach(SessionMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                if store.settings.sessionMode == .standUp {
                    Stepper(
                        strings.workMinutes(store.settings.standUpWorkMinutes),
                        value: $store.settings.standUpWorkMinutes, in: 1...240, step: 5
                    )
                    Stepper(
                        strings.moveMinutes(store.settings.standUpBreakMinutes),
                        value: $store.settings.standUpBreakMinutes, in: 1...60
                    )
                } else {
                    Stepper(
                        strings.workMinutes(store.settings.pomodoroWorkMinutes),
                        value: $store.settings.pomodoroWorkMinutes, in: 1...240, step: 5
                    )
                    Stepper(
                        strings.shortMinutes(store.settings.pomodoroShortMinutes),
                        value: $store.settings.pomodoroShortMinutes, in: 1...60
                    )
                    Stepper(
                        strings.longMinutes(store.settings.pomodoroLongMinutes),
                        value: $store.settings.pomodoroLongMinutes, in: 1...60
                    )
                }
            }

            Section(strings.notifySection) {
                Toggle(strings.soundToggle, isOn: $store.settings.reminderSound)
                Toggle(strings.flashToggle, isOn: $store.settings.fullScreenFlash)
                Toggle(strings.quoteToggle, isOn: $store.settings.quoteOnFlash)
                HStack {
                    Text(strings.permissionRow)
                    Spacer()
                    Text(notificationsOn == true ? strings.permissionOn : strings.permissionOff)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button(strings.requestButton) {
                        Task { notificationsOn = await store.requestNotificationAccess() }
                    }
                    Button(strings.openSystemButton) { openNotificationSettings() }
                }
            }

            Section(strings.autoSection) {
                Stepper(
                    strings.idleTitle(minutes: store.settings.idlePauseMinutes),
                    value: $store.settings.idlePauseMinutes, in: 1...60
                )
                Toggle(strings.resumeToggle, isOn: $store.settings.autoResumeOnReturn)
                Toggle(strings.startPausedToggle, isOn: $store.settings.startPaused)
            }

            Section(strings.goalSection) {
                Stepper(
                    store.settings.standGoalMinutes == 0
                        ? strings.goalOff
                        : strings.goalOn(formatDuration(TimeInterval(store.settings.standGoalMinutes * 60), language: lang)),
                    value: $store.settings.standGoalMinutes, in: 0...600, step: 15
                )
            }

            Section(strings.displaySection) {
                Picker(strings.languageLabel, selection: Binding(
                    get: { effectiveLang },
                    set: { selectLanguage($0) }
                )) {
                    Text(AppLanguage.english.displayName).tag(AppLanguage.english)
                    Text(AppLanguage.vietnamese.displayName).tag(AppLanguage.vietnamese)
                }
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AppLanguage.vietnamese.displayName)
                        Text(packNote(strings: strings))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    packTrailing(strings: strings)
                }
                .disabled(packDownloading)
                if let packError {
                    Text(packError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Picker(strings.calendarLabel, selection: $store.settings.subCalendar) {
                    ForEach(SubCalendar.allCases, id: \.self) { option in
                        Text(strings.calendarName(option)).tag(option)
                    }
                }
                Toggle(strings.pinPopoverToggle, isOn: $store.settings.pinPopover)
            }

            Section(strings.systemSection) {
                Toggle(strings.loginToggle, isOn: Binding(
                    get: { store.settings.launchAtLogin },
                    set: { setLaunchAtLogin($0) }
                ))
                if let loginError {
                    Text(loginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section(strings.dataSection) {
                Button(strings.revealButton) { revealDataFolder() }
                Button(strings.resetTodayButton) { confirmResetToday = true }
                Button(strings.clearAllButton, role: .destructive) { confirmClearAll = true }
            }

            Section(strings.supportSection) {
                Link(destination: AppInfo.donateURL) {
                    Label("Buy me a coffee", systemImage: "cup.and.saucer")
                }
            }

            Section {
                Text(strings.footerNote(version: AppInfo.version))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        // Minimum height feeds the intrinsic size: without it the hosting
        // controller can report zero height and collapse the panel to a bare
        // title bar (seen in production screenshots).
        .frame(minWidth: 440, minHeight: 620)
        .confirmationDialog(
            strings.resetTodayDialog, isPresented: $confirmResetToday, titleVisibility: .visible
        ) {
            Button(strings.deleteButton, role: .destructive) { store.resetToday() }
            Button(strings.keepButton, role: .cancel) {}
        }
        .confirmationDialog(
            strings.clearAllDialog, isPresented: $confirmClearAll, titleVisibility: .visible
        ) {
            Button(strings.deleteAllButton, role: .destructive) { store.clearHistory() }
            Button(strings.keepButton, role: .cancel) {}
        }
        .task {
            notificationsOn = await store.notificationAuthorized()
            store.settings.launchAtLogin = LoginItemManager.isEnabled
            store.refreshLanguagePackStatus()
        }
    }

    /// Dropdown selection: English switches at once; Vietnamese switches
    /// when installed, otherwise downloads first (and switches on success).
    private func selectLanguage(_ language: AppLanguage) {
        if language == .english {
            store.settings.language = .english
        } else if store.vietnamesePackInstalled {
            store.settings.language = .vietnamese
        } else {
            downloadPack()
        }
    }

    private func packNote(strings: Strings) -> String {
        if packDownloading { return strings.langDownloading }
        if store.vietnamesePackInstalled {
            return strings.langDownloaded(ByteCountFormatter.string(
                fromByteCount: Int64(store.vietnamesePackBytes), countStyle: .file
            ))
        }
        return strings.langNotDownloaded
    }

    private func packTrailing(strings: Strings) -> some View {
        Group {
            if packDownloading {
                ProgressView()
                    .controlSize(.small)
            } else if store.vietnamesePackInstalled {
                Button(strings.deleteButton) { store.deleteVietnamesePack() }
            } else {
                Button(strings.langDownload) { downloadPack() }
            }
        }
    }

    private func downloadPack() {
        guard !packDownloading else { return }
        packDownloading = true
        packError = nil
        Task {
            packError = await store.downloadVietnamesePack()
            packDownloading = false
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        loginError = nil
        do {
            try LoginItemManager.setEnabled(enabled)
            store.settings.launchAtLogin = enabled
        } catch {
            loginError = Strings(store.settings.language).loginError(error.localizedDescription)
            store.settings.launchAtLogin = LoginItemManager.isEnabled
        }
    }

    private func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }

    private func revealDataFolder() {
        if let folder = Persistence.folderURL() {
            NSWorkspace.shared.open(folder)
        }
    }
}
