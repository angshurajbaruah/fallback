import AppKit
import FallbackCore

/// Watches sending apps for file-open panels and reports what was picked (PRD 9.3, 9.4; FR-1 to FR-4).
@MainActor
final class PanelWatcher {
    /// Sandboxed apps (Safari, Mail, App Store apps) have their panel drawn by this system service.
    private static let panelService = "com.apple.appkit.xpc.openAndSavePanelService"

    private enum CloseReason: String {
        case defaultButton = "the Open button (or Return)"
        case doubleClick = "a double-click on a file"
        case cancel = "Cancel (or Escape)"
        case unknown = "unknown means (the panel just disappeared)"
    }

    private struct Tracked {
        let element: AXUIElement
        let kind: PanelKind
        let defaultButton: AXUIElement?
        let cancelButton: AXUIElement?
        var picks: [Pick] = []
        var closedBy: CloseReason = .unknown
    }

    private let log: DetectionLog
    private var timer: Timer?
    private var monitor: Any?
    private var lastHost: NSRunningApplication?
    private var tracked: Tracked?

    init(log: DetectionLog) { self.log = log }

    func start() {
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.5)
        // shortcut: polls 3x a second while a watched app is in front; switch to AXObserver if NFR CPU checks object.
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func tick() {
        guard AXIsProcessTrusted() else { return }
        if monitor == nil {
            // Only clicks and the Return/Escape keys are looked at, and only while a panel is open. No keys are stored.
            monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .keyDown]) { [weak self] event in
                MainActor.assumeIsolated { self?.handle(event) }
            }
        }
        let front = NSWorkspace.shared.frontmostApplication
        if let front, WatchedApps.contains(front.bundleIdentifier) { lastHost = front }

        if var panel = tracked {
            if panel.element.isGone {
                tracked = nil
                finish(panel)
            } else if panel.kind == .open {
                let now = PanelReader.picks(in: panel.element)
                if !now.isEmpty { panel.picks = now; tracked = panel }
            }
            return
        }

        guard let host = lastHost, !host.isTerminated, let front,
              front.processIdentifier == host.processIdentifier || front.bundleIdentifier == Self.panelService
        else { return }

        for (element, viaService) in candidates(host: host) {
            guard let button = element.element(kAXDefaultButtonAttribute), PanelReader.hasFileList(element) else { continue }
            begin(element, button: button, host: host, viaService: viaService)
            return
        }
    }

    private func candidates(host: NSRunningApplication) -> [(AXUIElement, Bool)] {
        var out = windowsAndSheets(pid: host.processIdentifier).map { ($0, false) }
        for service in NSWorkspace.shared.runningApplications where service.bundleIdentifier == Self.panelService {
            out += windowsAndSheets(pid: service.processIdentifier).map { ($0, true) }
        }
        return out
    }

    private func windowsAndSheets(pid: pid_t) -> [AXUIElement] {
        AXUIElementCreateApplication(pid).elements(kAXWindowsAttribute).flatMap { window in
            [window] + window.children.filter { $0.role == "AXSheet" }
        }
    }

    private func begin(_ element: AXUIElement, button: AXUIElement, host: NSRunningApplication, viaService: Bool) {
        let buttonTitle = button.string(kAXTitleAttribute) ?? ""
        let kind = PanelKind(defaultButtonTitle: buttonTitle)
        var panel = Tracked(element: element, kind: kind, defaultButton: button,
                            cancelButton: element.element(kAXCancelButtonAttribute))
        let app = "\(host.localizedName ?? "?") (\(host.bundleIdentifier ?? "?"))"
        guard kind == .open else {
            log.add("IGNORED", "Save panel in \(app), button “\(buttonTitle)”")
            tracked = panel
            return
        }
        let drawnBy = viaService ? "drawn by the Open and Save Panel Service" : "drawn by the app itself"
        log.add("OPEN PANEL", "\(app) · \(drawnBy) · button “\(buttonTitle)”")
        for line in ContextResolver.capture(host: host) { log.add("CONTEXT", line) }
        log.add("LISTS", PanelReader.describe(element))
        panel.picks = PanelReader.picks(in: element)
        tracked = panel
    }

    private func handle(_ event: NSEvent) {
        guard var panel = tracked, panel.kind == .open else { return }
        switch event.type {
        case .keyDown:
            switch event.keyCode {
            case 36, 76: panel.closedBy = .defaultButton                      // Return, Enter
            case 53: panel.closedBy = .cancel                                // Escape
            case 47 where event.modifierFlags.contains(.command): panel.closedBy = .cancel // Cmd-.
            default: return
            }
        case .leftMouseDown:
            let point = NSEvent.mouseLocation
            let screenHeight = NSScreen.screens.first?.frame.height ?? 0 // AX measures from the top of the main screen
            var hit: AXUIElement?
            AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(point.x), Float(screenHeight - point.y), &hit)
            guard let hit else { return }
            if hit.matches(panel.defaultButton) { panel.closedBy = .defaultButton }
            else if hit.matches(panel.cancelButton) { panel.closedBy = .cancel }
            else if event.clickCount == 2 { panel.closedBy = .doubleClick }
            else { return }
        default:
            return
        }
        // Read the selection right now: the panel may be gone before the next tick.
        let now = PanelReader.picks(in: panel.element)
        if !now.isEmpty { panel.picks = now }
        tracked = panel
    }

    private func finish(_ panel: Tracked) {
        guard panel.kind == .open else { return }
        if panel.closedBy == .cancel {
            log.add("CLOSED", "with Cancel. Nothing recorded.")
            return
        }
        log.add("CLOSED", "by \(panel.closedBy.rawValue)")
        if panel.picks.isEmpty { log.add("METHOD A", "✗ couldn't read a selected file") }
        for pick in panel.picks { log.add("METHOD A", pick.path ?? "name only: \(pick.name)") }

        let names = panel.picks.map(\.name)
        let fromA = Set(panel.picks.compactMap(\.path))
        let closedBy = panel.closedBy
        Task {
            var fromB: [String] = []
            for delay in [1.5, 3.0] { // Spotlight can take a moment to update
                try? await Task.sleep(for: .seconds(delay))
                fromB = await Spotlight.recentlyUsed(names: names, withinSeconds: 10)
                if !fromB.isEmpty { break }
            }
            if fromB.isEmpty { log.add("METHOD B", "✗ Spotlight found no file used in the last 10 seconds") }
            for path in fromB { log.add("METHOD B", path) }
            log.add("RESULT", Self.verdict(fromA: fromA, fromB: Set(fromB), aHadNames: !names.isEmpty, closedBy: closedBy))
        }
    }

    private static func verdict(fromA: Set<String>, fromB: Set<String>, aHadNames: Bool, closedBy: CloseReason) -> String {
        switch (fromA.isEmpty, fromB.isEmpty) {
        case (false, false): fromA == fromB ? "✓ A and B agree" : "⚠ A and B disagree, check which is right"
        case (false, true): "✓ Method A only"
        case (true, false): aHadNames ? "✓ Method B (A only read the name)" : "✓ Method B only (A read nothing)"
        case (true, true): closedBy == .unknown ? "✗ No file captured (or the panel was cancelled)" : "✗ No file captured"
        }
    }
}
