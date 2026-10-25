import AppKit
import SwiftUI
import SittingCore

/// Borderless fullscreen window that can take key focus and dismisses on any
/// click or key, without activating the app (so it never steals focus).
final class FlashWindow: NSWindow {
    var onDismiss: (() -> Void)?

    override var canBecomeKey: Bool { true }

    /// Intercepts clicks and keys before the activation machinery: the first
    /// click dismisses even though the app stays inactive.
    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown, .rightMouseDown, .keyDown:
            onDismiss?()
        default:
            super.sendEvent(event)
        }
    }
}

/// The full-screen sit reminder: dimmed screen, centered message, a random
/// health quote, auto-dismiss (6 s, or 20 s with a quote like the Tauri app).
@MainActor
final class FlashCenter {
    private var window: FlashWindow?
    private var dismissWork: DispatchWorkItem?

    func show(title: String, message: String, quote: HealthQuote?, language: AppLanguage, sound: Bool) {
        dismiss()
        guard let screen = NSScreen.main else { return }
        let window = FlashWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        // Solid black: a translucent background does not composite on this
        // window (verified: alpha is ignored, opaque paints), and the flash
        // reads better as a full blackout anyway.
        window.isOpaque = true
        window.backgroundColor = .black
        window.hasShadow = false
        window.contentViewController = NSHostingController(
            rootView: FlashView(
                title: title, message: message, quote: quote,
                language: language, size: screen.frame.size
            )
        )
        window.onDismiss = { [weak self] in self?.dismiss() }
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            window.animator().alphaValue = 1
        }
        self.window = window
        let work = DispatchWorkItem { [weak self] in self?.dismiss() }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (quote == nil ? 6 : 20), execute: work)
        if sound {
            NSSound(named: "Glass")?.play()
        }
    }

    func dismiss() {
        dismissWork?.cancel()
        dismissWork = nil
        window?.orderOut(nil)
        window = nil
    }
}

/// Centered card on the dimmed screen. Dismissal is handled by `FlashWindow`,
/// so this view holds no gestures or timers.
struct FlashView: View {
    let title: String
    let message: String
    let quote: HealthQuote?
    let language: AppLanguage
    /// Screen size: without an explicit frame the window shrinks to fit the
    /// card (NSHostingController adopts the content's ideal size).
    let size: CGSize

    var body: some View {
        // The dim comes from the window background (always paints); SwiftUI
        // only centers the card.
        ZStack {
            flashCard
        }
        .frame(width: size.width, height: size.height)
    }

    private var flashCard: some View {
        VStack(spacing: 16) {
            Text(title)
                    .font(.largeTitle).bold()
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if let quote {
                    Divider()
                        .frame(width: 200)
                    Text("\(quote.emoji) \(quote.text(in: language))")
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 640)
                }
                Text(Strings(language).dismissHint)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 24)
            }
            .foregroundStyle(.white)
            .padding(48)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding()
    }
}
