import Foundation

/// What gets indexed (FR-21, FR-22). Users can add types, and turn each "Always skipped" group
/// off in Settings › Folders (screen 17); all three are on by default.
public struct IndexRules: Sendable, Equatable {
    public static let defaultTypes: Set<String> = [
        "pdf", "doc", "docx", "pages", "ppt", "pptx", "key", "xls", "xlsx", "numbers",
        "csv", "txt", "md", "rtf", "png", "jpg", "jpeg", "heic", "zip",
    ]
    /// "Hidden files, app bundles, Library, caches".
    static let systemFolders: Set<String> = ["Library", "Caches", "cache", ".cache", ".Trash"]
    /// "node_modules and .git folders".
    static let codeFolders: Set<String> = ["node_modules", ".git"]
    public static let minimumBytes: Int64 = 1024

    public var types: Set<String>
    public var excludes: Set<String>
    public var skipSystem: Bool
    public var skipCode: Bool
    public var skipTiny: Bool

    public init(extraTypes: [String] = [], extraExcludes: [String] = [],
                skipSystem: Bool = true, skipCode: Bool = true, skipTiny: Bool = true) {
        types = Self.defaultTypes.union(extraTypes.map(Self.normalisedType).filter { !$0.isEmpty })
        excludes = Set(extraExcludes)
        self.skipSystem = skipSystem
        self.skipCode = skipCode
        self.skipTiny = skipTiny
    }

    /// ".SKETCH " → "sketch".
    public static func normalisedType(_ text: String) -> String {
        text.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ". "))
    }

    /// Whether a folder should be skipped entirely.
    public func skipsFolder(_ name: String) -> Bool {
        if excludes.contains(name) { return true }
        if skipCode && Self.codeFolders.contains(name) { return true }
        if skipSystem && (name.hasPrefix(".") || name.lowercased().hasSuffix(".app") || Self.systemFolders.contains(name)) { return true }
        return false
    }

    /// Whether a file (or document package such as a .key bundle) is indexed.
    public func indexes(name: String, sizeBytes: Int64?, isPackage: Bool = false) -> Bool {
        guard types.contains((name as NSString).pathExtension.lowercased()) else { return false }
        if skipSystem && name.hasPrefix(".") { return false }
        if isPackage || !skipTiny { return true } // packages have no single size; their type is enough
        return (sizeBytes ?? 0) >= Self.minimumBytes
    }

    /// Whether any folder on the path is excluded (for FSEvents paths deep inside a watched folder).
    public func skipsPath(_ path: String, under root: String) -> Bool {
        let relative = path.hasPrefix(root) ? String(path.dropFirst(root.count)) : path
        let parts = relative.split(separator: "/").map(String.init)
        return parts.dropLast().contains(where: skipsFolder)
    }
}
