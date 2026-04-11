import SwiftUI
import Combine

final class EditorStore: ObservableObject {
    @Published var editingSnippet: Snippet?
    /// Seeds the body when opening a new snippet editor (`editingSnippet == nil`). Reset when opening from the menu bar.
    @Published var pendingNewSnippetPrefill: String = ""
    /// Bumped whenever a new (unsaved) editor is opened so `SnippetEditorView` state is recreated with the latest prefill.
    @Published var newSnippetEditorSession: UInt = 0
}
