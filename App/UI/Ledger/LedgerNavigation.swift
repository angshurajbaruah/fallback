import AppKit
import SwiftUI

/// Text that reads as clickable: Frosted Blue, underlined and a pointing-hand cursor on hover.
struct HoverLink: View {
    var text: String
    var font: Font
    var colour: Color = Theme.text
    var help: String
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(font)
                .foregroundStyle(hovering ? Theme.primary : colour)
                .underline(hovering)
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { inside in
            hovering = inside
            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

/// "‹ Resume": back to where a jump came from. Shown only when there's somewhere to go back to.
struct BackLink: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let previous = model.backStack.last {
            HoverLink(text: "‹ \(model.title(of: previous))", font: Theme.caption, colour: Theme.textMuted,
                      help: "Back (⌘[)") { model.goBack() }
        }
    }
}

/// ⌘[ and the two-finger swipe back, for the whole Ledger window.
struct LedgerBackGestures: View {
    @Environment(AppModel.self) private var model
    @State private var window: NSWindow?
    @State private var monitor: Any?

    var body: some View {
        Button("Back") { model.goBack() }
            .keyboardShortcut("[", modifiers: .command)
            .disabled(!model.canGoBack)
            .opacity(0).frame(width: 0, height: 0).accessibilityHidden(true)
            .background(WindowReader(window: $window))
            .onAppear(perform: startSwipeTracking)
            .onDisappear { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil }
    }

    /// Follows the system setting "Swipe between pages" (scroll left or right with two fingers),
    /// the same way Safari and Finder do: a horizontal two-finger swipe to the right goes back.
    private func startSwipeTracking() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            MainActor.assumeIsolated {
                guard event.phase == .began, event.window === window, model.canGoBack,
                      NSEvent.isSwipeTrackingFromScrollEventsEnabled,
                      abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) else { return }
                var done = false
                // Only the "back" direction is allowed (0…1); a swipe the other way does nothing.
                event.trackSwipeEvent(options: [.lockDirection, .clampGestureAmount],
                                      dampenAmountThresholdMin: 0, max: 1) { amount, phase, isComplete, stop in
                    MainActor.assumeIsolated {
                        if phase == .ended, amount > 0.3, !done {
                            done = true
                            model.goBack()
                        }
                        if isComplete { stop.pointee = true }
                    }
                }
            }
            return event
        }
    }
}

/// Gives SwiftUI the NSWindow it lives in, so events from other windows (the popover) are ignored.
private struct WindowReader: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { window = view.window }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        if window !== view.window { DispatchQueue.main.async { window = view.window } }
    }
}
