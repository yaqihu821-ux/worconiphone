import Foundation

enum MessageRole: String, Codable {
    case user
    case assistant
}

enum ExpressionTag: String, Codable {
    case none = "NONE"
}

struct ChatMessage: Identifiable, Codable, Equatable {
    var id: UUID
    var role: MessageRole
    var content: String
    var expression: ExpressionTag
    var createdAt: Date

    init(id: UUID = UUID(), role: MessageRole, content: String, expression: ExpressionTag = .none, createdAt: Date = .now) {
        self.id = id
        self.role = role
        self.content = content
        self.expression = expression
        self.createdAt = createdAt
    }
}

struct Conversation: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var messages: [ChatMessage]
    var updatedAt: Date

    init(id: UUID = UUID(), title: String = "新的对话", messages: [ChatMessage] = [], updatedAt: Date = .now) {
        self.id = id
        self.title = title
        self.messages = messages
        self.updatedAt = updatedAt
    }
}
