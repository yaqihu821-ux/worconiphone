import Foundation
import Combine

@MainActor
final class ConversationStore: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var selectedConversationID: UUID?
    @Published var isGenerating = false
    @Published var streamingReply = ""
    @Published var generationError: String?
    @Published var connectionMessage = "本机开发后端尚未检查"
    private(set) var streamingMessageID = UUID()
    private var activeRequestID: UUID?
    private var generationTask: Task<Void, Never>?

    var selectedConversation: Conversation? {
        conversations.first { $0.id == selectedConversationID }
    }

    init() {
        load()
        if selectedConversationID == nil {
            createConversation()
        }
    }

    func createConversation() {
        cancelGeneration()
        generationError = nil
        let conversation = Conversation()
        conversations.insert(conversation, at: 0)
        selectedConversationID = conversation.id
        persist()
    }

    func add(_ message: ChatMessage) {
        guard let selectedConversationID else { return }
        add(message, to: selectedConversationID)
    }

    private func add(_ message: ChatMessage, to conversationID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        conversations[index].messages.append(message)
        conversations[index].updatedAt = .now
        if conversations[index].messages.filter({ $0.role == .user }).count == 1, message.role == .user {
            conversations[index].title = String(message.content.prefix(24))
        }
        conversations.sort { $0.updatedAt > $1.updatedAt }
        persist()
    }

    func deleteSelected() {
        cancelGeneration()
        guard let selectedConversationID else { return }
        conversations.removeAll { $0.id == selectedConversationID }
        self.selectedConversationID = conversations.first?.id
        if self.selectedConversationID == nil { createConversation() }
        persist()
    }

    func clearAll() {
        cancelGeneration()
        conversations = [Conversation()]
        selectedConversationID = conversations[0].id
        persist()
    }

    func send(_ text: String, model: String, backendURL: String) {
        guard !isGenerating, let conversationID = selectedConversationID,
              let currentConversation = selectedConversation,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        generationError = nil
        streamingReply = ""
        let userMessage = ChatMessage(role: .user, content: text)
        add(userMessage, to: conversationID)
        var conversation = currentConversation
        conversation.messages.append(userMessage)
        conversation.updatedAt = .now
        runModel(for: conversationID, model: model, backendURL: backendURL, conversation: conversation)
    }

    func retryLast(model: String, backendURL: String) {
        guard !isGenerating, let conversationID = selectedConversationID,
              let conversation = conversations.first(where: { $0.id == conversationID }),
              conversation.messages.last?.role == .user else { return }
        generationError = nil
        streamingReply = ""
        runModel(for: conversationID, model: model, backendURL: backendURL, conversation: conversation)
    }

    func cancelGeneration() {
        activeRequestID = nil
        generationTask?.cancel()
        generationTask = nil
        if isGenerating { generationError = "回复已取消。可以重试。" }
        isGenerating = false
        streamingReply = ""
    }

    private func runModel(for conversationID: UUID, model: String, backendURL: String, conversation: Conversation) {
        let prompt = """
        你是 Worcon，一款 AI 情绪支持与自我理解助手。温和、坦诚、自然，不机械迎合或制造虚假亲密。先理解用户是在提问、倾诉、学习还是做决策，再选择回应方式。不要擅自推断动机，不把猜测说成事实，不诊断或指导用药。需要时鼓励用户联系可信任的人或专业人士。用中文回应时自然简洁。不要展示内部思维链；只给简短、可理解的解释。你不是临床医生，也不取代专业医疗服务。
        """
        var messages = [GroqClient.RequestMessage(role: "system", content: prompt)]
        messages += conversation.messages.suffix(24).map { message in
            GroqClient.RequestMessage(role: message.role.rawValue, content: message.content)
        }

        let requestID = UUID()
        activeRequestID = requestID
        streamingMessageID = UUID()
        isGenerating = true
        generationTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.activeRequestID == requestID {
                    self.isGenerating = false
                    self.generationTask = nil
                    self.activeRequestID = nil
                }
            }
            var sentenceBuffer = SentenceBuffer()
            do {
                try await GroqClient().stream(baseURL: backendURL, model: model, messages: messages) { [weak self] text in
                    guard let self, self.activeRequestID == requestID else { throw CancellationError() }
                    sentenceBuffer.append(text)
                    while let sentence = sentenceBuffer.next() {
                        try await self.presentSentence(sentence, requestID: requestID)
                    }
                }
                try Task.checkCancellation()
                guard activeRequestID == requestID else { throw CancellationError() }
                while let sentence = sentenceBuffer.next(flush: true) {
                    try await presentSentence(sentence, requestID: requestID)
                }
                guard !streamingReply.isEmpty else { throw GroqClient.ClientError.server("模型返回了空回复，请重试。") }
                add(ChatMessage(id: streamingMessageID, role: .assistant, content: streamingReply), to: conversationID)
                streamingReply = ""
            } catch is CancellationError {
                // Cancellation is initiated from the explicit Stop action.
            } catch {
                if activeRequestID == requestID {
                    generationError = error.localizedDescription
                }
            }
        }
    }

    private func presentSentence(_ sentence: String, requestID: UUID) async throws {
        try Task.checkCancellation()
        guard activeRequestID == requestID else { throw CancellationError() }
        streamingReply += sentence
        // Pause after each received sentence, with extra breathing room at paragraphs.
        let delay = sentence.contains("\n") ? 850 : min(1000, max(400, sentence.count * 18))
        try await Task.sleep(for: .milliseconds(delay))
    }

    private var storageURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Worcon", isDirectory: true)
            .appendingPathComponent("conversations.json")
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        conversations = snapshot.conversations
        selectedConversationID = snapshot.selectedConversationID
    }

    private func persist() {
        do {
            let directory = storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(Snapshot(conversations: conversations, selectedConversationID: selectedConversationID))
            try data.write(to: storageURL, options: .atomic)
        } catch {
            connectionMessage = "本地记录保存失败：\(error.localizedDescription)"
        }
    }

    private struct Snapshot: Codable {
        var conversations: [Conversation]
        var selectedConversationID: UUID?
    }
}
