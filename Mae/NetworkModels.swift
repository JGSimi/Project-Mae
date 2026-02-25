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
    let temperature: Double?
    let max_tokens: Int?
    let stream: Bool
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

// MARK: - Anthropic Models
struct AnthropicRequest: Codable {
    let model: String
    let max_tokens: Int
    let system: String?
    let messages: [AnthropicMessage]
    let temperature: Double
}

struct AnthropicMessage: Codable {
    let role: String
    let content: [AnthropicContent]
}

struct AnthropicContent: Codable {
    let type: String
    let text: String?
    let source: AnthropicImageSource?
}

struct AnthropicImageSource: Codable {
    let type: String
    let media_type: String
    let data: String
}

struct AnthropicResponse: Decodable {
    let content: [AnthropicResponseContent]
    
    struct AnthropicResponseContent: Decodable {
        let type: String
        let text: String
    }
}

// MARK: - API Model Fetching
struct APIModelListResponse: Decodable {
    let data: [APIModelItem]
}

struct APIModelItem: Decodable, Identifiable {
    let id: String
}

// MARK: - ChatGPT Backend-API Models (chatgpt.com/backend-api/conversation)

struct ChatGPTConversationRequest: Encodable {
    let action: String
    let messages: [ChatGPTMessage]
    let model: String
    let parent_message_id: String
    
    struct ChatGPTMessage: Encodable {
        let id: String
        let author: Author
        let content: Content
        
        struct Author: Encodable {
            let role: String
        }
        
        struct Content: Encodable {
            let content_type: String
            let parts: [ChatGPTPart]
        }
    }
    
    /// Helper to create a simple user text request
    static func userMessage(prompt: String, model: String, images: [String]? = nil) -> ChatGPTConversationRequest {
        var parts: [ChatGPTPart] = []
        
        // Add images first if present
        if let images = images {
            for base64 in images {
                parts.append(.imageAssetPointer(base64))
            }
        }
        
        // Add text prompt
        parts.append(.text(prompt))
        
        let contentType = (images != nil && !images!.isEmpty) ? "multimodal_text" : "text"
        
        let message = ChatGPTMessage(
            id: UUID().uuidString,
            author: ChatGPTMessage.Author(role: "user"),
            content: ChatGPTMessage.Content(
                content_type: contentType,
                parts: parts
            )
        )
        
        return ChatGPTConversationRequest(
            action: "next",
            messages: [message],
            model: model,
            parent_message_id: UUID().uuidString
        )
    }
}

/// A part in a ChatGPT message — can be text or an image
enum ChatGPTPart: Encodable {
    case text(String)
    case imageAssetPointer(String) // base64

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let str):
            try container.encode(str)
        case .imageAssetPointer(let base64):
            // ChatGPT backend-api expects inline image data in conversation
            try container.encode("data:image/jpeg;base64,\(base64)")
        }
    }
}

/// Response from chatgpt.com/backend-api/conversation (streamed SSE)
/// Each line is `data: {...}` with a message object
struct ChatGPTConversationResponse: Decodable {
    let message: ChatGPTResponseMessage?
    let is_completion: Bool?
    
    struct ChatGPTResponseMessage: Decodable {
        let id: String?
        let author: Author?
        let content: Content?
        let status: String?
        
        struct Author: Decodable {
            let role: String
        }
        
        struct Content: Decodable {
            let content_type: String?
            let parts: [String]?
        }
    }
}

/// Models response from chatgpt.com/backend-api/models
struct ChatGPTModelsResponse: Decodable {
    let models: [ChatGPTModel]
    
    struct ChatGPTModel: Decodable {
        let slug: String
        let title: String?
    }
}
