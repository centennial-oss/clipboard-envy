import SwiftUI
import SwiftData
import Combine

final class SnippetsStore: ObservableObject {
    @Published var snippets: [Snippet] = []

    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s for SwiftData to finish loading
            refresh()
        }
    }

    @MainActor
    func refresh() {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Snippet>(
            sortBy: [SortDescriptor(\Snippet.timestamp, order: .forward)]
        )
        snippets = (try? context.fetch(descriptor)) ?? []
    }
}
