import Foundation

struct GroqClient {
    struct RequestMessage: Encodable {
        let role: String
        let content: String
    }

    enum ClientError: LocalizedError {
        case invalidAddress
        case invalidResponse
        case insecureTokenDestination
        case server(String)

        var errorDescription: String? {
            switch self {
            case .invalidAddress: "请在设置里填写 Mac 后端地址。"
            case .invalidResponse: "后端返回了无法读取的响应。"
            case .insecureTokenDestination: "线上连接口令只能发送到 HTTPS 地址。请检查设置中的服务地址。"
            case .server(let message): message
            }
        }
    }

    func stream(baseURL: String, model: String, messages: [RequestMessage], onText: @escaping @MainActor (String) async throws -> Void) async throws {
        guard let base = URL(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(base.scheme?.lowercased() ?? ""),
              let url = URL(string: "/v1/chat/completions", relativeTo: base) else {
            throw ClientError.invalidAddress
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 150
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if let token = KeychainStore.readBackendToken(), !token.isEmpty {
            guard url.scheme?.lowercased() == "https" else { throw ClientError.insecureTokenDestination }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(Body(model: model, messages: messages))

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            var errorBody = ""
            for try await line in bytes.lines {
                errorBody += line
                if errorBody.count > 4_000 { break }
            }
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: Data(errorBody.utf8)))?.error
            if http.statusCode == 401 { throw ClientError.server("连接口令无效。请在设置中重新保存线上连接口令。") }
            throw ClientError.server(message ?? "后端连接失败（HTTP \(http.statusCode)）。")
        }

        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { return }
            guard let data = payload.data(using: .utf8),
                  let event = try? JSONDecoder().decode(StreamEvent.self, from: data) else { continue }
            if let text = event.text, !text.isEmpty { try await onText(text) }
        }
        throw ClientError.server("回复连接中断，请重试。")
    }

    private struct Body: Encodable {
        let model: String
        let messages: [RequestMessage]
    }

    private struct StreamEvent: Decodable { let text: String? }
    private struct ErrorBody: Decodable { let error: String? }
}

// Keeps sentence boundaries intact even when punctuation arrives in separate SSE events.
struct SentenceBuffer {
    private var pending = ""
    mutating func append(_ text: String) { pending += text }
    mutating func next(flush: Bool = false) -> String? {
        guard !pending.isEmpty else { return nil }
        let chars = Array(pending)
        var end: Int?
        for i in chars.indices {
            let c = chars[i]
            let terminal = "。！？!?；;\n".contains(c)
                || (c == "." && (i + 1 < chars.count ? chars[i + 1].isWhitespace : flush))
            if terminal {
                var boundary = i + 1
                while boundary < chars.count && "。！？!?\"”’）)]\n\r".contains(chars[boundary]) { boundary += 1 }
                // One event of lookahead keeps closing quotes and paragraph breaks together.
                if boundary == chars.count && !flush { return nil }
                end = boundary
                break
            }
            if i >= 119 && (c.isWhitespace || "，、,:：".contains(c)) || i >= 199 {
                end = i + 1
                break
            }
        }
        guard let count = end ?? (flush ? chars.count : nil) else { return nil }
        let result = String(chars.prefix(count))
        pending = String(chars.dropFirst(count))
        return result
    }
}
