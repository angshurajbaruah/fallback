#if DEBUG
import AppKit

/// Development only: `open -n Fallback.app --args --ax-dump <bundleID> <file>` writes the recipient-related
/// part of that app's front window (anything labelled To, Cc or recipients, with its ancestors and a few
/// levels below), so the To-field reader (P-1) can be matched to how each app really describes it.
@MainActor
enum AXDump {
    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let flag = args.firstIndex(of: "--ax-dump"), flag + 2 < args.count,
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: args[flag + 1]).first else { return false }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        // macOS only shows an app the windows on the current desktop: wait (up to 3 minutes) until it's in front.
        let deadline = Date(timeIntervalSinceNow: 180)
        let wanted = flag + 3 < args.count ? args[flag + 3].lowercased() : ""
        func ready() -> Bool {
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else { return false }
            return wanted.isEmpty || (appElement.element(kAXFocusedWindowAttribute)?.string(kAXTitleAttribute)?.lowercased().contains(wanted) ?? false)
        }
        while !ready(), Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))
        }
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 2))
        var out = ["trusted: \(AXIsProcessTrusted())", "ready: \(ready())"]
        // Only the window that's in front: never the user's other windows.
        var windows = appElement.element(kAXFocusedWindowAttribute).map { [$0] } ?? []
        if !ready() { windows = [] }
        out.append("windows: \(appElement.elements(kAXWindowsAttribute).count) listed, \(windows.count) found; children: \(appElement.children.count)")
        let start = Date()
        for (index, window) in windows.enumerated() {
            var count = 0
            var lines: [String] = []
            walk(window, depth: 0, path: [], count: &count, lines: &lines, below: -1)
            out.append("== window \(index) “\(window.string(kAXTitleAttribute) ?? "")” nodes: \(count)")
            out += lines
        }
        out.append("took \(Int(Date().timeIntervalSince(start) * 1000)) ms")
        try? out.joined(separator: "\n").write(toFile: args[flag + 2], atomically: true, encoding: .utf8)
        return true
    }

    /// The recipient-related outline of one window (the compose window the user is attaching from), for the debug log.
    static func outline(_ window: AXUIElement, limit: Int = 150) -> String {
        var count = 0
        var lines: [String] = []
        walk(window, depth: 0, path: [], count: &count, lines: &lines, below: -1)
        return "AX outline (\(count) nodes, recipient-related only):\n" + lines.prefix(limit).joined(separator: "\n")
    }

    /// Whole labels only ("To", "Cc:", "To recipients"), not sentences that happen to contain "to".
    private static let pattern = try! NSRegularExpression(pattern: #"(^|\|\s*)(to|cc|bcc|from|to recipients|recipients?):?\s*($|\|)"#, options: .caseInsensitive)

    private static func describe(_ e: AXUIElement) -> String {
        var parts = [e.role ?? "?"]
        if let labelled = e.value("AXLinkedUIElements") as? [AnyObject] { parts.append("linked=\(labelled.count)") }
        for (key, attribute) in [("sub", kAXSubroleAttribute), ("rdesc", kAXRoleDescriptionAttribute), ("desc", kAXDescriptionAttribute),
                                 ("title", kAXTitleAttribute), ("value", kAXValueAttribute), ("ph", kAXPlaceholderValueAttribute),
                                 ("help", kAXHelpAttribute), ("id", "AXDOMIdentifier"), ("class", "AXDOMClassList")] {
            if let text = e.string(attribute), !text.isEmpty { parts.append("\(key)=“\(text.prefix(80))”") }
        }
        if let titleElement = e.element(kAXTitleUIElementAttribute) { parts.append("titleUI=“\(titleElement.string(kAXValueAttribute) ?? titleElement.string(kAXTitleAttribute) ?? "")”") }
        return parts.joined(separator: " ")
    }

    private static func labels(_ e: AXUIElement) -> String {
        [kAXDescriptionAttribute, kAXTitleAttribute, kAXPlaceholderValueAttribute, kAXRoleDescriptionAttribute]
            .compactMap { e.string($0) }.joined(separator: " | ")
            + (e.element(kAXTitleUIElementAttribute).flatMap { $0.string(kAXValueAttribute) }.map { " | " + $0 } ?? "")
    }

    /// Prints matching nodes with their ancestor chain, and up to 4 levels under each match.
    private static func walk(_ e: AXUIElement, depth: Int, path: [String], count: inout Int, lines: inout [String], below: Int) {
        count += 1
        // Never message lists (an inbox): only the compose window's fields matter here.
        guard count < 80_000, depth < 80, !RecipientReader.isMessageList(e) else { return }
        let text = labels(e)
        // Every text field too (a compose window has only a few: To, Subject, the search box), whatever its label.
        let isField = RecipientReader.fieldRoles.contains(e.role ?? "")
        let isMatch = isField || pattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
        let line = String(repeating: "  ", count: depth) + describe(e)
        var stillBelow = below > 0 ? below - 1 : -1
        if isMatch {
            for (i, ancestor) in path.enumerated() where !lines.contains(ancestor) { lines.append(ancestor); _ = i }
            lines.append(">> " + line)
            stillBelow = 3
        } else if below > 0 {
            lines.append(line)
        }
        for child in e.children { walk(child, depth: depth + 1, path: Array((path + [line]).suffix(6)), count: &count, lines: &lines, below: stillBelow) }
    }
}
#endif
