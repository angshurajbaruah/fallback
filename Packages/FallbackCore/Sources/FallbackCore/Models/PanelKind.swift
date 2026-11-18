/// Whether a file panel is for picking files (watched) or saving them (ignored, FR-1).
public enum PanelKind: Sendable, Equatable {
    case open, save

    /// Decided from the panel's default button. Anything not save-like counts as open,
    /// so "Open", "Choose File", "Upload" and unfamiliar wording are all watched.
    public init(defaultButtonTitle: String) {
        let title = defaultButtonTitle.lowercased()
        let saveWords = ["save", "export", "move", "replace"]
        self = saveWords.contains { title.hasPrefix($0) } ? .save : .open
    }
}
