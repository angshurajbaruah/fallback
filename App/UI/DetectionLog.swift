import FallbackCore
import AppKit
import Observation
import os
import SwiftUI

/// In-memory log for the M1 detection spike. Nothing is written to disk.
@MainActor @Observable
final class DetectionLog {
    struct Entry: Identifiable {
        let id = UUID()
        let time = Date()
        let tag: String
        let text: String

        var line: String {
            "\(time.formatted(.verbatim("\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits)", timeZone: .current, calendar: .current)))  "
                + tag.padding(toLength: 11, withPad: " ", startingAt: 0) + text
        }
    }

    private(set) var entries: [Entry] = []
    private let logger = Logger(subsystem: "com.angshurajbaruah.fallback", category: "detection")

    func add(_ tag: String, _ text: String) {
        entries.append(Entry(tag: tag, text: text))
        if entries.count > 2000 { entries.removeFirst(entries.count - 2000) }
        logger.info("\(tag, privacy: .public) \(text, privacy: .private)")
        #if DEBUG
        Self.appendToFile(entries[entries.count - 1].line)
        #endif
    }

    #if DEBUG
    /// Spike only: a copy on disk so results can be read without Copy Log. Never in release builds.
    static let fileURL = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Logs/Fallback/detection-debug.log")

    private static func appendToFile(_ line: String) {
        let data = Data((line + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: fileURL)
        }
    }
    #endif

    var text: String { entries.map(\.line).joined(separator: "\n") }
}

/// Developer window for M1. Not a designed screen: plain system styling on purpose.
struct DetectionLogView: View {
    let log: DetectionLog
    @State private var trusted = AXIsProcessTrusted()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if trusted {
                    Label("\(SystemNames.accessibility) allowed. Watching for file panels.", systemImage: "checkmark.circle")
                } else {
                    Label("\(SystemNames.accessibility) not allowed yet. Fallback can't see file panels.", systemImage: "exclamationmark.triangle")
                    Button("Open Accessibility Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    }
                }
                Spacer()
                Button("Copy Log") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(log.text, forType: .string)
                }
                .disabled(log.entries.isEmpty)
            }
            .padding(10)
            Divider()
            if log.entries.isEmpty {
                Text("Waiting for a file-open panel in a watched app…")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List(log.entries) { entry in
                        Text(entry.line).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    }
                    .onChange(of: log.entries.count) { proxy.scrollTo(log.entries.last?.id, anchor: .bottom) }
                }
            }
        }
        .frame(minWidth: 760, minHeight: 420)
        .task {
            while !Task.isCancelled {
                trusted = AXIsProcessTrusted()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}
