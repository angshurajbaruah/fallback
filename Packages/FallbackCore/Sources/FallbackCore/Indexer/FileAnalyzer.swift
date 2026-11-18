import Foundation

/// Facts read from inside a document (PRD 8.3 layer 2) plus its text for the content fingerprint.
/// The text is used once to build the fingerprint and then dropped; it is never stored.
public struct DocumentContents: Sendable {
    public var title: String?
    public var author: String?
    public var created: Date?
    public var modified: Date?
    public var internalID: String?
    public var text: String?

    public init(title: String? = nil, author: String? = nil, created: Date? = nil, modified: Date? = nil,
                internalID: String? = nil, text: String? = nil) {
        self.title = title; self.author = author; self.created = created; self.modified = modified
        self.internalID = internalID; self.text = text
    }
}

/// Everything Fallback keeps about a file: metadata and fingerprints, never contents.
public struct IndexedFile: Sendable {
    public var path: String
    public var name: String
    public var facts: FileFacts
    public var createdAt: Date?
    public var whereFrom: String?
    public var downloadedAt: Date?
    public var docTitle: String?
    public var docAuthor: String?
    public var docCreatedAt: Date?
    public var docModifiedAt: Date?
    public var docInternalID: String?
    public var textSignature: [UInt64]?
    public var imageHash: UInt64?
    public var imageColor: UInt32?

    public init(path: String, name: String, facts: FileFacts, createdAt: Date? = nil, whereFrom: String? = nil,
                downloadedAt: Date? = nil, docTitle: String? = nil, docAuthor: String? = nil, docCreatedAt: Date? = nil,
                docModifiedAt: Date? = nil, docInternalID: String? = nil, textSignature: [UInt64]? = nil, imageHash: UInt64? = nil) {
        self.path = path; self.name = name; self.facts = facts; self.createdAt = createdAt; self.whereFrom = whereFrom
        self.downloadedAt = downloadedAt; self.docTitle = docTitle; self.docAuthor = docAuthor; self.docCreatedAt = docCreatedAt
        self.docModifiedAt = docModifiedAt; self.docInternalID = docInternalID; self.textSignature = textSignature
        self.imageHash = imageHash
    }
}

/// Reads a file into an IndexedFile. PDFs are read by the app (PDFKit), passed in as `readPDF`.
public struct FileAnalyzer: Sendable {
    public typealias PDFReader = @Sendable (URL) -> DocumentContents?
    static let maxTextCharacters = 5_000_000 // PRD 8.3: stop at 5 MB of text

    private let readPDF: PDFReader

    public init(readPDF: @escaping PDFReader) { self.readPDF = readPDF }

    public func analyze(path: String) -> IndexedFile {
        let url = URL(filePath: path)
        let name = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        var file = IndexedFile(path: path, name: name, facts: FileFacts.read(path: path),
                               createdAt: attributes?[.creationDate] as? Date)
        let froms = Self.plistXattr(path, "com.apple.metadata:kMDItemWhereFroms") as? [String]
        file.whereFrom = froms?.last(where: { !$0.isEmpty }) // the referring page or thread is the "source"
        file.downloadedAt = (Self.plistXattr(path, "com.apple.metadata:kMDItemDownloadedDate") as? [Date])?.first

        var contents: DocumentContents?
        switch ext {
        case "pdf": contents = readPDF(url)
        case "docx", "pptx", "xlsx": contents = Self.office(url: url, ext: ext)
        case "txt", "md", "csv":
            if (file.facts.sizeBytes ?? 0) < 20 << 20 { contents = DocumentContents(text: try? String(contentsOf: url, encoding: .utf8)) }
        case "png", "jpg", "jpeg", "heic":
            file.imageHash = ImageSignature.make(url: url)
            file.imageColor = ImageSignature.averageColor(url: url)
        default: break
        }
        if let contents {
            file.docTitle = contents.title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            file.docAuthor = contents.author?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            file.docCreatedAt = contents.created
            file.docModifiedAt = contents.modified
            file.docInternalID = contents.internalID
            file.textSignature = contents.text.flatMap { TextSignature.make(String($0.prefix(Self.maxTextCharacters))) }
        }
        return file
    }

    /// Word, PowerPoint and Excel: core properties from docProps/core.xml and the visible text.
    static func office(url: URL, ext: String) -> DocumentContents? {
        guard let zip = ZipReader(url: url) else { return nil }
        let core = zip.read("docProps/core.xml").flatMap { String(data: $0, encoding: .utf8) } ?? ""
        func tag(_ name: String) -> String? {
            guard let range = core.range(of: "<\(name)[^>]*>([^<]*)</\(name)>", options: .regularExpression) else { return nil }
            return String(core[range]).replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression).nilIfEmpty
        }
        let dates = ISO8601DateFormatter()
        let parts: [String] = switch ext {
        case "docx": ["word/document.xml"]
        case "pptx": zip.entries.keys.filter { $0.range(of: #"^ppt/slides/slide\d+\.xml$"#, options: .regularExpression) != nil }.sorted()
        default: ["xl/sharedStrings.xml"]
        }
        let text = parts.compactMap { zip.read($0).flatMap { String(data: $0, encoding: .utf8) } }
            .map { $0.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression) }
            .joined(separator: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
        return DocumentContents(title: tag("dc:title"), author: tag("dc:creator"),
                                created: tag("dcterms:created").flatMap(dates.date(from:)),
                                modified: tag("dcterms:modified").flatMap(dates.date(from:)),
                                text: text)
    }

    /// macOS stores download sources and dates as binary-plist extended attributes.
    static func plistXattr(_ path: String, _ name: String) -> Any? {
        let size = getxattr(path, name, nil, 0, 0, 0)
        guard size > 0 else { return nil }
        var data = Data(count: size)
        let read = data.withUnsafeMutableBytes { getxattr(path, name, $0.baseAddress, size, 0, 0) }
        guard read == size else { return nil }
        return try? PropertyListSerialization.propertyList(from: data, format: nil)
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
