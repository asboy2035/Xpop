//
//  OpenAIInterface.swift
//  Xpop
//
//  Created by Dongqi Shen on 2025/1/8.
//

import AppKit

public struct Message: Codable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public struct ChatRequest: Codable {
    let model: String
    let messages: [Message]
    let stream: Bool  // 添加 stream 字段

    static func create(
        messages: [Message], model: String, stream: Bool = false
    ) -> ChatRequest {
        return ChatRequest(model: model, messages: messages, stream: stream)
    }
}

public struct ChatResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
}

public struct Choice: Codable {
    let index: Int
    let message: Message
    let finishReason: String

    enum CodingKeys: String, CodingKey {
        case index
        case message
        case finishReason = "finish_reason"
    }
}

public struct StreamResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [StreamChoice]
}

public struct StreamChoice: Codable {
    let delta: Delta
    let finishReason: String?
    let index: Int

    enum CodingKeys: String, CodingKey {
        case delta
        case finishReason = "finish_reason"
        case index
    }
}

public struct Delta: Codable {
    let content: String?
    let role: String?
}

public enum OpenAIError: Error {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case noResponse
    case invalidAPIKey
    case streamError(String)  // 添加流式错误类型

    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .noResponse:
            return "No response from API"
        case .invalidAPIKey:
            return "Invalid API key"
        case .streamError(let message):
            return "Stream error: \(message)"
        }
    }
}

public class OpenAIChatClient {
    private let apiKey: String
    private let baseURL: String
    private let model: String

    /// 初始化函数，优先使用传入的 apiKey 和 baseURL 参数
    /// 如果参数为空，则使用默认的 ProviderManager 和 UserDefaults 配置
    public init(apiKey: String? = nil, baseURL: String? = nil) {
        if let providedApiKey = apiKey, let providedBaseURL = baseURL {
            self.apiKey = providedApiKey
            self.baseURL = providedBaseURL
        } else {
            let details = ProviderManager.shared.getSelectedProviderDetails()
            self.apiKey = details?.apiKey ?? ""
            self.baseURL = (details?.baseURL ?? "") + "/chat/completions"
        }
        self.model = UserDefaults.standard.string(forKey: "chosenModel") ?? ""
    }

