import SwiftUI
import SwiftData

struct EditorWindowRoot: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var editorStore: EditorStore
    @EnvironmentObject private var snippetsStore: SnippetsStore

    var body: some View {
        if let snippet = editorStore.editingSnippet {
            SnippetEditorView(snippet: snippet) { body, title in
                snippet.body = body
                snippet.title = title
                snippetsStore.refresh()
                dismiss()
            } onCancel: {
                dismiss()
            }
            .id(snippet.id)
        } else {
            SnippetEditorView(snippet: nil) { body, title in
                let new = Snippet(body: body, title: title, timestamp: Date())
                modelContext.insert(new)
                snippetsStore.refresh()
                dismiss()
            } onCancel: {
                dismiss()
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: Snippet.self, configurations: .init(isStoredInMemoryOnly: true))
    EditorWindowRoot()
        .environmentObject(EditorStore())
        .environmentObject(SnippetsStore(container: container))
        .modelContainer(container)
}
