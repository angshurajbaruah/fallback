import CryptoKit
import Foundation

/// Metadata and fingerprint of a file at send time. Never the contents (CLAUDE.md).
public struct FileFacts: Sendable {
    /// Volume + file number, so a renamed or moved file is still the same file.
    public var identity: String?
    public var sha256: String?
    public var sizeBytes: Int64?
    public var modifiedAt: Date?

    public init(identity: String? = nil, sha256: String? = nil, sizeBytes: Int64? = nil, modifiedAt: Date? = nil) {
        self.identity = identity; self.sha256 = sha256; self.sizeBytes = sizeBytes; self.modifiedAt = modifiedAt
    }

    public static func read(path: String) -> FileFacts {
        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        var facts = FileFacts()
        if let device = attributes?[.systemNumber], let inode = attributes?[.systemFileNumber] {
            facts.identity = "\(device):\(inode)"
        }
        facts.sizeBytes = (attributes?[.size] as? NSNumber)?.int64Value
        facts.modifiedAt = attributes?[.modificationDate] as? Date
        if attributes?[.type] as? FileAttributeType == .typeRegular { facts.sha256 = sha256(path: path) }
        return facts
    }

    /// Streamed in 1 MB chunks so large files don't fill memory (PRD 9.1).
    static func sha256(path: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try? handle.read(upToCount: 1 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
