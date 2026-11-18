import Foundation
import GRDB

/// FR-6: High = file and URL known, Medium = file known but only a window title, Low = file guessed.
public enum Confidence: String, Sendable, Codable, DatabaseValueConvertible {
    case high, medium, low

    public init(fileKnown: Bool, urlKnown: Bool) {
        self = !fileKnown ? .low : (urlKnown ? .high : .medium)
    }
}

public enum DetectionMethod: String, Sendable {
    case axPanel = "ax_panel", spotlight, manual
}

/// What the app hands the store when a pick is detected.
public struct NewSend: Sendable {
    public var path: String?
    public var fileName: String
    public var appBundleID: String
    public var appName: String
    public var url: String?
    public var pageTitle: String?
    public var method: DetectionMethod
    public var sentAt: Date

    public init(path: String?, fileName: String, appBundleID: String, appName: String, url: String?,
                pageTitle: String?, method: DetectionMethod, sentAt: Date = Date()) {
        self.path = path; self.fileName = fileName; self.appBundleID = appBundleID; self.appName = appName
        self.url = url; self.pageTitle = pageTitle; self.method = method; self.sentAt = sentAt
    }
}

/// One send as the UI shows it, joined with its file and destination.
public struct SendRow: Sendable, Identifiable, Hashable, Decodable, FetchableRecord {
    public var id: Int64
    public var fileName: String
    public var path: String?
    public var sha256: String?
    public var sizeBytes: Int64?
    public var destinationID: Int64
    public var destinationKey: String
    public var destinationLabel: String
    public var appBundleID: String
    public var appName: String
    public var url: String?
    public var pageTitle: String?
    public var confidence: Confidence
    public var sentAt: Date
    public var fileID: Int64?
    /// From document families (M3): v5, whether it's a tailored variant, and which document.
    public var versionNumber: Int?
    public var isVariant: Bool?
    public var familyID: Int64?
    public var familyName: String?

    public var versionLabel: String? { versionNumber.map { "v\($0)" } }

    /// The quiet second line under a destination: the site for web sends, the app otherwise.
    public var placeDetail: String {
        if let url, let host = URL(string: url)?.host(), !host.isEmpty {
            return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        }
        return appName
    }
}

/// A destination with its send count, for the sidebar and By destination (FR-11).
public struct DestinationSummary: Sendable, Identifiable, Hashable, Decodable, FetchableRecord {
    public var id: Int64
    public var key: String
    public var label: String
    public var labelSource: String
    public var sendCount: Int
    public var lastSentAt: Date
}
