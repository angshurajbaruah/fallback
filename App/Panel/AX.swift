import ApplicationServices

/// Small readers over the Accessibility API. All return nil/empty instead of throwing.
extension AXUIElement {
    func value(_ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(self, attribute as CFString, &value) == .success ? value : nil
    }

    func string(_ attribute: String) -> String? { value(attribute) as? String }

    func element(_ attribute: String) -> AXUIElement? {
        guard let v = value(attribute), CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
        return (v as! AXUIElement)
    }

    func elements(_ attribute: String) -> [AXUIElement] {
        guard let array = value(attribute) as? [AnyObject] else { return [] }
        return array.compactMap { CFGetTypeID($0) == AXUIElementGetTypeID() ? ($0 as! AXUIElement) : nil }
    }

    var role: String? { string(kAXRoleAttribute) }
    var children: [AXUIElement] { elements(kAXChildrenAttribute) }

    /// True only when the element is definitely destroyed; a slow app counts as still there.
    var isGone: Bool {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(self, kAXRoleAttribute as CFString, &value) == .invalidUIElement
    }

    /// Depth-first search of this element and its descendants.
    func first<T>(depth: Int, _ match: (AXUIElement) -> T?) -> T? {
        if let found = match(self) { return found }
        guard depth > 0 else { return nil }
        for child in children { if let found = child.first(depth: depth - 1, match) { return found } }
        return nil
    }

    func matches(_ other: AXUIElement?) -> Bool {
        guard let other else { return false }
        return CFEqual(self, other) || element(kAXParentAttribute).map { CFEqual($0, other) } == true
    }
}
