import Foundation
import SwiftData

@Model
final class Snippet {
    @Attribute(.unique) var id: UUID
    var body: String
    var title: String?
    var timestamp: Date

    init(id: UUID = UUID(), body: String, title: String? = nil, timestamp: Date = Date()) {
        self.id = id
        self.body = body
        self.title = title
        self.timestamp = timestamp
    }

    convenience init(body: String) {
        self.init(body: body, timestamp: Date())
    }
}
