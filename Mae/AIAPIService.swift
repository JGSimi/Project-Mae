import Foundation

class AIAPIService {
    static let shared = AIAPIService()
    private let session: URLSession
    private static let debugLogPath = "/Users/simi/Documents/Mae - Beta/.cursor/debug-45d8c6.log"
    private static let debugSessionId = "45d8c6"

    init(session: URLSession = .shared) {
        self.session = session
    }
    
    private static func debugLog(runId: String, hypothesisId: String, location: String, message: String, data: [String: Any]) {
        let payload: [String: Any] = [
            "sessionId": debugSessionId,
            "runId": runId,
            "hypothesisId": hypothesisId,
            "location": location,
            "message": message,
            "data": data,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]
        guard JSONSerialization.isValidJSONObject(payload),
              let json = try? JSONSerialization.data(withJSONObject: payload),
              let line = String(data: json, encoding: .utf8) else { return }
        let out = line + "\n"
        guard let fileData = out.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: debugLogPath) {
            guard let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: debugLogPath)) else { return }
            defer { try? handle.close() }
            do {
                try handle.seekToEnd()
                try handle.write(contentsOf: fileData)
            } catch {
                return
            }
        } else {
            try? fileData.write(to: URL(fileURLWithPath: debugLogPath), options: .atomic)
        }
    }

    func executeRequest(prompt: String, images: [String]?) async throws -> String {
        let inferenceMode = SettingsManager.inferenceMode
        #if DEBUG
        // #region agent log
        Self.debugLog(
            runId: "initial",
            hypothesisId: "H1",
            location: "AIAPIService.swift:executeRequest",
            message: "Entrada executeRequest",
            data: [
                "inferenceMode": String(describing: inferenceMode),
                "provider": String(describing: SettingsManager.selectedProvider),
                "model": SettingsManager.apiModelName,
                "imagesCount": images?.count ?? 0,
                "promptLength": prompt.count
            ]
        )
        // #endregion
        #endif
        if inferenceMode == .local {
            return try await executeLocalRequest(prompt: prompt, images: images)
        } else {
            return try await executeAPIRequest(prompt: prompt, images: images)
        }
    }

    private func executeLocalRequest(prompt: String, images: [String]?) async throws -> String {
        let payload = OllamaRequest(
            model: SettingsManager.localModelName,
            prompt: prompt,
            stream: false,
            images: images,
            options: ["temperature": 0.0]
        )

        guard let url = URL(string: "http://localhost:11434/api/generate") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (data, response) = try await session.data(for: request)
        #if DEBUG
        // #region agent log
        Self.debugLog(
            runId: "initial",
            hypothesisId: "H2",
            location: "AIAPIService.swift:executeLocalRequest",
            message: "Resposta local recebida",
            data: [
                "statusCode": (response as? HTTPURLResponse)?.statusCode ?? -1,
                "dataBytes": data.count
            ]
        )
        // #endregion
        #endif
        let result = try JSONDecoder().decode(OllamaResponse.self, from: data)
        return result.response.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func executeAPIRequest(prompt: String, images: [String]?) async throws -> String {
        guard let url = URL(string: SettingsManager.apiEndpoint) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let apiKey = SettingsManager.apiKey
        let isAnthropic = SettingsManager.selectedProvider == .anthropic
        #if DEBUG
        // #region agent log
        Self.debugLog(
            runId: "initial",
            hypothesisId: "H1",
            location: "AIAPIService.swift:executeAPIRequest",
            message: "Preflight request API",
            data: [
                "provider": String(describing: SettingsManager.selectedProvider),
                "isAnthropic": isAnthropic,
                "endpoint": SettingsManager.apiEndpoint,
                "apiKeyPresent": !apiKey.isEmpty,
                "imagesCount": images?.count ?? 0
            ]
        )
        // #endregion
        #endif
        
        if !apiKey.isEmpty {
            switch SettingsManager.selectedProvider {
            case .google, .openai, .custom:
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            case .anthropic:
                request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            }
        }
        
        if isAnthropic {
            var content: [AnthropicContent] = [AnthropicContent(type: "text", text: prompt, source: nil)]
            if let images = images {
                for img in images {
                    content.append(AnthropicContent(
                        type: "image",
                        text: nil,
                        source: AnthropicImageSource(type: "base64", media_type: "image/jpeg", data: img)
                    ))
                }
            }
            
            let payload = AnthropicRequest(
                model: SettingsManager.apiModelName,
                max_tokens: 4096,
                system: nil,
                messages: [AnthropicMessage(role: "user", content: content)],
                temperature: 0.0
            )
            
            request.httpBody = try JSONEncoder().encode(payload)
            
            let (data, response) = try await session.data(for: request)
            #if DEBUG
            // #region agent log
            Self.debugLog(
                runId: "initial",
                hypothesisId: "H3",
                location: "AIAPIService.swift:executeAPIRequest.anthropic",
                message: "Resposta HTTP Anthropic",
                data: [
                    "statusCode": (response as? HTTPURLResponse)?.statusCode ?? -1,
                    "dataBytes": data.count
                ]
            )
            // #endregion
            #endif
            if let httpRes = response as? HTTPURLResponse, !(200...299).contains(httpRes.statusCode) {
                let errorStr = String(data: data, encoding: .utf8) ?? "Unknown HTTP ERROR"
                throw NSError(domain: "AssistantAPIError", code: httpRes.statusCode, userInfo: [NSLocalizedDescriptionKey: "API Error: \(errorStr)"])
            }
            
            let result: AnthropicResponse
            do {
                result = try JSONDecoder().decode(AnthropicResponse.self, from: data)
            } catch {
                #if DEBUG
                // #region agent log
                Self.debugLog(
                    runId: "initial",
                    hypothesisId: "H5",
                    location: "AIAPIService.swift:executeAPIRequest.anthropic.decode",
                    message: "Falha decode AnthropicResponse",
                    data: [
                        "error": String(describing: error),
                        "dataPrefix": String(data: data.prefix(250), encoding: .utf8) ?? ""
                    ]
                )
                // #endregion
                #endif
                throw error
            }
            if let firstText = result.content.first(where: { $0.type == "text" }) {
                return firstText.text.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                throw NSError(domain: "AssistantError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No response from API."])
            }
        } else {
            var content: [MessageContent] = [.text(prompt)]
            if let images = images {
                for img in images {
                    content.append(.image(base64: img))
                }
            }
            
            let userMessage = APIMessage(role: "user", content: content)
            
            let modelName = SettingsManager.apiModelName
            let isOModel = modelName.hasPrefix("o1") || modelName.hasPrefix("o3")
            
            let payload = APIRequest(
                model: modelName,
                messages: [userMessage],
                temperature: isOModel ? nil : 0.0,
                max_tokens: 4096,
                stream: false
            )
            
            request.httpBody = try JSONEncoder().encode(payload)
            
            let (data, response) = try await session.data(for: request)
            #if DEBUG
            // #region agent log
            Self.debugLog(
                runId: "initial",
                hypothesisId: "H4",
                location: "AIAPIService.swift:executeAPIRequest.openaiLike",
                message: "Resposta HTTP OpenAI-like",
                data: [
                    "statusCode": (response as? HTTPURLResponse)?.statusCode ?? -1,
                    "isOModel": isOModel,
                    "modelName": modelName,
                    "dataBytes": data.count
                ]
            )
            // #endregion
            #endif
            if let httpRes = response as? HTTPURLResponse, !(200...299).contains(httpRes.statusCode) {
                let errorStr = String(data: data, encoding: .utf8) ?? "Unknown HTTP ERROR"
                throw NSError(domain: "AssistantAPIError", code: httpRes.statusCode, userInfo: [NSLocalizedDescriptionKey: "API Error: \(errorStr)"])
            }
            
            let result: APIResponse
            do {
                result = try JSONDecoder().decode(APIResponse.self, from: data)
            } catch {
                #if DEBUG
                // #region agent log
                Self.debugLog(
                    runId: "initial",
                    hypothesisId: "H5",
                    location: "AIAPIService.swift:executeAPIRequest.openaiLike.decode",
                    message: "Falha decode APIResponse",
                    data: [
                        "error": String(describing: error),
                        "dataPrefix": String(data: data.prefix(250), encoding: .utf8) ?? ""
                    ]
                )
                // #endregion
                #endif
                throw error
            }
            
            if let firstChoice = result.choices.first {
                return firstChoice.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                throw NSError(domain: "AssistantError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No response from API."])
            }
        }
    }
}
