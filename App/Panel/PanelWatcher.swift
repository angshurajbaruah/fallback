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
        var context: PanelContext?
        var picks: [Pick] = []
        var closedBy: CloseReason = .unknown
    }

    /// Called once per confirmed pick (not for Cancel), with the files, where they went and how they were found.
    typealias OnPick = @MainActor ([Pick], PanelContext, DetectionMethod) -> Void

    private let log: DetectionLog
    private let onPick: OnPick
    private var timer: Timer?
    private var monitor: Any?
    private var lastHost: NSRunningApplication?
    private var tracked: Tracked?

    init(log: DetectionLog, onPick: @escaping OnPick) {
        self.log = log
        self.onPick = onPick
    }

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
            let hash = Int(bitPattern: CFHash(element))
            guard !rejected.contains(hash) else { continue }
            let isSheetOrDialog = viaService || element.role == "AXSheet" || element.string(kAXSubroleAttribute) == "AXDialog"
            let defaultButton = element.element(kAXDefaultButtonAttribute)
            guard isSheetOrDialog || defaultButton != nil else { continue }
            // Standard file panels name their buttons OKButton and CancelButton, whatever the label or language.
            // Mail's sheet doesn't report a default button, so these names are the main signal.
            let buttons = PanelReader.buttons(in: element)
            let ok = buttons.first { $0.string(kAXIdentifierAttribute) == "OKButton" } ?? defaultButton
            let cancel = buttons.first { $0.string(kAXIdentifierAttribute) == "CancelButton" }
                ?? element.element(kAXCancelButtonAttribute)
            // A collapsed Save panel has no file list, but must still be recognised (and ignored).
            let isSave = ok.map { PanelKind(defaultButtonTitle: $0.string(kAXTitleAttribute) ?? "") == .save } ?? false
            guard let ok, cancel != nil, isSave || PanelReader.hasFileList(element) else {
                // Main windows don't turn into panels, so check them once. Sheets may still be loading.
                if !isSheetOrDialog { reject(hash, element, ok) } else { noteScan(element) }
                continue
            }
            begin(element, button: ok, cancel: cancel, host: host, viaService: viaService)
            return
        }
        noteUnseenFocus()
    }

    private var lastUnseen = ""

    /// Spike diagnostic: keyboard focus is in a file list but no panel was found. Logs who owns it
    /// and the parents above it, once per change, to show where the panel lives.
    private func noteUnseenFocus() {
        guard let app = AXUIElementCreateSystemWide().element(kAXFocusedApplicationAttribute),
              let focused = app.element(kAXFocusedUIElementAttribute),
              let role = focused.role, ["AXList", "AXOutline", "AXTable", "AXBrowser"].contains(role)
        else { return }
        var pid: pid_t = 0
        AXUIElementGetPid(app, &pid)
        var chain: [String] = []
        var node: AXUIElement? = focused
        while let current = node, chain.count < 15 {
            if current.role == "AXWebArea" { return } // a list inside a web page, not a panel
            chain.append(Self.shape(current))
            node = current.element(kAXParentAttribute)
        }
        let owner = NSRunningApplication(processIdentifier: pid).map { "\($0.localizedName ?? "?") (\($0.bundleIdentifier ?? "?"))" } ?? "pid \(pid)"
        let line = "focus in \(owner): \(chain.joined(separator: " < "))"
        guard line != lastUnseen else { return }
        lastUnseen = line
        log.add("UNSEEN", line)
    }

    private var rejected: Set<Int> = []
    private var lastScan = ""

    private func reject(_ hash: Int, _ element: AXUIElement, _ button: AXUIElement?) {
        if rejected.count > 500 { rejected.removeAll() }
        rejected.insert(hash)
        log.add("SKIPPED", "\(Self.shape(element)) has a default button “\(button?.string(kAXTitleAttribute) ?? "")” but isn't a file panel")
    }

    /// Spike diagnostic for a sheet or dialog that looked close but didn't qualify. Logged when it changes.
    private func noteScan(_ element: AXUIElement) {
        let buttons = PanelReader.buttons(in: element)
            .map { "\($0.string(kAXTitleAttribute) ?? "")#\($0.string(kAXIdentifierAttribute) ?? "-")" }
        let scan = "\(Self.shape(element)) buttons \(buttons) · file list: \(PanelReader.hasFileList(element) ? "yes" : "no")"
        guard scan != lastScan else { return }
        lastScan = scan
        log.add("NEAR MISS", scan)
    }

    private static func shape(_ element: AXUIElement) -> String {
        "\(element.role ?? "?")/\(element.string(kAXSubroleAttribute) ?? "-")"
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

    private func begin(_ element: AXUIElement, button: AXUIElement, cancel: AXUIElement?, host: NSRunningApplication, viaService: Bool) {
        let buttonTitle = button.string(kAXTitleAttribute) ?? ""
        let kind = PanelKind(defaultButtonTitle: buttonTitle)
        var panel = Tracked(element: element, kind: kind, defaultButton: button,
                            cancelButton: cancel)
        let app = "\(host.localizedName ?? "?") (\(host.bundleIdentifier ?? "?"))"
        guard kind == .open else {
            log.add("IGNORED", "Save panel in \(app), button “\(buttonTitle)”")
            tracked = panel
            return
        }
        let drawnBy = viaService ? "drawn by the Open and Save Panel Service" : "drawn by the app itself"
        log.add("OPEN PANEL", "\(app) · \(drawnBy) · \(Self.shape(element)) · button “\(buttonTitle)”")
        let context = ContextResolver.capture(host: host, panel: element)
        panel.context = context
        log.add("CONTEXT", "window title “\(context.windowTitle ?? "—")”")
        if let url = context.url { log.add("CONTEXT", "tab \(url)  “\(context.tabTitle ?? "")” (Apple Events)") }
        if let note = context.note { log.add("CONTEXT", note) }
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
            else if event.clickCount == 2 {
                panel.closedBy = .doubleClick
                // A double-click opens the file and closes the panel at once: read the row under the mouse.
                if let row = PanelReader.row(under: hit) {
                    panel.picks = [row]
                    tracked = panel
                    return
                }
            }
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
        guard let context = panel.context else { return }
        // Method A found the files: record now.
        if !fromA.isEmpty { onPick(panel.picks, context, .axPanel) }
        Task {
            var fromB: [String] = []
            // One quick try so a pick's lines stay together; in testing Spotlight never matched (0 of 34).
            try? await Task.sleep(for: .seconds(0.5))
            fromB = await Spotlight.recentlyUsed(names: names, withinSeconds: 10)
            if fromB.isEmpty { log.add("METHOD B", "✗ Spotlight found no file used in the last 10 seconds") }
            for path in fromB { log.add("METHOD B", path) }
            if fromA.isEmpty {
                if !fromB.isEmpty {
                    onPick(fromB.map { Pick(path: $0, name: ($0 as NSString).lastPathComponent) }, context, .spotlight)
                } else if !names.isEmpty {
                    onPick(panel.picks, context, .axPanel) // name only: recorded with Low confidence (FR-6)
                }
            }
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
