import Foundation

/// Layer 4 of PRD 8.3: the name stem, so "Resume_v3.pdf" and "resume-v5-final-final.pdf" share "resume".
public enum NameStem {
    static let markers: Set<String> = ["final", "draft", "revised", "updated", "new", "latest", "copy"]
    static let generic: Set<String> = ["document", "untitled", "scan", "image", "img", "file", "screenshot", "photo", "export"]
    static let filler: Set<String> = ["at", "of", "the", "and"]

    /// The stem used for grouping, or nil when it is under 4 characters or too generic (rule 4).
    public static func stem(_ fileName: String) -> String? {
        let words = tokens(fileName)
        let stem = words.joined(separator: " ")
        let meaningful = words.filter { !filler.contains($0) && Int($0) == nil }
        guard stem.count >= 4, !meaningful.isEmpty, !meaningful.allSatisfy(generic.contains) else { return nil }
        return stem
    }

    /// Rules 1-3: lowercase, drop version markers and dates, normalise separators.
    static func tokens(_ fileName: String) -> [String] {
        var text = ((fileName as NSString).deletingPathExtension).lowercased()
        for pattern in [
            #"\d{4}[-_.]\d{1,2}[-_.]\d{1,2}"#,          // 2026-11-16
            #"\d{1,2}[-_.]\d{1,2}[-_.]\d{4}"#,          // 16.11.2026
            #"(?<![\d.])\d{1,2}[.:]\d{2}([.:]\d{2})?(?![\d.])"#, // 10.42 (screenshot times)
            #"\(\d+\)"#,                                 // (1)
        ] {
            text = text.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
        text = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: #"[-_]\d+$"#, with: "", options: .regularExpression) // trailing -2 / _2
        let raw = text.split { $0 == " " || $0 == "_" || $0 == "-" || $0 == "." }.map(String.init)
        var out: [String] = []
        var index = 0
        while index < raw.count {
            let word = raw[index]
            if ["v", "ver", "version"].contains(word), index + 1 < raw.count, Int(raw[index + 1]) != nil {
                index += 2 // "v 3", "version 3"
                continue
            }
            if markers.contains(word) || word.range(of: #"^(v|ver|version)\d+$"#, options: .regularExpression) != nil {
                index += 1
                continue
            }
            out.append(word)
            index += 1
        }
        return out
    }

    /// The explicit version number in a name ("v5", "ver 3", "version 2"), used only to break date ties.
    public static func versionNumber(_ fileName: String) -> Int? {
        let text = ((fileName as NSString).deletingPathExtension).lowercased()
        guard let match = text.range(of: #"(?<![a-z])(v|ver|version)[\s_-]?\d+"#, options: .regularExpression) else { return nil }
        return Int(text[match].filter(\.isNumber))
    }
}
