#if DEBUG
import FallbackCore
import SwiftUI

/// Development only: `Fallback.app/Contents/MacOS/Fallback --snapshot <folder>` draws each popover
/// state and the Ledger views into PNGs, using made-up sends in an in-memory database, then quits.
/// Used to compare the build with Design/screens without touching the real ledger.
@MainActor
enum Snapshots {
    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let flag = args.firstIndex(of: "--snapshot"), flag + 1 < args.count else { return false }
        let folder = URL(filePath: args[flag + 1])
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let popover = { (name: String, query: String, setup: (AppModel) -> Void) in
            let model = sampleModel()
            setup(model)
            render(PopoverView(query: query).environment(model), width: Theme.popoverWidth, to: folder.appending(path: "\(name).png"))
        }
        popover("01-normal", "") { _ in }
        popover("02-empty", "") { _ in } // replaced below with an empty model
        render(PopoverView().environment(try! AppModel(store: Store.inMemory())), width: Theme.popoverWidth,
               to: folder.appending(path: "02-empty.png"))
        popover("03-search", "razorpay") { _ in }
        popover("04-no-results", "globx") { _ in }
        popover("05-paused", "") { $0.pause(.oneHour) }
        popover("06-permission", "") { $0.debugSetTrusted(false) }

        let ledger = sampleModel()
        ledger.ledgerRoute = .allSends(selected: nil)
        render(LedgerView().environment(ledger), size: CGSize(width: 1390, height: 860), to: folder.appending(path: "07-ledger-all.png"))
        let byDestination = sampleModel()
        byDestination.ledgerRoute = .byDestination(selected: nil)
        render(LedgerView().environment(byDestination), size: CGSize(width: 1390, height: 860), to: folder.appending(path: "08-ledger-destination.png"))
        render(LedgerView().environment(ledger), size: CGSize(width: 1390, height: 860), to: folder.appending(path: "09-ledger-light.png"), dark: false)

