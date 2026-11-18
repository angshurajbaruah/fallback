import Foundation

/// Where a send went: a stable key plus the label the user sees (PRD 9.5, FR-5).
public struct Destination: Sendable, Equatable {
    public enum Source: String, Sendable { case rule, user, fallback }
    public var key: String
    public var label: String
    public var source: Source

    public init(key: String, label: String, source: Source) {
        self.key = key; self.label = label; self.source = source
    }
}

/// Turns a URL, tab or window title and app into a Destination, using Resources/destinations.json.
public struct DestinationResolver: Sendable {
    struct Rules: Decodable {
        var web: [Rule]
        var apps: [AppRule]
        var multiPartSuffixes: [String]
    }

    /// Regexes may capture `(?<label>…)`; a rule applies when every regex it has matches, except
    /// `title`, which falls back to `fallback` when it doesn't match.
    struct Rule: Decodable {
        var id: String
        var host: String
        var path: String?
        var title: String?
        var fixed: String?
        var fallback: String?
        var titleCase: Bool?
    }

    struct AppRule: Decodable {
        var id: String
        var bundleIDs: [String]
        var title: String
        var labelPrefix: String?
    }

    private let rules: Rules

    public init(json: Data) throws {
        rules = try JSONDecoder().decode(Rules.self, from: json)
    }

    public func resolve(url: String?, title: String?, appBundleID: String, appName: String) -> Destination {
        if let url, let parsed = URL(string: url), let host = parsed.host()?.lowercased(), !host.isEmpty {
            return web(host: host, path: parsed.path(), title: title ?? "") ?? domain(host)
        }
        if let title, let found = app(bundleID: appBundleID, title: title) { return found }
        return Destination(key: "app:\(appBundleID)", label: appName, source: .fallback)
    }

    private func web(host: String, path: String, title: String) -> Destination? {
        for rule in rules.web {
            guard let hostMatch = Self.match(rule.host, host) else { continue }
            var label = hostMatch
            if let pathRegex = rule.path {
                guard let pathMatch = Self.match(pathRegex, path) else { continue }
                label = label ?? pathMatch
            }
            if let titleRegex = rule.title { label = label ?? Self.match(titleRegex, title) ?? nil }
            if let captured = label, !captured.isEmpty {
                let pretty = rule.titleCase == true ? Self.titleCased(captured) : captured
                return Destination(key: "\(rule.id):\(captured.lowercased())", label: pretty, source: .rule)
            }
            if let fixed = rule.fixed ?? rule.fallback {
                return Destination(key: rule.id, label: fixed, source: .rule)
            }
        }
        return nil
    }

    private func app(bundleID: String, title: String) -> Destination? {
        for rule in rules.apps where rule.bundleIDs.contains(bundleID) {
            guard let captured = Self.match(rule.title, title) ?? nil else { continue }
            let label = (rule.labelPrefix ?? "") + captured
            let scope = Self.capture(rule.title, title, group: "scope").map { "\($0.lowercased())/" } ?? ""
            return Destination(key: "\(rule.id):\(scope)\(label.lowercased())", label: label, source: .rule)
        }
        return nil
    }

    /// Main domain: careers.acme.co.in → acme.co.in.
    // shortcut: a short list of multi-part suffixes, not the full Public Suffix List; switch to the full list if a real site resolves wrongly.
    private func domain(_ host: String) -> Destination {
        let parts = host.split(separator: ".").map(String.init)
        let lastTwo = parts.suffix(2).joined(separator: ".")
        let keep = rules.multiPartSuffixes.contains(lastTwo) ? 3 : 2
        let main = parts.suffix(keep).joined(separator: ".")
        return Destination(key: "domain:\(main)", label: main, source: .fallback)
    }

    /// nil when the regex doesn't match; .some(nil) when it matches without a label group.
    private static func match(_ pattern: String, _ text: String) -> String?? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let result = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        guard regex.pattern.contains("(?<label>"), let range = Range(result.range(withName: "label"), in: text) else { return .some(nil) }
        return .some(String(text[range]).trimmingCharacters(in: .whitespaces))
    }

    private static func capture(_ pattern: String, _ text: String, group: String) -> String? {
        guard pattern.contains("(?<\(group)>"),
              let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let result = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(result.range(withName: group), in: text) else { return nil }
        return String(text[range])
    }

    /// razorpay → Razorpay, acme-corp → Acme Corp.
    private static func titleCased(_ text: String) -> String {
        text.replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ").capitalized
    }
}
