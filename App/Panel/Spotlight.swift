import CoreServices
import Foundation

/// Method B (PRD 9.4): ask Spotlight which files were "last used" in the past few seconds.
/// Picking a file in a panel updates its last-used date.
enum Spotlight {
    static func recentlyUsed(names: [String], withinSeconds seconds: Int) async -> [String] {
        await Task.detached { query(names: names, seconds: seconds) }.value
    }

    private static func query(names: [String], seconds: Int) -> [String] {
        var text = "kMDItemLastUsedDate >= $time.now(-\(seconds))"
        if !names.isEmpty {
            let byName = names.map { "kMDItemFSName == \"\(escape($0))\"" }.joined(separator: " || ")
            text += " && (\(byName))"
        }
        guard let query = MDQueryCreate(kCFAllocatorDefault, text as CFString, nil, nil) else { return [] }
        MDQueryExecute(query, CFOptionFlags(kMDQuerySynchronous.rawValue))
        return (0..<MDQueryGetResultCount(query)).compactMap { i in
            guard let raw = MDQueryGetResultAtIndex(query, i) else { return nil }
            let item = Unmanaged<MDItem>.fromOpaque(raw).takeUnretainedValue()
            return MDItemCopyAttribute(item, kMDItemPath) as? String
        }
    }

    private static func escape(_ name: String) -> String {
        name.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}
