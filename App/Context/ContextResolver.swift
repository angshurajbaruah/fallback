import AppKit

/// Captures where a pick is going, at the moment the panel opens (FR-4, PRD 9.3 step 3).
@MainActor
enum ContextResolver {
    static func capture(host: NSRunningApplication) -> [String] {
        let app = AXUIElementCreateApplication(host.processIdentifier)
        let title = app.element(kAXFocusedWindowAttribute)?.string(kAXTitleAttribute) ?? "—"
        var lines = ["window title “\(title)” (Accessibility)"]
        guard let id = host.bundleIdentifier, let script = tabScript(for: id) else {
            lines.append("no tab address for this app, window title only")
            return lines
        }
        var error: NSDictionary?
        let result = NSAppleScript(source: script)?.executeAndReturnError(&error).stringValue
        if let parts = result?.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false), parts.count == 2 {
            lines.append("tab \(parts[0])  “\(parts[1])” (Apple Events)")
        } else {
            lines.append("✗ couldn't read the tab (Apple Events): \(describe(error))")
        }
        return lines
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
        // shortcut: runs on the main thread with a 2 s cap; move off-main in M2 if it ever stalls.
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
