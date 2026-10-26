import AppKit
import AVFoundation
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

/// Soft two-tone chime (E5 → A5 sine, fast attack, ~0.7 s decay) matching the
/// Tauri app's WebAudio chime. Replaces the harsh Glass system sound.
@MainActor
final class SoftChime {
    private var engine: AVAudioEngine?
    private var stopWork: DispatchWorkItem?

    func play() {
        stop()
        let engine = AVAudioEngine()
        let sampleRate = 44_100.0
        let frames = AVAudioFrameCount(sampleRate * 1.0)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)
        else { return }
        buffer.frameLength = frames
        let data = buffer.floatChannelData![0]
        let tones = [(freq: 659.25, start: 0.0), (freq: 880.0, start: 0.12)]
        for n in 0 ..< Int(frames) {
            let t = Double(n) / sampleRate
            var sample = 0.0
            for tone in tones {
                let dt = t - tone.start
                guard dt >= 0 else { continue }
                let attack = min(dt / 0.025, 1.0)
                // Matches the Tauri ramp (0.18 → 0.0001 over 0.72 s).
                let decay = exp(-dt / 0.096)
                sample += 0.18 * attack * decay * sin(2 * .pi * tone.freq * dt)
            }
            data[n] = Float(sample)
        }
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
        } catch {
            return
        }
        player.scheduleBuffer(buffer, at: nil)
        player.play()
        self.engine = engine
        let work = DispatchWorkItem { [weak self] in self?.stop() }
        stopWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }

    private func stop() {
        stopWork?.cancel()
        stopWork = nil
        engine?.stop()
        engine = nil
    }
}

/// The full-screen sit reminder. Same look as the Tauri app's overlay
/// (`src/overlay.css`): soft light backdrop with a green glow, gradient
/// headline, tinted fact card — a dark variant follows the system appearance.
/// Auto-dismiss (6 s, or 20 s with a quote like the Tauri app).
@MainActor
final class FlashCenter {
    private var window: FlashWindow?
    private var dismissWork: DispatchWorkItem?
    private let chime = SoftChime()

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
        // Solid colors: a translucent background does not composite on this
        // window (verified: alpha is ignored, opaque paints). The soft glow
        // is drawn in SwiftUI on top of this base.
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        window.isOpaque = true
        window.backgroundColor = dark
            ? NSColor(red: 0x0C / 255, green: 0x0C / 255, blue: 0x0D / 255, alpha: 1)
            : .white
        window.hasShadow = false
        window.contentViewController = NSHostingController(
            rootView: FlashView(
                title: title, message: message, quote: quote,
                language: language, size: screen.frame.size
            )
        )
        window.onDismiss = { [weak self] in self?.dismiss() }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            window.alphaValue = 1
            window.makeKeyAndOrderFront(nil)
        } else {
            window.alphaValue = 0
            window.makeKeyAndOrderFront(nil)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.24
                window.animator().alphaValue = 1
            }
        }
        self.window = window
        let work = DispatchWorkItem { [weak self] in self?.dismiss() }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (quote == nil ? 6 : 20), execute: work)
        if sound {
            chime.play()
        }
    }

    func dismiss() {
        dismissWork?.cancel()
        dismissWork = nil
        window?.orderOut(nil)
        window = nil
    }
}

private extension Color {
    init(rgb: Int, opacity: Double = 1) {
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Centered message on the soft backdrop, ported from the Tauri overlay:
/// brand eyebrow, gradient headline, gray subline, tinted fact card.
/// Dismissal is handled by `FlashWindow`, so this view holds no gestures.
struct FlashView: View {
    let title: String
    let message: String
    let quote: HealthQuote?
    let language: AppLanguage
    /// Screen size: without an explicit frame the window shrinks to fit the
    /// content (NSHostingController adopts the content's ideal size).
    let size: CGSize

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private var dark: Bool { colorScheme == .dark }
    /// Opaque base, same value as the window background: the view stays
    /// self-contained so previews and captures show the true colors.
    private var base: Color { dark ? Color(rgb: 0x0C0C0D) : .white }
    private var brand: Color { dark ? Color(rgb: 0x55D555) : Color(rgb: 0x208120) }
    private var titleGradient: [Color] {
        dark
            ? [Color(rgb: 0x55D555), Color(rgb: 0x2BC3D2), Color(rgb: 0x40BFFF)]
            : [Color(rgb: 0x208120), Color(rgb: 0x1B7A84), Color(rgb: 0x104E92)]
    }
    private var bodyGray: Color { dark ? Color(rgb: 0xAAAAAA) : Color(rgb: 0x555555) }
    private var hintGray: Color { dark ? Color(rgb: 0x777777) : Color(rgb: 0x8A8A8A) }
    private var factPrimary: Color { dark ? Color(rgb: 0xE2E2E4) : Color(rgb: 0x222222) }
    private var factSecondary: Color { dark ? Color(rgb: 0x9A9A9E) : Color(rgb: 0x6A6A6A) }

    /// `clamp(48px, 7vw, 112px)` from the overlay CSS.
    private var titleSize: CGFloat { min(max(size.width * 0.07, 48), 112) }
    /// `clamp(18px, 2vw, 28px)`.
    private var bodySize: CGFloat { min(max(size.width * 0.02, 18), 28) }

    var body: some View {
        ZStack {
            base
            // Soft green/cyan glow over the base.
            RadialGradient(
                colors: [
                    Color(rgb: 0x55D555, opacity: 0.16),
                    Color(rgb: 0x2BC3D2, opacity: 0.07),
                    .clear,
                ],
                center: UnitPoint(x: 0.5, y: 0.4),
                startRadius: 0,
                endRadius: max(size.width, size.height) * 0.55
            )
            VStack(spacing: 0) {
                Text("SITTINGTIME")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(13 * 0.18)
                    .foregroundStyle(brand)
                    .padding(.bottom, 28)
                Text(title)
                    .font(.system(size: titleSize, weight: .semibold))
                    .tracking(-titleSize * 0.055)
                    .foregroundStyle(LinearGradient(
                        colors: titleGradient, startPoint: .leading, endPoint: .trailing
                    ))
                    .multilineTextAlignment(.center)
                    .lineSpacing(-titleSize * 0.05)
                    .frame(maxWidth: 1000)
                Text(message)
                    .font(.system(size: bodySize))
                    .foregroundStyle(bodyGray)
                    .multilineTextAlignment(.center)
                    .padding(.top, 30)
                if let quote {
                    let primary = quote.text(in: language)
                    VStack(spacing: 8) {
                        Text(quote.emoji)
                            .font(.system(size: 40))
                        Text(primary)
                            .font(.system(size: 20))
                            .foregroundStyle(factPrimary)
                            .multilineTextAlignment(.center)
                        // The overlay always pairs the localized fact with
                        // its English original; skip it when identical.
                        if quote.en != primary {
                            Text(quote.en)
                                .font(.system(size: 16))
                                .foregroundStyle(factSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: 720)
                    .padding(.vertical, 22)
                    .padding(.horizontal, 32)
                    .background(
                        Color(rgb: 0x55D555, opacity: dark ? 0.10 : 0.09),
                        in: RoundedRectangle(cornerRadius: 18)
                    )
                    .padding(.top, 44)
                }
                Text(Strings(language).dismissHint)
                    .font(.system(size: 13))
                    .foregroundStyle(hintGray)
                    .padding(.top, 56)
            }
            .padding(48)
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.96)
        }
        .frame(width: size.width, height: size.height)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.easeOut(duration: 0.35)) { appeared = true }
            }
        }
    }
}
