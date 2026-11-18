import Foundation

/// What gets indexed (FR-21, FR-22). Users can add types and exclusions; defaults always apply.
public struct IndexRules: Sendable {
    public static let defaultTypes: Set<String> = [
        "pdf", "doc", "docx", "pages", "ppt", "pptx", "key", "xls", "xlsx", "numbers",
        "csv", "txt", "md", "rtf", "png", "jpg", "jpeg", "heic", "zip",
    ]
    /// Folder names never descended into.
    public static let defaultExcludes: Set<String> = ["node_modules", ".git", "Library", "Caches", "cache", ".cache", ".Trash"]
    public static let minimumBytes: Int64 = 1024

    public var types: Set<String>
    public var excludes: Set<String>

    public init(extraTypes: [String] = [], extraExcludes: [String] = []) {
        types = Self.defaultTypes.union(extraTypes.map { $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ". ")) })
        excludes = Self.defaultExcludes.union(extraExcludes)
    }

    /// Whether a folder should be skipped entirely: hidden folders, app bundles and the exclude list.
    public func skipsFolder(_ name: String) -> Bool {
        name.hasPrefix(".") || name.lowercased().hasSuffix(".app") || excludes.contains(name)
    }

    /// Whether a file (or document package such as a .key bundle) is indexed.
    public func indexes(name: String, sizeBytes: Int64?, isPackage: Bool = false) -> Bool {
        guard !name.hasPrefix("."), types.contains((name as NSString).pathExtension.lowercased()) else { return false }
        if isPackage { return true } // packages have no single size; their type is enough
        return (sizeBytes ?? 0) >= Self.minimumBytes
    }

    /// Whether any folder on the path is excluded (for FSEvents paths deep inside a watched folder).
    public func skipsPath(_ path: String, under root: String) -> Bool {
        let relative = path.hasPrefix(root) ? String(path.dropFirst(root.count)) : path
        let parts = relative.split(separator: "/").map(String.init)
        return parts.dropLast().contains(where: skipsFolder)
    }
}