    public func fetchChatCompletion(messages: [Message]) async throws -> String {
        guard !apiKey.isEmpty else {
            throw OpenAIError.invalidAPIKey
        }

        guard let url = URL(string: baseURL) else {
            throw OpenAIError.invalidURL
        }

        let request = ChatRequest.create(messages: messages, model: self.model, stream: false)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw OpenAIError.decodingError(error)
        }

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        // 检查 HTTP 响应状态码
        if let httpResponse = response as? HTTPURLResponse,
            !(200...299).contains(httpResponse.statusCode)
        {
            throw OpenAIError.networkError(NSError(domain: "", code: httpResponse.statusCode))
        }

        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)

        guard let result = chatResponse.choices.first?.message.content else {
            throw OpenAIError.noResponse
        }

        return result
    }

    public func streamChatCompletion(messages: [Message]) async throws -> AsyncStream<String> {
        guard !apiKey.isEmpty else {
            throw OpenAIError.invalidAPIKey
        }

        guard let url = URL(string: baseURL) else {
            throw OpenAIError.invalidURL
        }

        let request = ChatRequest.create(messages: messages,model: self.model, stream: true)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw OpenAIError.decodingError(error)
        }
        // 使用 AsyncStream.makeStream() 创建流
        var continuation: AsyncStream<String>.Continuation!
        let stream = AsyncStream<String> { _continuation in
            continuation = _continuation
        }

        // 在单独的 Task 中处理网络请求
        Task {
            do {
                let (result, response) = try await URLSession.shared.bytes(for: urlRequest)

                if let httpResponse = response as? HTTPURLResponse,
                    !(200...299).contains(httpResponse.statusCode)
                {
                    continuation.finish()
                    return
                }

                for try await line in result.lines {
                    if line.hasPrefix("data: ") {
                        let dataString = line.dropFirst(6)

                        if dataString == "[DONE]" {
                            break
                        }

                        guard let data = dataString.data(using: .utf8) else {
                            continuation.finish()
                            return
                        }

                        do {
                            let response = try JSONDecoder().decode(StreamResponse.self, from: data)
                            if let content = response.choices.first?.delta.content {
                                continuation.yield(content)
                            }
                        } catch {
                            continuation.finish()
                            return
                        }
                    }
                }
                continuation.finish()
            } catch {
                continuation.finish()
            }
        }
        return stream
    }
    
    public func performGetRequest() async throws -> Data {
        guard let requestURL = URL(string: baseURL) else {
            throw NSError(
                domain: "Invalid URL", code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "The provided URL is invalid."])
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "Invalid Response", code: 1002,
                userInfo: [NSLocalizedDescriptionKey: "Received an invalid response from the server."])
        }

        switch httpResponse.statusCode {
        case 200:
            return data
        case 401:
            throw handle401Error(data: data)
        case 403:
            throw NSError(
                domain: "Forbidden", code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Country, region, or territory not supported."])
        case 429:
            throw handle429Error(data: data)
        case 500:
            throw NSError(
                domain: "Internal Server Error", code: 500,
                userInfo: [
                    NSLocalizedDescriptionKey: "The server had an error while processing your request."
                ])
        case 503:
            throw NSError(
                domain: "Service Unavailable", code: 503,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "The engine is currently overloaded. Please try again later."
                ])
        default:
            throw NSError(
                domain: "HTTP Error", code: httpResponse.statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Unexpected HTTP status code: \(httpResponse.statusCode)."
                ])
        }
    }

    /// 专门处理 401 错误的辅助函数
    private func handle401Error(data: Data?) -> NSError {
        guard let data = data,
            let errorMessage = String(data: data, encoding: .utf8)
        else {
            return NSError(
                domain: "Unauthorized", code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Invalid Authentication."])
        }

        if errorMessage.contains("Invalid Authentication") {
            return NSError(
                domain: "Unauthorized", code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Invalid Authentication."])
        } else if errorMessage.contains("Incorrect API key provided") {
            return NSError(
                domain: "Unauthorized", code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Incorrect API key provided."])
        } else if errorMessage.contains("You must be a member of an organization to use the API") {
            return NSError(
                domain: "Unauthorized", code: 401,
                userInfo: [
                    NSLocalizedDescriptionKey: "You must be a member of an organization to use the API."
                ])
        } else {
            return NSError(
                domain: "Unauthorized", code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication error occurred."])
        }
    }

    /// 专门处理 429 错误的辅助函数
    private func handle429Error(data: Data?) -> NSError {
        guard let data = data,
            let errorMessage = String(data: data, encoding: .utf8)
        else {
            return NSError(
                domain: "Too Many Requests", code: 429,
                userInfo: [NSLocalizedDescriptionKey: "Rate limit reached for requests."])
        }

        if errorMessage.contains("Rate limit reached for requests") {
            return NSError(
                domain: "Too Many Requests", code: 429,
                userInfo: [NSLocalizedDescriptionKey: "Rate limit reached for requests."])
        } else if errorMessage.contains("You exceeded your current quota") {
            return NSError(
                domain: "Too Many Requests", code: 429,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "You exceeded your current quota. Please check your plan and billing details."
                ])
        } else {
            return NSError(
                domain: "Too Many Requests", code: 429,
                userInfo: [
                    NSLocalizedDescriptionKey: "Too many requests sent in a given amount of time."
                ])
        }
    }
    
}

public class OpenAIChatService {
    private let apiKey: String
    private let baseURL: String
    private let model: String
    private let systemPrompt: String
    private let chatClient: OpenAIChatClient

    public init(
        apiKey: String,
        baseURL: String,
        model: String = "qwen2-1.5b-instruct",
        systemPrompt: String
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model
        self.systemPrompt = systemPrompt
        self.chatClient = OpenAIChatClient()
    }

    // 非流式请求
    public func complete(_ query: String) async throws -> String {
        let messages = [
            Message(role: "system", content: systemPrompt),
            Message(role: "user", content: query),
        ]
        return try await chatClient.fetchChatCompletion(messages: messages)
    }

    // 流式请求
    public func streamComplete(_ query: String) async throws -> AsyncStream<String> {
        let messages = [
            Message(role: "system", content: systemPrompt),
            Message(role: "user", content: query),
        ]
        return try await chatClient.streamChatCompletion(messages: messages)
    }
}
