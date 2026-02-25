import Foundation

class ModelFetcher {
    static let shared = ModelFetcher()
    
    private init() {}
    
    /// Fetches available models dynamically from the provider's models endpoint.
    func fetchModels(for provider: CloudProvider, apiKey: String) async throws -> [String] {
        guard let endpointString = provider.modelsEndpoint,
              let url = URL(string: endpointString) else {
            return []
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if !apiKey.isEmpty || provider == .chatgptPlus {
            switch provider {
            case .chatgptPlus:
                // Use OAuth token + ChatGPT-Account-ID
                let jwtToken = try await OpenAIAuthManager.shared.getValidToken()
                request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
                if let accountId = await OpenAIAuthManager.shared.getAccountId() {
                    request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-ID")
                }
            case .openai, .google, .custom:
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            case .anthropic:
                request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            }
        }
        
        request.timeoutInterval = 10
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        // ChatGPT backend-api/models returns a different format
        if provider == .chatgptPlus {
            return parseChatGPTModels(data: data)
        }
        
        // Standard OpenAI-compatible format
        let decodedResponse = try JSONDecoder().decode(APIModelListResponse.self, from: data)
        let modelIds = decodedResponse.data.map { $0.id }
        return modelIds.filter { !$0.isEmpty }.sorted()
    }
    
    /// Parse the ChatGPT backend-api/models response format
    private func parseChatGPTModels(data: Data) -> [String] {
        // Try the structured format first
        if let response = try? JSONDecoder().decode(ChatGPTModelsResponse.self, from: data) {
            return response.models.map { $0.slug }.filter { !$0.isEmpty }
        }
        
        // Fallback: try to parse as generic JSON and extract model slugs
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let models = json["models"] as? [[String: Any]] {
            return models.compactMap { $0["slug"] as? String }.filter { !$0.isEmpty }
        }
        
        // Last resort: try categories format
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let categories = json["categories"] as? [[String: Any]] {
            var slugs: [String] = []
            for category in categories {
                if let models = category["models"] as? [[String: Any]] {
                    slugs.append(contentsOf: models.compactMap { $0["slug"] as? String })
                }
            }
            return slugs.filter { !$0.isEmpty }
        }
        
        print("[ModelFetcher] Could not parse ChatGPT models response")
        return []
    }
}
