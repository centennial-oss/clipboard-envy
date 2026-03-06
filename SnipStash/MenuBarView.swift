import SwiftUI
import SwiftData
import AppKit

struct MenuBarView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var editorStore: EditorStore
    @EnvironmentObject private var snippetsStore: SnippetsStore
    @AppStorage("muteQuickSaveSounds") private var muteSounds = false

    private var snippets: [Snippet] { snippetsStore.snippets }

    var body: some View {
        Button("New Snippet") {
            editorStore.editingSnippet = nil
            openWindow(id: "editor")
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        Button("Quick Save From Clipboard", action: quickSaveFromClipboard)
        Divider()
        if snippets.isEmpty {
            Text("No snippets yet")
        } else {
            ForEach(snippets) { snippet in
                Menu(snippetMenuTitle(for: snippet)) {
                    Button("Copy to Clipboard") { copyToClipboard(snippet) }
                    if hasURL(snippet.body) {
                        Button("Open URL") { openURL(from: snippet.body) }
                    }
                    Button("Edit") {
                        editorStore.editingSnippet = snippet
                        openWindow(id: "editor")
                        DispatchQueue.main.async {
                            NSApp.activate(ignoringOtherApps: true)
                        }
                    }
                    Button(role: .destructive) { confirmAndDelete(snippet) } label: {
                        Text("Delete")
                    }
                    Divider()
                    Button("Move Up") { moveUp(snippet) }
                        .disabled(snippets.first?.id == snippet.id)
                    Button("Move Down") { moveDown(snippet) }
                        .disabled(snippets.last?.id == snippet.id)
                }
            }
        }
        Divider()
        Toggle("Mute Sounds", isOn: $muteSounds)
        Button("About SnipStash") {
            openWindow(id: "about")
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                if let w = NSApp.windows.first(where: { $0.title == "About SnipStash" }) {
                    if w.isMiniaturized {
                        w.deminiaturize(nil)
                    }
                    w.makeKeyAndOrderFront(nil)
                }
            }
        }
        Button("Quit SnipStash") {
            NSApp.terminate(nil)
        }
        .onAppear {
            snippetsStore.refresh()
        }
    }

    // MARK: - Actions

    private func quickSaveFromClipboard() {
        if let str = NSPasteboard.general.string(forType: .string), !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let snippet = Snippet(body: str, timestamp: Date())
            modelContext.insert(snippet)
            snippetsStore.refresh()
            if !muteSounds {
                if let snd = NSSound(named: "Frog") {
                    snd.volume = 0.25
                    snd.play()
                }
            }
        } else {
            if !muteSounds {
                NSSound.beep()
            }
        }
    }

    private func confirmAndDelete(_ snippet: Snippet) {
        let modifiers: NSEvent.ModifierFlags = NSApp.currentEvent?.modifierFlags ?? []
        let bypassConfirmation = modifiers.contains(.option) || modifiers.contains(.shift)

        if bypassConfirmation {
            modelContext.delete(snippet)
            snippetsStore.refresh()
        } else {
            let alert = NSAlert()
            alert.messageText = "Delete this snippet?"
            alert.informativeText = "This will permanently delete: \(snippetMenuTitle(for: snippet))"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Delete")
            alert.addButton(withTitle: "Cancel")
            NSApp.activate(ignoringOtherApps: true)
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                modelContext.delete(snippet)
                snippetsStore.refresh()
            }
        }
    }

    private func copyToClipboard(_ snippet: Snippet) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snippet.body, forType: .string)
    }

    private func moveUp(_ snippet: Snippet) {
        guard let idx = snippets.firstIndex(where: { $0.id == snippet.id }), idx > 0 else { return }
        let above = snippets[idx - 1]
        swapTimestamps(between: snippet, and: above)
        snippetsStore.refresh()
    }

    private func moveDown(_ snippet: Snippet) {
        guard let idx = snippets.firstIndex(where: { $0.id == snippet.id }), idx < snippets.count - 1 else { return }
        let below = snippets[idx + 1]
        swapTimestamps(between: snippet, and: below)
        snippetsStore.refresh()
    }

    private func swapTimestamps(between a: Snippet, and b: Snippet) {
        let temp = a.timestamp
        a.timestamp = b.timestamp
        b.timestamp = temp
        try? modelContext.save()
    }

    private func snippetMenuTitle(for snippet: Snippet) -> String {
        if let t = snippet.title, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return truncated(normalizedForMenu(t), limit: 40)
        }
        return truncated(normalizedForMenu(snippet.body), limit: 40)
    }

    private func hasURL(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")
    }

    private func openURL(from text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
        guard let url = URL(string: firstLine) else { return }
        NSWorkspace.shared.open(url)
    }

    private func normalizedForMenu(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private func truncated(_ text: String, limit: Int) -> String {
        if text.count <= limit { return text }
        let idx = text.index(text.startIndex, offsetBy: limit)
        return String(text[..<idx]) + "…"
    }
}

#Preview {
    let container = try! ModelContainer(for: Snippet.self, configurations: .init(isStoredInMemoryOnly: true))
    MenuBarView()
        .environmentObject(EditorStore())
        .environmentObject(SnippetsStore(container: container))
        .modelContainer(container)
}
