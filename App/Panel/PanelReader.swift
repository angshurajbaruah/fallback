import ApplicationServices
import Foundation

/// A file chosen in a panel. Method A may only manage the name; Method B then looks up the path.
struct Pick: Equatable {
    var path: String?
    var name: String
}

/// Method A (PRD 9.4): read the panel's file list through Accessibility, the way VoiceOver does.
enum PanelReader {
    private struct Container { let element: AXUIElement; let inColumnView: Bool }

    private static let listRoles: Set<String> = ["AXOutline", "AXTable", "AXList"]

    /// An open panel has a file list somewhere inside; plain alerts don't.
    static func hasFileList(_ panel: AXUIElement) -> Bool { !containers(in: panel).isEmpty }

    /// The files currently selected in the panel.
    static func picks(in panel: AXUIElement) -> [Pick] {
        let found = containers(in: panel).filter { !isSidebar($0.element) }
        var lists = found.filter { !$0.inColumnView }.map(\.element)
        // Column view: every column has a selected folder; only the right-most selection is the file.
        if let column = found.filter(\.inColumnView).map(\.element).last(where: { !selectedRows($0).isEmpty }) {
            lists.append(column)
        }
        return lists.flatMap(selectedRows).compactMap(pick)
    }

    /// One line describing the lists found, so a failed read can be diagnosed from the log.
    static func describe(_ panel: AXUIElement) -> String {
        let parts = containers(in: panel).map { c in
            let id = c.element.string(kAXIdentifierAttribute) ?? c.element.string(kAXDescriptionAttribute) ?? "-"
            return "\(c.element.role ?? "?")(\(id))\(c.inColumnView ? "[column]" : "")"
        }
        return parts.joined(separator: " ")
    }

    private static func containers(in panel: AXUIElement) -> [Container] {
        var out: [Container] = []
        var visited = 0
        func walk(_ el: AXUIElement, depth: Int, inBrowser: Bool) {
            visited += 1
            guard depth < 14, visited < 600, let role = el.role, role != "AXWebArea" else { return }
            if listRoles.contains(role) { out.append(Container(element: el, inColumnView: inBrowser)); return }
            for child in el.children { walk(child, depth: depth + 1, inBrowser: inBrowser || role == "AXBrowser") }
        }
        walk(panel, depth: 0, inBrowser: false)
        return out
    }

    private static func isSidebar(_ el: AXUIElement) -> Bool {
        let label = [el.string(kAXIdentifierAttribute), el.string(kAXDescriptionAttribute)]
            .compactMap { $0 }.joined(separator: " ").lowercased()
        return label.contains("sidebar")
    }

    private static func selectedRows(_ list: AXUIElement) -> [AXUIElement] {
        let rows = list.elements(kAXSelectedRowsAttribute)
        return rows.isEmpty ? list.elements(kAXSelectedChildrenAttribute) : rows
    }

    private static func pick(_ row: AXUIElement) -> Pick? {
        if let url = row.first(depth: 3, { $0.value(kAXURLAttribute) as? URL }), url.isFileURL {
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
            if values?.isDirectory == true && values?.isPackage != true { return nil } // a folder, not a file
            return Pick(path: url.path, name: url.lastPathComponent)
        }
        let name = row.first(depth: 3) { el -> String? in
            for attr in [kAXValueAttribute, kAXTitleAttribute] {
                if let s = el.string(attr), !s.isEmpty { return s }
            }
            return nil
        }
        return name.map { Pick(path: nil, name: $0) }
    }
}
