import Foundation

enum InferenceMode: String, CaseIterable, Identifiable {
    case local = "Modelos Locais (Ollama)"
    case api = "API na Nuvem (Google, OpenAI, etc)"
    
    var id: String { self.rawValue }
}

enum CloudProvider: String, CaseIterable, Identifiable {
    case google = "Google Gemini"
    case openai = "OpenAI (API Key)"
    case chatgptPlus = "ChatGPT Plus/Pro (No Key)"
    case anthropic = "Anthropic Claude"
    case custom = "Personalizado (Outros)"
    
    var id: String { self.rawValue }
    
    var defaultEndpoint: String {
        switch self {
        case .google:
            return "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
        case .openai, .chatgptPlus:
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
        case .openai, .chatgptPlus:
            return "https://api.openai.com/v1/models"
        case .anthropic:
            return "https://api.anthropic.com/v1/models"
        case .custom:
            return nil
        }
    }
    
    var availableModels: [String] {
        switch self {
        case .google:
            return [
                "gemini-2.0-flash",
                "gemini-2.0-flash-lite",
                "gemini-1.5-flash",
                "gemini-1.5-pro"
            ]
        case .openai:
            return [
                "gpt-4o",
                "gpt-4o-mini",
                "gpt-4.1",
                "gpt-4.1-mini",
                "gpt-4.1-nano",
                "o3",
                "o3-mini",
                "o4-mini",
                "chatgpt-4o-latest"
            ]
        case .chatgptPlus:
            return [
                "gpt-4o",
                "gpt-4o-mini",
                "gpt-4.1",
                "gpt-4.1-mini",
                "gpt-4.1-nano",
                "o3",
                "o3-mini",
                "o4-mini",
                "chatgpt-4o-latest"
            ]
        case .anthropic:
            return [
                "claude-sonnet-4-20250514",
                "claude-3-7-sonnet-20250219",
                "claude-3-5-haiku-20241022",
                "claude-3-opus-20240229"
            ]
        case .custom:
            return []
        }
    }
    
    var defaultModel: String {
        switch self {
        case .google: return "gemini-2.0-flash"
        case .openai: return "gpt-4o-mini"
        case .chatgptPlus: return "gpt-4o"
        case .anthropic: return "claude-sonnet-4-20250514"
        case .custom: return ""
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
    static var systemPrompt: String { UserDefaults.standard.string(forKey: "systemPrompt") ?? "Resposta direta. Pergunta: " }
    static var playNotifications: Bool { UserDefaults.standard.object(forKey: "playNotifications") as? Bool ?? true }
}
