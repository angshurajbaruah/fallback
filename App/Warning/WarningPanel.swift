import AppKit
import SwiftUI

/// PRD 9.7 / FR-26: a floating, non-activating panel at the top right, under the menu bar.
/// It sits above normal windows but never takes keyboard focus, so typing in the browser carries on.
final class WarningPanel: NSPanel {
    /// Only the "destination unknown" card takes typing, and only after its field is clicked
    /// (becomesKeyOnlyIfNeeded). Every other card can never become key.
    var acceptsTyping = false
    override var canBecomeKey: Bool { acceptsTyping }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(contentRect: .zero, styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovable = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        appearance = NSAppearance(named: .darkAqua) // the cards are designed dark
    }
}

/// Clicks work on the first try even though the panel never becomes key.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Shows one card at a time and animates it in and out.
@MainActor
final class WarningPresenter {
    private var panel: WarningPanel?
    private let margin: CGFloat = 12

    func show<Content: View>(_ view: Content, acceptsTyping: Bool = false) {
        dismiss(animated: false)
        let panel = WarningPanel()
        panel.acceptsTyping = acceptsTyping
        let host = FirstMouseHostingView(rootView: view)
        host.frame.size = host.fittingSize
        panel.contentView = host
        // The screen with the menu bar; never the centre of the screen.
        guard let screen = NSScreen.screens.first else { return }
        let size = host.fittingSize
        let visible = screen.visibleFrame
        let target = NSRect(x: visible.maxX - size.width - margin, y: visible.maxY - size.height - margin,
                            width: size.width, height: size.height)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        panel.setFrame(reduceMotion ? target : target.offsetBy(dx: size.width + margin, dy: 0), display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless() // shown without activating Fallback
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0.2 : 0.28
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(target, display: true)
            panel.animator().alphaValue = 1
        }
        self.panel = panel
    }

    func dismiss(animated: Bool = true) {
        guard let panel else { return }
        self.panel = nil
        guard animated else { panel.orderOut(nil); return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = 0
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            panel.orderOut(nil)
        }
    }
}
