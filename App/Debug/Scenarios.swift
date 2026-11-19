#if DEBUG
import FallbackCore
import SwiftUI

/// Development only: `Fallback --scenarios <folder>` runs PRD 14.3's warning scenarios against the real
/// files in ~/FallbackTest, in a temporary in-memory ledger, and draws each card to a PNG.
@MainActor
enum Scenarios {
    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let flag = args.firstIndex(of: "--scenarios"), flag + 1 < args.count else { return false }
        let out = URL(filePath: args[flag + 1])
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        var report: [String] = []
        let say = { (line: String) in report.append(line); print(line) }

        // 1. W1: upload v3 in Gmail.
        do {
            let run = try! Run()
            say("1. W1 · send resume_v3.pdf in Gmail")
            run.send("resume_v3.pdf", to: "https://mail.google.com/mail/u/0/#inbox?compose=new", title: "Inbox - Gmail", say: say, card: out, name: "1-w1")
            // 6. Save: pick v5 within 2 minutes of that card.
            say("6. Save · then send resume_v5.pdf within 2 minutes")
            run.send("resume_v5.pdf", to: "https://mail.google.com/mail/u/0/#inbox?compose=new", title: "Inbox - Gmail", say: say, card: out, name: "6-after")
            let saves = (try? run.store.warnings(outcome: "fixed")) ?? []
            say("   → saves counted: \(saves.count) (\(saves.first?.detail ?? "none"))")
        }
        // 2. W2: the same file to the same Greenhouse company twice.
        for sensitivity in [Sensitivity.balanced, .strict] {
            let run = try! Run(sensitivity: sensitivity)
            say("2. W2 · resume_v5.pdf to Greenhouse Northwind twice (\(sensitivity.rawValue))")
            run.send("resume_v5.pdf", to: "https://boards.greenhouse.io/northwind/jobs/1", title: "Apply", say: say, card: out, name: "2-first")
            run.send("resume_v5.pdf", to: "https://boards.greenhouse.io/northwind/jobs/1", title: "Apply", say: say, card: out, name: "2-w2-\(sensitivity.rawValue)")
        }
        // 3. W3: v3 to a company, then v5 to the same company.
        for sensitivity in [Sensitivity.balanced, .strict] {
            let run = try! Run(sensitivity: sensitivity)
            say("3. W3 · resume_v3.pdf then resume_v5.pdf to Lever Northwind (\(sensitivity.rawValue))")
            run.send("resume_v3.pdf", to: "https://jobs.lever.co/northwind/apply", title: "Apply", say: say, card: out, name: "3-first")
            run.send("resume_v5.pdf", to: "https://jobs.lever.co/northwind/apply", title: "Apply", say: say, card: out, name: "3-w3-\(sensitivity.rawValue)")
        }
        // 4. W4: send anything to Acme, then Proposal_Acme.pdf to another company.
        do {
            let run = try! Run()
            say("4. W4 · resume_v5.pdf to Acme, then Proposal_Acme.pdf to Globex")
            run.send("resume_v5.pdf", to: "https://boards.greenhouse.io/acme/jobs/2", title: "Apply", say: say, card: out, name: "4-first")
            run.send("Proposal_Acme.pdf", to: "https://jobs.lever.co/globex/apply", title: "Apply", say: say, card: out, name: "4-w4")
        }
        // 5. W5: the PDF was exported before the DOCX was edited.
        do {
            let run = try! Run()
            say("5. W5 · send Proposal_Acme.pdf")
            run.send("Proposal_Acme.pdf", to: "https://mail.google.com/mail/u/0/", title: "Inbox - Gmail", say: say, card: out, name: "5-w5")
        }
        // README's softer check: a tailored variant is never "older".
        do {
            let run = try! Run()
            say("+ Softer · send Resume_Razorpay.pdf")
            run.send("Resume_Razorpay.pdf", to: "https://jobs.ashbyhq.com/northwind/apply", title: "Apply", say: say, card: out, name: "7-softer")
        }
        // FR-37: a browser that gave no address. Asked once per window; never above a warning.
        do {
            let run = try! Run()
            say("+ FR-37 · resume_v5.pdf in a Chrome window with no address (\"Upload\"), twice")
            run.send("resume_v5.pdf", to: nil, title: "Upload - Google Chrome", say: say, card: out, name: "8-unknown")
            run.send("resume_v5.pdf", to: nil, title: "Upload - Google Chrome", say: say, card: out, name: "8-unknown-again")
            say("+ FR-37 · resume_v3.pdf in another unknown window")
            run.send("resume_v3.pdf", to: nil, title: "Attach a file - Google Chrome", say: say, card: out, name: "8-unknown-w1")
        }
        try? report.joined(separator: "\n").write(to: out.appending(path: "report.txt"), atomically: true, encoding: .utf8)
        return true
    }

    /// A temporary ledger with ~/FallbackTest indexed and grouped, as the app would have it.
    @MainActor final class Run {
        let store: Store
        let resolver: DestinationResolver
        let folder = NSString(string: "~/FallbackTest").expandingTildeInPath
        var lastCard: (id: Int64, family: Int64?, file: Int64?, at: Date)?

        init(sensitivity: Sensitivity = .balanced) throws {
            store = try Store.inMemory()
            resolver = try DestinationResolver(json: Data(contentsOf: Bundle.main.url(forResource: "destinations", withExtension: "json")!))
            try store.setSetting("sensitivity", sensitivity.rawValue)
            let analyzer = FileAnalyzer(readPDF: PDFContents.read)
            let rules = IndexRules()
            for name in try FileManager.default.contentsOfDirectory(atPath: folder) {
                let path = (folder as NSString).appendingPathComponent(name)
                let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.int64Value
                if rules.indexes(name: name, sizeBytes: size) { try store.upsert(analyzer.analyze(path: path), inWatchedFolder: true) }
            }
            try regroup()
        }

        func regroup() throws {
            try store.apply(FamilyEngine.build(files: store.evidence(), decisions: store.userDecisions(),
                                               knownOrganisations: Set(store.destinations().map(\.label))))
        }

        /// Records a send like the app does after a pick, then runs the warnings exactly as the app does.
        func send(_ name: String, to url: String?, title: String, say: (String) -> Void, card folder: URL, name pngName: String) {
            let path = (self.folder as NSString).appendingPathComponent(name)
            let destination = resolver.resolve(url: url, title: title, appBundleID: "com.google.Chrome", appName: "Google Chrome")
            guard let sendID = try? store.record(NewSend(path: path, fileName: name, appBundleID: "com.google.Chrome", appName: "Google Chrome",
                                                         url: url, pageTitle: title, method: .axPanel),
                                                 destination: destination, file: FileAnalyzer(readPDF: PDFContents.read).analyze(path: path),
                                                 inWatchedFolder: true) else { return say("   ✗ couldn't record") }
            try? regroup()
            if let last = lastCard, let pick = try? store.familyAndFile(ofSend: sendID),
               WarningEngine.isSave(card: (last.family, last.file, last.at), pick: (pick.family, pick.file, Date())) {
                try? store.setOutcome(warning: last.id, "fixed", detail: "Picked \(pick.name) \(Int(Date().timeIntervalSince(last.at))) s later")
                lastCard = nil
            }
            guard let input = try? store.warningInput(forSend: sendID) else { return say("   ✗ no input") }
            let result = WarningEngine.evaluate(input)
            let cardID = try? store.record(result, forSend: sendID, familyID: input.familyID, fileID: input.fileID, sensitivity: input.sensitivity)
            let fired = result.fired.map(\.rule.rawValue).joined(separator: ", ")
            say("   \(name) → \(destination.label): fired [\(fired.isEmpty ? "none" : fired)], card: \(result.card?.rule.rawValue ?? "none")")
            if let card = result.card, let cardID {
                lastCard = (cardID, input.familyID, input.fileID, Date())
                if card.rule == .unknownDestination { try? store.markLabelAsked(destination: input.destinationID) }
                let content = WarningCardContent(card, input: input, moreChecks: result.moreChecks, appName: "Chrome")
                Snapshots.render(WarningCardView(content: content, onPrimary: {}, onSecondary: {}, onMute: {}, onMore: {},
                                                 onClose: {}, onTimeout: {}),
                                 width: 372, to: folder.appending(path: "\(pngName).png"))
            }
        }
    }
}
#endif
