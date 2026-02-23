import Foundation

// MARK: - Ollama Models
struct OllamaRequest: Codable {
    let model: String
    let prompt: String
    let stream: Bool
    let images: [String]?
    let options: [String: Double]
}

struct OllamaResponse: Decodable {
    let response: String
}

// MARK: - API Models (OpenAI Compatible)
struct APIRequest: Codable {
    let model: String
    let messages: [APIMessage]
    let temperature: Double
    let stream: Bool
    let max_tokens: Int?
}

struct APIMessage: Codable {
    let role: String
    let textContent: String?
    let arrayContent: [MessageContent]?
    
    init(role: String, content: String) {
        self.role = role
        self.textContent = content
        self.arrayContent = nil
    }
    
    init(role: String, content: [MessageContent]) {
        self.role = role
        self.textContent = nil
        self.arrayContent = content
    }
    
    enum CodingKeys: String, CodingKey {
        case role, content
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        if let textContent = textContent {
            try container.encode(textContent, forKey: .content)
        } else if let arrayContent = arrayContent {
            try container.encode(arrayContent, forKey: .content)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.role = try container.decode(String.self, forKey: .role)
        if let text = try? container.decode(String.self, forKey: .content) {
            self.textContent = text
            self.arrayContent = nil
        } else if let array = try? container.decode([MessageContent].self, forKey: .content) {
            self.arrayContent = array
            self.textContent = nil
        } else {
            self.textContent = nil
            self.arrayContent = nil
        }
    }
}

struct MessageContent: Codable {
    let type: String
    let text: String?
    let image_url: ImageURL?
    
    struct ImageURL: Codable {
        let url: String
    }
    
    static func text(_ text: String) -> MessageContent {
        return MessageContent(type: "text", text: text, image_url: nil)
    }
    
    static func image(base64: String) -> MessageContent {
        return MessageContent(type: "image_url", text: nil, image_url: ImageURL(url: "data:image/png;base64,\(base64)"))
    }
}

struct APIResponse: Decodable {
    let choices: [Choice]
    
    struct Choice: Decodable {
        let message: ResponseMessage
    }
    
    struct ResponseMessage: Decodable {
        let content: String
    }
}

// MARK: - API Model Fetching
struct APIModelListResponse: Decodable {
    let data: [APIModelItem]
}

struct APIModelItem: Decodable, Identifiable {
    let id: String
}
