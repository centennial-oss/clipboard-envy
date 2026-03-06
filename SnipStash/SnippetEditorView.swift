import SwiftUI
import SwiftData

struct SnippetEditorView: View {
    let snippet: Snippet?
    let onSave: (String, String?) -> Void
    let onCancel: () -> Void

    @State private var text: String
    @State private var title: String
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case body, title
    }

    init(snippet: Snippet?, onSave: @escaping (String, String?) -> Void, onCancel: @escaping () -> Void) {
        self.snippet = snippet
        self.onSave = onSave
        self.onCancel = onCancel
        _text = State(initialValue: snippet?.body ?? "")
        _title = State(initialValue: snippet?.title ?? "")
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 14))
                .frame(maxWidth: .infinity)
                .focused($focusedField, equals: .title)
                .onKeyPress(.tab) {
                    // Both Tab and Shift+Tab from title go to body (the only other field)
                    focusedField = .body
                    return .handled
                }
            TextEditor(text: $text)
                .font(.system(size: 14))
                .frame(maxWidth: .infinity, minHeight: 400)
                .border(Color.secondary.opacity(0.3))
                .background(Color(NSColor.textBackgroundColor))
                .focused($focusedField, equals: .body)
                .onKeyPress(.tab) {
                    // Both Tab and Shift+Tab from body go to title (the only other field)
                    focusedField = .title
                    return .handled
                }
            HStack(spacing: 10) {
                Button("Cancel") { onCancel() }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .keyboardShortcut(.escape)
                Button("Save") {
                    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(text, trimmedTitle.isEmpty ? nil : trimmedTitle)
                }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 520)
        .onAppear {
            focusedField = .body
        }
    }
}

#Preview {
    SnippetEditorView(snippet: nil, onSave: { _, _ in }, onCancel: { })
        .modelContainer(for: Snippet.self, inMemory: true)
}
