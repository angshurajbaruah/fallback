import AppKit

/// Where a pick is going, captured when the panel opens (FR-4).
struct PanelContext: Sendable {
    var appName: String
    var bundleID: String
    var windowTitle: String?
    var url: String?
    var tabTitle: String?
    /// Why the tab address is missing, for the debug log.
    var note: String?

    /// The title that best describes the page: the tab title for browsers, else the window title.
    var pageTitle: String? { tabTitle ?? windowTitle }
}

/// Captures where a pick is going, at the moment the panel opens (FR-4, PRD 9.3 step 3).
@MainActor
enum ContextResolver {
    static func capture(host: NSRunningApplication, panel: AXUIElement) -> PanelContext {
        // A sheet's parent is the window it's attached to; otherwise use the app's focused window.
        let window = panel.role == "AXSheet" ? panel.element(kAXParentAttribute)
            : AXUIElementCreateApplication(host.processIdentifier).element(kAXFocusedWindowAttribute)
        let bundleID = host.bundleIdentifier ?? "unknown"
        var context = PanelContext(appName: host.localizedName?.trimmingCharacters(in: .controlCharacters.union(.init(charactersIn: "\u{200E}"))) ?? bundleID,
                                   bundleID: bundleID,
                                   windowTitle: window?.string(kAXTitleAttribute).flatMap { $0.isEmpty ? nil : $0 })
        guard let script = tabScript(for: bundleID) else {
            context.note = "no tab address for this app, window title only"
            return context
        }
        var error: NSDictionary?
        let result = NSAppleScript(source: script)?.executeAndReturnError(&error).stringValue
        if let parts = result?.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false), parts.count == 2 {
            context.url = String(parts[0])
            context.tabTitle = String(parts[1])
        } else {
            context.note = "✗ couldn't read the tab (Apple Events): \(describe(error))"
        }
        return context
    }

    private static func tabScript(for bundleID: String) -> String? {
        let body: String
        if bundleID == WatchedApps.safari {
            body = "tell front document to return (URL) & linefeed & (name)"
        } else if WatchedApps.chromium.contains(bundleID) {
            body = "tell front window to return (URL of active tab) & linefeed & (title of active tab)"
        } else {
            return nil
        }
        // shortcut: runs on the main thread with a 2 s cap; it never stalled in M1 testing. Move off-main if it does.
        return """
        with timeout of 2 seconds
            tell application id "\(bundleID)" to \(body)
        end timeout
        """
    }

    private static func describe(_ error: NSDictionary?) -> String {
        switch error?[NSAppleScript.errorNumber] as? Int {
        case -1743: "not allowed. Turn Fallback on in System Settings › Privacy & Security › Automation"
        case -1712: "the browser didn't answer within 2 seconds"
        default: error?[NSAppleScript.errorMessage] as? String ?? "unknown error"
        }
    }
}
