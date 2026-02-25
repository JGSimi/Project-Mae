import Foundation

class ModelFetcher {
    static let shared = ModelFetcher()
    
    private init() {}
    
    /// Bate no endpoint `/v1/models` dos provedores compatíveis e retorna a lista de IDs de modelos disponíveis para a chave atual.
    func fetchModels(for provider: CloudProvider, apiKey: String) async throws -> [String] {
        guard let endpointString = provider.modelsEndpoint,
              let url = URL(string: endpointString) else {
            // Se o provedor não suporta a busca dinâmica ou não tem endpoint, retorna fallback vazio.
            return []
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if !apiKey.isEmpty || provider == .chatgptPlus {
            switch provider {
            case .chatgptPlus:
                // Intercepta e usa o token JWT
                let jwtToken = try await OpenAIAuthManager.shared.getValidToken()
                request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
            case .openai, .google, .custom:
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            case .anthropic:
                request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            }
        }
        
        // Timeout curto para não prender a interface se a rede estiver ruim
        request.timeoutInterval = 10
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decodedResponse = try JSONDecoder().decode(APIModelListResponse.self, from: data)
        let modelIds = decodedResponse.data.map { $0.id }
        
        // Filtra possíveis sufixos vazios e ordena
        return modelIds.filter { !$0.isEmpty }.sorted()
    }
}
