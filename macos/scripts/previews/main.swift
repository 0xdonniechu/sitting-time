import AppKit
import SwiftUI
import SittingCore

// Renders Stats / About / Flash screens to PNGs for human review.
// Usage: sitting-previews [all|stats-day|stats-week|about|flash] [outdir]
// ImageRenderer covers Stats + About anywhere; Flash needs a real window
// server (borderless capture) and is skipped under sandbox.

final class Box: @unchecked Sendable {
    var now: Date
    init(_ now: Date) { self.now = now }
}

@MainActor
func log(_ s: String) { print(s); fflush(stdout) }

@MainActor
func makeStore(at date: Date, box: Box) -> SittingStore {
    box.now = date
    return SittingStore(
        now: { box.now },
        idleSeconds: { 0 },
        reminders: ReminderCenter(requestAccess: { true }, post: { _, _, _ in }, isAuthorized: { true }),
        inMemory: true
    )
}

@MainActor
func run(store: SittingStore, box: Box, seconds: Int) {
    var left = seconds
    while left > 0 {
        let dt = min(60, left)
        box.now = box.now.addingTimeInterval(TimeInterval(dt))
        store.tick()
        left -= dt
    }
}

@MainActor
func fakeDay(store: SittingStore, box: Box, sit1: Int, stand: Int, pause: Int, sit2: Int) {
    if store.paused { store.togglePause() }
    store.setPosture(.sitting)
    run(store: store, box: box, seconds: sit1)
    store.setPosture(.standing)
    run(store: store, box: box, seconds: stand)
    store.togglePause()
    run(store: store, box: box, seconds: pause)
    store.togglePause()
    store.setPosture(.sitting)
    run(store: store, box: box, seconds: sit2)
    store.togglePause()
}

@MainActor
func fakeWeek() -> SittingStore {
    let today9 = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
    let box = Box(Calendar.current.date(byAdding: .day, value: -6, to: today9)!)
    let store = makeStore(at: box.now, box: box)
    let shapes = [(5400, 1800, 900, 3600), (3600, 3600, 600, 1800), (7200, 900, 1200, 2700),
                  (1800, 1800, 1800, 1800), (6300, 2700, 300, 900), (4500, 1500, 2400, 3200)]
    for offset in 0..<6 {
        let s = shapes[offset]
        fakeDay(store: store, box: box, sit1: s.0, stand: s.1, pause: s.2, sit2: s.3)
        box.now = Calendar.current.date(byAdding: .day, value: offset - 5, to: today9)!
        store.tick() // overnight gap: discarded like production
    }
    fakeDay(store: store, box: box, sit1: 5000, stand: 2200, pause: 1100, sit2: 3400)
    return store
}

@MainActor
func writePNG(_ image: NSImage, to path: String, label: String) {
    if let tiff = image.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let data = rep.representation(using: .png, properties: [:]) {
        try? data.write(to: URL(fileURLWithPath: path))
        log("wrote \(label) (\(data.count) bytes)")
    } else {
        log("RENDER FAILED \(label)")
    }
}

@MainActor
func render<V: View>(_ view: V, label: String, dir: String, width: CGFloat = 560) {
    let renderer = ImageRenderer(
        content: view.frame(width: width).background(.white).preferredColorScheme(.light)
    )
    renderer.scale = 1.0
    if let img = renderer.nsImage {
        writePNG(img, to: "\(dir)/\(label).png", label: label)
    } else {
        log("RENDER FAILED \(label)")
    }
}

@MainActor
func renderFlash(dark: Bool, dir: String) {
    // Borderless-window capture (keeps SwiftUI text, unlike titled
    // windows). Needs a window server; skipped under sandbox.
    guard let screen = NSScreen.main else {
        log("flash skipped: no window server (run unsandboxed)")
        return
    }
    NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    let window = FlashWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
    window.level = .screenSaver
    window.isOpaque = true
    window.backgroundColor = dark
        ? NSColor(red: 0x0C / 255, green: 0x0C / 255, blue: 0x0D / 255, alpha: 1)
        : .white
    window.hasShadow = false
    window.contentViewController = NSHostingController(
        rootView: FlashView(
            title: "It\u{2019}s time to stand up",
            message: "Move around for a few minutes",
            quote: healthQuotes[2],
            language: .english,
            size: screen.frame.size
        )
    )
    window.alphaValue = 0
    window.makeKeyAndOrderFront(nil)
    NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.24
        window.animator().alphaValue = 1
    }
    RunLoop.main.run(until: Date().addingTimeInterval(0.9))
    let label = dark ? "flash-dark" : "flash-light"
    if let view = window.contentView,
       let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
        view.cacheDisplay(in: view.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: "\(dir)/\(label).png"))
            log("wrote \(label) (\(data.count) bytes)")
        }
    }
    window.orderOut(nil)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
Task { @MainActor in
    let args = CommandLine.arguments
    let which = args.count > 1 ? args[1] : "all"
    let dir = args.count > 2 ? args[2] : "/tmp/sitting-previews"
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    let store = fakeWeek()
    log("today tracked: \(store.liveToday().trackedSeconds)s")
    if which == "all" || which == "stats-day" {
        render(StatsContentView(store: store, scope: .constant(.day), onReturnToDash: nil), label: "stats-day", dir: dir)
    }
    if which == "all" || which == "stats-week" {
        render(StatsContentView(store: store, scope: .constant(.week), onReturnToDash: nil), label: "stats-week", dir: dir)
    }
    if which == "all" || which == "about" {
        render(AboutView().environment(store), label: "about", dir: dir, width: 380)
    }
    if which == "all" || which == "flash" {
        renderFlash(dark: false, dir: dir)
        renderFlash(dark: true, dir: dir)
    }
    NSApp.terminate(nil)
}
app.run()
