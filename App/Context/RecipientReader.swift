import AppKit

/// PRD 16.4 P-1 (extends FR-8): reads the addresses in an email's To field through Accessibility, so the
/// recipient's company can be the destination. Only the To field is read, never the subject or body.
/// The addresses themselves are never stored: only the company domain becomes the destination.
@MainActor
enum RecipientReader {
    static let mailApps: Set<String> = ["com.apple.mail", "com.microsoft.Outlook"]
    static let webmailHosts = ["mail.google.com", "outlook.live.com", "outlook.office.com", "outlook.office365.com"]

    /// Whether this pick is happening in an email compose window Fallback knows how to read.
    static func applies(bundleID: String, url: String?) -> Bool {
        if mailApps.contains(bundleID) { return true }
        guard let host = url.flatMap({ URL(string: $0)?.host()?.lowercased() }) else { return false }
        return webmailHosts.contains(host)
    }

    /// The To addresses in `window`, plus a line for the debug log.
    static func read(window: AXUIElement?, app: NSRunningApplication) -> (addresses: [String], note: String) {
        guard let window else { return ([], "recipient: no compose window") }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        // Chrome-based browsers build their page's accessibility tree only once asked.
        let enabled = enableWebAccessibility(appElement)
        var found = scan(window)
        if found.addresses.isEmpty && enabled {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3)) // give the page a moment to build its tree
            found = scan(window)
        }
        if found.addresses.isEmpty {
            var note = found.toField ? "recipient: To field found but no address in it (a contact name only?)" : "recipient: no To field found"
            #if DEBUG
            note += "\n" + AXDump.outline(window) // development builds only: how this app describes its To field
            #endif
            return ([], note)
        }
        let domains = Set(found.addresses.compactMap { $0.split(separator: "@").last.map(String.init) })
        return (found.addresses, "recipient: \(found.addresses.count) address(es) at \(domains.sorted().joined(separator: ", "))")
    }

    /// Finds the To field and collects the addresses inside it (and in its parent row, where webmail draws
    /// recipient chips next to the input). Never searches the rest of the window, so an inbox list of
    /// senders can't be mistaken for recipients.
    private static func scan(_ window: AXUIElement) -> (addresses: [String], toField: Bool) {
        var budget = 4000
        guard let field = findToField(window, depth: 40, budget: &budget) else {
            // Gmail folds the To field into a line of text once you leave it (seen live on 20 Nov 2026), so read
            // the addresses above the Subject field in the same compose window, and nothing after it.
            budget = 4000
            guard let subject = findField(window, labelled: "subject", depth: 60, budget: &budget),
                  let compose = composeArea(around: subject) else { return ([], false) }
            var addresses: [String] = []
            var seen = 0
            var reachedSubject = false
            collectBefore(subject, in: compose, depth: 30, into: &addresses, seen: &seen, stop: &reachedSubject)
            let own = emails(in: window.string(kAXTitleAttribute) ?? "") // the account's own address, in the title
            return (addresses.filter { !own.contains($0) }, !addresses.isEmpty)
        }
        var addresses: [String] = []
        var seen = 0
        for area in [field, field.element(kAXParentAttribute)].compactMap({ $0 }) {
            collect(area, depth: 6, into: &addresses, seen: &seen)
            if !addresses.isEmpty { break }
        }
        return (addresses, true)
    }

    private static func findField(_ element: AXUIElement, labelled label: String, depth: Int, budget: inout Int) -> AXUIElement? {
        budget -= 1
        guard budget > 0 else { return nil }
        if let role = element.role, fieldRoles.contains(role),
           [kAXDescriptionAttribute, kAXTitleAttribute].contains(where: { element.string($0)?.lowercased() == label }) { return element }
        guard depth > 0, !isMessageList(element) else { return nil }
        for child in element.children {
            if let found = findField(child, labelled: label, depth: depth - 1, budget: &budget) { return found }
        }
        return nil
    }

    /// The compose window around a field: the nearest dialog or region ("New Message") above it.
    private static func composeArea(around field: AXUIElement) -> AXUIElement? {
        var current = field.element(kAXParentAttribute)
        for _ in 0..<12 {
            guard let element = current else { return nil }
            let sub = element.string(kAXSubroleAttribute)
            if sub == "AXApplicationDialog" || sub == "AXLandmarkRegion" { return element }
            current = element.element(kAXParentAttribute)
        }
        return nil
    }

    /// Addresses in `area`, in reading order, up to (not including) `stopAt`.
    private static func collectBefore(_ stopAt: AXUIElement, in area: AXUIElement, depth: Int,
                                      into addresses: inout [String], seen: inout Int, stop: inout Bool) {
        guard !stop else { return }
        if CFEqual(area, stopAt) { stop = true; return }
        seen += 1
        guard seen < 600 else { stop = true; return }
        for attribute in [kAXValueAttribute, kAXDescriptionAttribute, kAXTitleAttribute] {
            guard let text = area.string(attribute) else { continue }
            for address in emails(in: text) where !addresses.contains(address) { addresses.append(address) }
        }
        guard depth > 0 else { return }
        for child in area.children {
            collectBefore(stopAt, in: child, depth: depth - 1, into: &addresses, seen: &seen, stop: &stop)
            if stop { return }
        }
    }

    private static func findToField(_ element: AXUIElement, depth: Int, budget: inout Int) -> AXUIElement? {
        budget -= 1
        guard budget > 0 else { return nil }
        if isToField(element) { return element }
        // A message list (Gmail's inbox) can't hold the To field: skip it, saving time and never reading it.
        guard depth > 0, !isMessageList(element) else { return nil }
        for child in element.children {
            if let found = findToField(child, depth: depth - 1, budget: &budget) { return found }
        }
        return nil
    }

    /// A table or outline with many rows: an inbox, not a form. Gmail lays its compose window out with
    /// small tables, so those are still searched.
    static func isMessageList(_ element: AXUIElement) -> Bool {
        guard element.role == kAXTableRole || element.role == kAXOutlineRole else { return false }
        var count: CFIndex = 0
        return AXUIElementGetAttributeValueCount(element, kAXRowsAttribute as CFString, &count) == .success && count > 12
    }

    static let fieldRoles: Set<String> = [kAXTextFieldRole, kAXComboBoxRole, kAXTextAreaRole, "AXTokenField"]

    /// A text field labelled To. Mail labels it with a separate "To:" text (its title element, seen live on
    /// 20 Nov 2026); webmail may use an accessible name ("To recipients", "To") or a linked label.
    private static func isToField(_ element: AXUIElement) -> Bool {
        guard let role = element.role, fieldRoles.contains(role) else { return false }
        var labels = [kAXDescriptionAttribute, kAXTitleAttribute, kAXPlaceholderValueAttribute].compactMap { element.string($0) }
        if let title = element.element(kAXTitleUIElementAttribute) {
            labels += [kAXValueAttribute, kAXTitleAttribute, kAXDescriptionAttribute].compactMap { title.string($0) }
        }
        return labels.contains { ["to", "to:", "to recipients"].contains($0.trimmingCharacters(in: .whitespaces).lowercased()) }
    }

    private static func collect(_ element: AXUIElement, depth: Int, into addresses: inout [String], seen: inout Int) {
        seen += 1
        guard seen < 300 else { return }
        for attribute in [kAXValueAttribute, kAXDescriptionAttribute, kAXTitleAttribute, kAXHelpAttribute] {
            guard let text = element.string(attribute) else { continue }
            for address in emails(in: text) where !addresses.contains(address) { addresses.append(address) }
        }
        guard depth > 0 else { return }
        for child in element.children { collect(child, depth: depth - 1, into: &addresses, seen: &seen) }
    }

    static func emails(in text: String) -> [String] {
        let pattern = #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .compactMap { Range($0.range, in: text).map { text[$0].lowercased() } }
    }

    /// Returns true if it switched the page tree on just now.
    private static func enableWebAccessibility(_ app: AXUIElement) -> Bool {
        var current: CFTypeRef?
        if AXUIElementCopyAttributeValue(app, "AXManualAccessibility" as CFString, &current) == .success,
           (current as? Bool) == true { return false }
        return AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue) == .success
    }
}
