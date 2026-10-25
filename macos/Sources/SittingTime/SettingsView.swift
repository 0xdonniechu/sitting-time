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
        Form {
            Section("Nhắc nhở đứng dậy") {
                Stepper(
                    store.settings.sitReminderMinutes == 0
                        ? "Tắt nhắc nhở"
                        : "Mỗi \(store.settings.sitReminderMinutes) phút ngồi liên tục",
                    value: $store.settings.sitReminderMinutes, in: 0...240, step: 5
                )
                Toggle("Âm thanh nhắc nhở", isOn: $store.settings.reminderSound)
                HStack {
                    Text("Quyền gửi nhắc nhở")
                    Spacer()
                    Text(notificationsOn == true ? "Đã bật" : "Chưa bật")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button("Xin quyền") {
                        Task { notificationsOn = await store.requestNotificationAccess() }
                    }
                    Button("Mở Cài đặt hệ thống") { openNotificationSettings() }
                }
            }

            Section("Tự động") {
                Stepper(
                    "Tự tạm nghỉ sau \(store.settings.idlePauseMinutes) phút không dùng máy",
                    value: $store.settings.idlePauseMinutes, in: 1...60
                )
                Toggle("Tự tiếp tục khi quay lại", isOn: $store.settings.autoResumeOnReturn)
                Toggle("Mở app ở trạng thái Tạm nghỉ", isOn: $store.settings.startPaused)
            }

            Section("Mục tiêu") {
                Stepper(
                    store.settings.standGoalMinutes == 0
                        ? "Không đặt mục tiêu đứng"
                        : "Đứng \(formatDuration(TimeInterval(store.settings.standGoalMinutes * 60))) mỗi ngày",
                    value: $store.settings.standGoalMinutes, in: 0...600, step: 15
                )
            }

            Section("Hệ thống") {
                Toggle("Mở cùng máy", isOn: Binding(
                    get: { store.settings.launchAtLogin },
                    set: { setLaunchAtLogin($0) }
                ))
                if let loginError {
                    Text(loginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Dữ liệu") {
                Button("Mở thư mục dữ liệu") { revealDataFolder() }
                Button("Xóa dữ liệu hôm nay") { confirmResetToday = true }
                Button("Xóa toàn bộ lịch sử", role: .destructive) { confirmClearAll = true }
            }

            Section {
                Text("SittingTime \(AppInfo.version) • Dữ liệu chỉ nằm trên máy này, không mạng, không tài khoản.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .confirmationDialog(
            "Xóa dữ liệu hôm nay?", isPresented: $confirmResetToday, titleVisibility: .visible
        ) {
            Button("Xóa", role: .destructive) { store.resetToday() }
            Button("Giữ lại", role: .cancel) {}
        }
        .confirmationDialog(
            "Xóa toàn bộ lịch sử?", isPresented: $confirmClearAll, titleVisibility: .visible
        ) {
            Button("Xóa hết", role: .destructive) { store.clearHistory() }
            Button("Giữ lại", role: .cancel) {}
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
            loginError = "Không đặt được — mục này chỉ dùng khi chạy từ file .app: \(error.localizedDescription)"
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