        let size = CGSize(width: 1390, height: 860)
        let warnings = sampleModel()
        warnings.ledgerRoute = .warnings
        render(LedgerView().environment(warnings), size: size, to: folder.appending(path: "10-warnings.png"))
        let documents = sampleModel()
        documents.ledgerRoute = .byDocument(family: nil)
        render(LedgerView().environment(documents), size: size, to: folder.appending(path: "11-by-document.png"))
        let detail = sampleModel()
        let resumeFamily = (try? detail.store.families())?.first { $0.name == "Resume" }?.id
        detail.ledgerRoute = .byDocument(family: resumeFamily)
        render(LedgerView().environment(detail), size: size, to: folder.appending(path: "12-document-detail.png"))
        let empty = try! AppModel(store: Store.inMemory())
        empty.debugSet(suggestions: [], folders: ["/Users/arjun/Documents", "/Users/arjun/Desktop", "/Users/arjun/Downloads"])
        render(LedgerView().environment(empty), size: size, to: folder.appending(path: "13-ledger-empty.png"))
        let group = sampleModel()
        render(GroupSheet(fileIDs: group.suggestions.first ?? []).environment(group), width: 560, to: folder.appending(path: "14-group-sheet.png"))
        return true
    }

    /// Sends and files like the ones in Design/screens, at times relative to now.
    static func sampleModel() -> AppModel {
        let model = try! AppModel(store: Store.inMemory())
        let day = 86_400.0
        let samples: [(String, String, String, String, String?, String, Double)] = [
            ("Resume_v4.pdf", "com.google.Chrome", "Google Chrome", "https://www.naukri.com/job-listings-pm", "Product Manager - Naukri", "", 4 * day),
            ("Portfolio_2026.pdf", "com.google.Chrome", "Google Chrome", "https://www.linkedin.com/jobs/view/1", "Product Manager | LinkedIn | LinkedIn", "", 3.2 * day),
            ("Invoice_Nov_Acme.pdf", "com.apple.mail", "Mail", "", nil, "Invoice for November", 1.3 * day),
            ("Cover_Letter_Emergent.docx", "com.apple.Safari", "Safari", "https://jobs.lever.co/emergent/apply", "Emergent - Product Manager", "", 1.2 * day),
            ("Resume_v5.pdf", "com.apple.Safari", "Safari", "https://jobs.lever.co/emergent/apply", "Emergent - Product Manager", "", 1.19 * day),
            ("Resume_v3.pdf", "com.google.Chrome", "Google Chrome", "https://razorpay.wd3.myworkdayjobs.com/careers/job/pm", "Product Manager, Payments", "", 16 * day),
            ("Pitch Deck 2026.key", "net.whatsapp.WhatsApp", "WhatsApp", "", nil, "WhatsApp", 3000),
            ("Proposal_Globex.pdf", "com.tinyspeck.slackmacgap", "Slack", "", nil, "globex-deal (Channel) - acme - Slack", 1800),
            ("Resume_v5.pdf", "com.google.Chrome", "Google Chrome", "https://razorpay.wd3.myworkdayjobs.com/careers/job/pm", "Product Manager, Payments", "", 300),
        ]
        for (name, bundle, app, url, tab, window, ago) in samples {
            let link = url.isEmpty ? nil : url
            let title = tab ?? window
            let destination = model.resolver.resolve(url: link, title: title, appBundleID: bundle, appName: app)
            _ = try? model.store.record(NewSend(path: "/Users/arjun/Documents/\(name)", fileName: name,
                                                appBundleID: bundle, appName: app, url: link, pageTitle: title,
                                                method: .axPanel, sentAt: Date(timeIntervalSinceNow: -ago)),
                                        destination: destination,
                                        facts: FileFacts(sha256: "4f2a91c0b7d2e83f55aa10c4e9d7b3a1" + String(name.hashValue & 0xFFFF, radix: 16) + "9c1e",
                                                         sizeBytes: 188_416))
        }
        // Files with their fingerprints, so the FamilyEngine builds families like screens 08 and 09.
        let resume = (0..<60).map { "word\($0 % 37) skill\($0 % 11) role\($0)" }.joined(separator: " ")
        let proposal = (0..<40).map { "scope\($0 % 9) price\($0) timeline\($0 % 5)" }.joined(separator: " ")
        let files: [(String, String, Double, String?)] = [
            ("Resume.pdf", resume, 78 * day, nil), ("resume final (1).pdf", resume, 40 * day, nil),
            ("Resume_v3.pdf", resume, 18 * day, nil), ("Resume_v4.pdf", resume, 7 * day, nil), ("Resume_v5.pdf", resume, 1 * day, nil),
            ("Resume_Emergent.pdf", resume, 0.1 * day, nil), ("Resume_Razorpay_PM.pdf", resume, 18 * day, nil),
            ("Proposal_Globex.pdf", proposal, 2 * day, nil), ("Proposal_Globex.docx", proposal, 1 * day, nil),
            ("final.pdf", "", 5 * day, "Offer letter"), ("2.0.pdf", "", 5 * day, "Offer letter"),
        ]
        for (name, text, ago, title) in files {
            let date = Date(timeIntervalSinceNow: -ago)
            _ = try? model.store.upsert(IndexedFile(path: "/Users/arjun/Documents/\(name)", name: name,
                                                    facts: FileFacts(sha256: "sha-\(name)", sizeBytes: 180_000, modifiedAt: date),
                                                    createdAt: date, docTitle: title, docCreatedAt: title == nil ? nil : date,
                                                    textSignature: text.isEmpty ? nil : TextSignature.make(text)),
                                        inWatchedFolder: true)
        }
        let result = FamilyEngine.build(files: (try? model.store.evidence()) ?? [])
        try? model.store.apply(result)
        model.debugSet(suggestions: result.suggestions, folders: ["/Users/arjun/Documents", "/Users/arjun/Desktop", "/Users/arjun/Downloads"])
        return model
    }

    static func render<V: View>(_ view: V, width: CGFloat, to url: URL) {
        let host = NSHostingView(rootView: view)
        host.frame.size = CGSize(width: width, height: 10)
        settle()
        render(view, size: CGSize(width: width, height: host.fittingSize.height), to: url)
    }

    static func render<V: View>(_ view: V, size: CGSize, to url: URL, dark: Bool = true) {
        let host = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.backgroundColor = .black
        window.contentView = host
        host.frame = CGRect(origin: .zero, size: size)
        settle() // let .task blocks load their data
        host.layoutSubtreeIfNeeded()
        settle()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }

    private static func settle() { RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.4)) }
}
#endif
