/// Sending apps watched by default (FR-3). Picks in any other app are ignored.
enum WatchedApps {
    static let safari = "com.apple.Safari"
    /// Chrome-based browsers that answer "URL of active tab of front window".
    static let chromium: Set<String> = [
        "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.canary",
        "com.brave.Browser", "com.microsoft.edgemac", "company.thebrowser.Browser", "com.vivaldi.Vivaldi",
    ]
    static let others: Set<String> = [
        "org.mozilla.firefox", "com.apple.mail", "com.microsoft.Outlook", "com.tinyspeck.slackmacgap",
        "net.whatsapp.WhatsApp", "desktop.WhatsApp", "ru.keepcoder.Telegram", "org.telegram.desktop",
        "com.microsoft.teams2", "com.hnc.Discord", "us.zoom.xos",
    ]

    static func contains(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return bundleID == safari || chromium.contains(bundleID) || others.contains(bundleID)
    }
}
