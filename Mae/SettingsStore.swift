import Foundation

enum InferenceMode: String, CaseIterable, Identifiable {
    case local = "Modelos Locais (Ollama)"
    case api = "API na Nuvem (Google, OpenAI, etc)"
    
    var id: String { self.rawValue }
}

enum CloudProvider: String, CaseIterable, Identifiable {
    case google = "Google Gemini"
    case openai = "OpenAI ChatGPT"
    case anthropic = "Anthropic Claude"
    case custom = "Personalizado (Outros)"
    
    var id: String { self.rawValue }
    
    var defaultEndpoint: String {
        switch self {
        case .google:
            return "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
        case .openai:
            return "https://api.openai.com/v1/chat/completions"
        case .anthropic:
            return "https://api.anthropic.com/v1/messages" // Note: Anthropics format is different natively, but proxy endpoints exist. The user requested Anthropic so we add it conceptually.
        case .custom:
            return ""
        }
    }
    
    var modelsEndpoint: String? {
        switch self {
        case .google:
            return "https://generativelanguage.googleapis.com/v1beta/openai/models"
        case .openai:
            return "https://api.openai.com/v1/models"
        case .anthropic:
            return nil // Anthropic usually doesn't expose a standard /models endpoint in the same way, we rely on static fallbacks.
        case .custom:
            return nil
        }
    }
    
    var availableModels: [String] {
        switch self {
        case .google:
            return ["gemini-2.5-flash", "gemini-2.0-flash", "gemini-1.5-pro", "gemini-1.5-flash"]
        case .openai:
            return ["gpt-4o", "gpt-4o-mini", "o1-mini", "o3-mini"]
        case .anthropic:
            return ["claude-3-5-sonnet-20241022", "claude-3-7-sonnet-latest", "claude-3-5-haiku-latest", "claude-3-opus-latest"]
        case .custom:
            return []
        }
    }
}

struct SettingsManager {
    static var inferenceMode: InferenceMode {
        let val = UserDefaults.standard.string(forKey: "inferenceMode") ?? InferenceMode.local.rawValue
        return InferenceMode(rawValue: val) ?? .local
    }
    static var selectedProvider: CloudProvider {
        let val = UserDefaults.standard.string(forKey: "selectedProvider") ?? CloudProvider.google.rawValue
        return CloudProvider(rawValue: val) ?? .google
    }
    static var localModelName: String { UserDefaults.standard.string(forKey: "localModelName") ?? "gemma3:4b" }
    static var apiEndpoint: String { UserDefaults.standard.string(forKey: "apiEndpoint") ?? "https://api.openai.com/v1/chat/completions" }
    static var apiModelName: String { UserDefaults.standard.string(forKey: "apiModelName") ?? "gpt-4o-mini" }
    static var apiKey: String { KeychainManager.shared.loadKey() ?? "" }
    static var systemPrompt: String { UserDefaults.standard.string(forKey: "systemPrompt") ?? "Responda APENAS com a letra e o texto da alternativa. Sem introduções. Pergunta: " }
}
