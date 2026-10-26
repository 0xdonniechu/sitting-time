import SwiftUI
import SittingCore

/// About panel: app version, author, manual update check, bug reports.
struct AboutView: View {
    // From .environment(store): see MenuBarView.
    @Environment(SittingStore.self) private var store
    @State private var checking = false
    @State private var status: UpdateChecker.Status?

    /// Closes the window and reopens the popover dash. Nil hides the button.
    var onReturnToDash: (() -> Void)?

    var body: some View {
        let lang = store.settings.language
        let strings = Strings(lang)
        VStack(alignment: .leading, spacing: 12) {
            if let onReturnToDash {
                Button(action: onReturnToDash) {
                    Label(strings.backButton, systemImage: "chevron.left")
                }
                .buttonStyle(.link)
            }
            Text("SittingTime")
                .font(.title2).bold()
            Text(AppInfo.version)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Text(strings.aboutMadeBy)
                    .foregroundStyle(.secondary)
                Link(AppInfo.authorName, destination: AppInfo.authorURL)
            }
            Text("\(strings.starNote) [\(strings.starRepo)](\(AppInfo.repoURL)) \(strings.starThanks)")
                .foregroundStyle(.secondary)
            Divider()
            HStack {
                Button(checking ? strings.checkUpdatesChecking : strings.checkUpdatesButton) {
                    checking = true
                    status = nil
                    Task {
                        let result = await UpdateChecker.check(currentVersion: AppInfo.shortVersion)
                        checking = false
                        status = result
                    }
                }
                .disabled(checking)
                Spacer()
                statusText(strings: strings)
            }
            Link(destination: AppInfo.reportBugURL) {
                Label(strings.reportBugButton, systemImage: "ant")
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    @ViewBuilder
    private func statusText(strings: Strings) -> some View {
        switch status {
        case .none:
            EmptyView()
        case .current:
            Text(strings.checkUpdatesCurrent)
                .foregroundStyle(.secondary)
        case .available(let version):
            HStack(spacing: 8) {
                Text(strings.checkUpdatesAvailable(version))
                Link(strings.viewReleaseButton, destination: UpdateChecker.releasePageURL(version: version))
            }
        case .failed:
            Text(strings.checkUpdatesFailed)
                .foregroundStyle(.secondary)
        }
    }
}
