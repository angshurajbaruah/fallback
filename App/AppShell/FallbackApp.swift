import SwiftUI
import FallbackCore

@main
struct FallbackApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        MenuBarExtra {
            PopoverView().environment(delegate.model)
        } label: {
            MenuBarLabel(model: delegate.model)
        }
        .menuBarExtraStyle(.window)

        Window("Fallback", id: "ledger") {
            LedgerView().environment(delegate.model)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 800)

        #if DEBUG
        // Development builds only: the M1 detection log (⌥⌘D in the popover).
        Window("Detection Log", id: "detection-log") {
            DetectionLogView(log: delegate.model.log)
        }
        #endif
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Theme.registerFonts()
        #if DEBUG
        if Snapshots.runIfRequested() || Scenarios.runIfRequested() { exit(0) }
        #endif
        // Adds Fallback to the Accessibility list and shows macOS's prompt if access isn't granted yet.
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        model.start()
    }
}

/// The menu-bar icon: dims to 45% when paused, and gets a Burnt Tangerine dot when
/// Accessibility is off (BRAND.md "Menu-bar icon", FR-31).
private struct MenuBarLabel: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // The dot also marks a warning card that hasn't been handled yet (screen 03).
        Image(nsImage: Self.image(paused: model.isPaused, problem: !model.isTrusted || model.activeCard != nil))
            .onAppear { model.openLedgerWindow = { openWindow(id: "ledger") } }
            .accessibilityLabel(model.isTrusted ? FallbackCore.appName : "\(FallbackCore.appName), needs Accessibility")
    }

    static func image(paused: Bool, problem: Bool) -> NSImage {
        guard let base = NSImage(named: "MenuBarIcon") else { return NSImage() }
        guard paused || problem else { return base }
        let size = base.size
        let image = NSImage(size: size, flipped: false) { rect in
            base.draw(in: rect, from: .zero, operation: .sourceOver, fraction: paused ? 0.45 : 1)
            if problem {
                // Not a template any more, so tint the glyph to the menu bar's text colour ourselves.
                NSColor.labelColor.withAlphaComponent(paused ? 0.45 : 1).setFill()
                rect.fill(using: .sourceAtop)
                let dot = NSRect(x: rect.maxX - 8, y: rect.maxY - 8, width: 7, height: 7)
                NSColor(Theme.bg).setFill()
                NSBezierPath(ovalIn: dot.insetBy(dx: -1.5, dy: -1.5)).fill()
                NSColor(Theme.warning).setFill()
                NSBezierPath(ovalIn: dot).fill()
            }
            return true
        }
        image.isTemplate = !problem
        return image
    }
}
