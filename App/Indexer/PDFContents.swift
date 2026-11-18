import CoreGraphics
import FallbackCore
import PDFKit

/// Reads a PDF on-device for PRD 8.3 layers 2 and 3: title, author, dates, internal ID and text.
/// The text only feeds the similarity fingerprint and is then dropped.
enum PDFContents {
    static let maxPages = 200 // PRD 8.3: text extraction stops at 200 pages

    static func read(_ url: URL) -> DocumentContents? {
        guard let document = PDFDocument(url: url), !document.isLocked else { return nil }
        let attributes = document.documentAttributes ?? [:]
        var text = ""
        for index in 0..<min(document.pageCount, maxPages) {
            text += (document.page(at: index)?.string ?? "") + "\n"
            if text.utf8.count > 5_000_000 { break }
        }
        return DocumentContents(title: attributes[PDFDocumentAttribute.titleAttribute] as? String,
                                author: attributes[PDFDocumentAttribute.authorAttribute] as? String,
                                created: attributes[PDFDocumentAttribute.creationDateAttribute] as? Date,
                                modified: attributes[PDFDocumentAttribute.modificationDateAttribute] as? Date,
                                internalID: internalID(url),
                                text: text)
    }

    /// The first half of the PDF's file identifier, which stays the same across edits of one document.
    private static func internalID(_ url: URL) -> String? {
        guard let identifiers = CGPDFDocument(url as CFURL)?.fileIdentifier else { return nil }
        var string: CGPDFStringRef?
        guard CGPDFArrayGetString(identifiers, 0, &string), let string, let bytes = CGPDFStringGetBytePtr(string) else { return nil }
        return (0..<CGPDFStringGetLength(string)).map { String(format: "%02x", bytes[$0]) }.joined()
    }
}
