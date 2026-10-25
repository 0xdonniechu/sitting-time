import AppKit
import Darwin
import SwiftUI
import SittingCore

@main
@MainActor
struct SittingTimeApp: App {
    // The delegate owns the one store; views observe it through
    // .environment(store). No @State here: reading it before installation
    // logs a runtime warning, and nothing needs scene-level invalidation.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The menu bar item and popover are manual AppKit (see AppDelegate):
        // MenuBarExtra's label renders once and never updates, and driving it
        // with TimelineView livelocks the main thread (verified by bisect:
        // TimelineView builds never tick, non-TimelineView builds do).
        // The Settings scene stays for the Scene body (and Cmd-,); the
        // popover button opens a manual panel instead (see showSettings).
        Settings {
            SettingsView()
                .environment(appDelegate.store)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// The one store, shared with the views through .environment(store).
    var store: SittingStore = SittingStore.live()
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var statsPanel: NSPanel?
    private var settingsPanel: NSPanel?
    private let flashCenter = FlashCenter()
    private var lockFD: Int32 = -1
    private var isDuplicate = false
    /// Held for the app's lifetime: the 1 s timer is user-initiated work,
    /// exempt from App Nap throttling (which otherwise slows ticks ~30 %+).
    private var napActivity: NSObjectProtocol?

    nonisolated func applicationWillFinishLaunching(_ notification: Notification) {
        // Documented main-thread callback.
        MainActor.assumeIsolated {
            // Single instance: a second copy would double-count time and fight
            // over records.json, so it exits during launch instead.
            if let folder = Persistence.folderURL() {
                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let path = folder.appendingPathComponent(".lock").path
                let fd = open(path, O_CREAT | O_RDWR, 0o644)
                if fd >= 0, flock(fd, LOCK_EX | LOCK_NB) == 0 {
                    lockFD = fd
                } else {
                    if fd >= 0 { close(fd) }
                    isDuplicate = true
                }
            }
        }
    }

    nonisolated func applicationDidFinishLaunching(_ notification: Notification) {
        // Documented main-thread callback; the whole setup is main-thread UI.
        MainActor.assumeIsolated {
            if isDuplicate {
                NSApp.terminate(nil)
                return
            }
            let store = self.store
            napActivity = ProcessInfo.processInfo.beginActivity(
                options: [.userInitiated], reason: "1 s sitting timer"
            )
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.button?.action = #selector(togglePopover(_:))
            item.button?.target = self
            // Monospaced digits: with proportional figures the variable-length
            // item resizes every second, jittering the menu bar clock.
            if let size = item.button?.font?.pointSize {
                item.button?.font = NSFont.monospacedDigitSystemFont(ofSize: size, weight: .regular)
            }
            statusItem = item
            let popover = NSPopover()
            popover.contentViewController = NSHostingController(
                rootView: MenuBarView(
                    openStats: { [weak self] in self?.showStats() },
                    openSettings: { [weak self] in self?.showSettings() }
                )
                .environment(store)
            )
            popover.behavior = .transient
            popover.animates = true
            self.popover = popover
            // The tick hook refreshes the AppKit label out-of-band; the hosted
            // SwiftUI views observe the store through .environment instead.
            store.onTick = { [weak self] in self?.refreshStatusItem() }
            // The flash hook fires on the main actor from tick(), like onTick.
            store.onFlash = { [weak self] title, body, quote in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.flashCenter.show(
                        title: title,
                        message: body,
                        quote: quote,
                        language: self.store.settings.language,
                        sound: self.store.settings.reminderSound
                    )
                }
            }
            refreshStatusItem()
            Task { @MainActor in
                _ = await store.requestNotificationAccess()
            }
            // Suppress SwiftUI's launch-time Settings window: with Settings as the
            // only scene, activating the app shows it uninvited. At this point
            // none of our windows exist yet, so anything here is SwiftUI's.
            for window in NSApp.windows { window.orderOut(nil) }
        }
    }

    nonisolated func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Menu bar app: re-activating (Finder double-click, second `open`)
        // must not pop any window; the icon click is the UI path.
        return true
    }

    nonisolated func applicationWillTerminate(_ notification: Notification) {
        // Documented main-thread callback; the synchronous flush must not hop.
        // A duplicate never saves: its stale snapshot would clobber the
        // primary's records.
        MainActor.assumeIsolated {
            if !isDuplicate {
                store.save()
            }
        }
    }

    @objc nonisolated private func togglePopover(_ sender: Any?) {
        MainActor.assumeIsolated {
            guard let popover else { return }
            if popover.isShown {
                popover.close()
            } else {
                showPopover()
            }
        }
    }

    @MainActor
    private func showPopover() {
        guard let button = statusItem?.button, let popover else { return }
        if let hostingView = popover.contentViewController?.view as? NSHostingView<MenuBarView> {
            let fit = hostingView.fittingSize
            popover.contentSize = NSSize(
                width: min(max(fit.width, 300), 380),
                height: min(max(fit.height, 300), 640)
            )
        } else {
            popover.contentSize = NSSize(width: 328, height: 520)
        }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func showStats() {
        if statsPanel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 640),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered, defer: false
            )
            panel.level = .floating
            panel.hidesOnDeactivate = false
            panel.contentViewController = NSHostingController(rootView: StatsView().environment(store))
            panel.isReleasedWhenClosed = false
            panel.center()
            statsPanel = panel
        }
        statsPanel?.title = Strings(store.settings.language).statsPanelTitle
        statsPanel?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func showSettings() {
        // Manual panel like showStats: the Settings scene's
        // showSettingsWindow: never fires from the popover while the app is
        // inactive, so the button goes through this closure instead.
        if settingsPanel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 640),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered, defer: false
            )
            panel.level = .floating
            panel.hidesOnDeactivate = false
            panel.contentViewController = NSHostingController(rootView: SettingsView().environment(store))
            panel.isReleasedWhenClosed = false
            panel.center()
            settingsPanel = panel
        }
        settingsPanel?.title = Strings(store.settings.language).settingsPanelTitle
        settingsPanel?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func refreshStatusItem() {
        guard let button = statusItem?.button else { return }
        button.title = store.menuCountdown
        let image = NSImage(systemSymbolName: store.statusSymbol, accessibilityDescription: store.statusTitle)
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageLeading
    }
}
