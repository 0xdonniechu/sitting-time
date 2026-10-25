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

    var body: some View {
        @Bindable var store = store
        let lang = store.settings.language
        let strings = Strings(lang)
        Form {
            Section(strings.reminderSection) {
                Stepper(
                    store.settings.sitReminderMinutes == 0
                        ? strings.reminderOff
                        : strings.reminderEvery(minutes: store.settings.sitReminderMinutes),
                    value: $store.settings.sitReminderMinutes, in: 0...240, step: 5
                )
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
                Picker(strings.languageLabel, selection: $store.settings.language) {
                    ForEach(AppLanguage.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                Picker(strings.calendarLabel, selection: $store.settings.subCalendar) {
                    ForEach(SubCalendar.allCases, id: \.self) { option in
                        Text(strings.calendarName(option)).tag(option)
                    }
                }
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

            Section {
                Text(strings.footerNote(version: AppInfo.version))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
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
