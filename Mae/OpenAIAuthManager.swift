import Foundation
import CryptoKit
import Network
import AppKit

actor OpenAIAuthManager {
    static let shared = OpenAIAuthManager()
    
    private let clientId = "app_EMoamEEZ73f0CkXaXp7hrann"
    private let redirectURI = "http://localhost:1455/auth/callback"
    private let authURL = "https://auth.openai.com/oauth/authorize"
    private let tokenURL = "https://auth.openai.com/oauth/token"
    
    private var currentAccessToken: String?
    private var currentRefreshToken: String?
    private var tokenExpirationDate: Date?
    
    private var isRefreshing = false
    private var pendingRequests = PreallocatedCircularBuffer<CheckedContinuation<String, Error>>(capacity: 1024)
    
    private var listener: NWListener?
    private var connection: NWConnection?
    private var authContinuation: CheckedContinuation<String, Error>?
    private var timeoutTask: Task<Void, Never>?
    
    // Status para UI — nonisolated para que a view possa ler sem bloquear o actor
    nonisolated(unsafe) private(set) var hasValidToken: Bool = false
    nonisolated(unsafe) private(set) var lastErrorMessage: String? = nil
    nonisolated(unsafe) private(set) var isConnecting: Bool = false
    
    private init() {}
    
    // MARK: - Token Management
    
    func getValidToken() async throws -> String {
        if let token = currentAccessToken, let exp = tokenExpirationDate, exp > Date() {
            // Se o token existe e tem mais de 5 minutos de validade garantida
            if exp.timeIntervalSinceNow > 300 {
                return token
            }
        }
        
        // Se já está atualizando/buscando, entra na fila circular buffer
        if isRefreshing {
            return try await withCheckedThrowingContinuation { continuation in
                let success = pendingRequests.enqueue(continuation)
                if !success {
                    continuation.resume(throwing: URLError(.cannotParseResponse)) // Overflow simulado
                }
            }
        }
        
        isRefreshing = true
        
        do {
            var token: String
            // Tenta usar o refresh token se houver
            if let refreshToken = currentRefreshToken {
                token = try await performRefreshToken(refreshToken)
            } else {
                // Senão, força o fluxo de login
                token = try await startLoginFlow()
            }
            
            self.currentAccessToken = token
            isRefreshing = false
            
            // Libera a fila
            let requestsToResume = pendingRequests.removeAll()
            for req in requestsToResume {
                req.resume(returning: token)
            }
            
            return token
            
        } catch {
            isRefreshing = false
            let requestsToFail = pendingRequests.removeAll()
            for req in requestsToFail {
                req.resume(throwing: error)
            }
            throw error
        }
    }
    
    func clearTokens() {
        currentAccessToken = nil
        currentRefreshToken = nil
        tokenExpirationDate = nil
        hasValidToken = false
        lastErrorMessage = nil
    }
    
    // UI Helper — nonisolated para leitura rápida sem aguardar o actor
    nonisolated func getStatus() -> (hasToken: Bool, lastError: String?, connecting: Bool) {
        return (hasValidToken, lastErrorMessage, isConnecting)
    }
    
    // MARK: - Login Flow
    
    private func startLoginFlow() async throws -> String {
        isConnecting = true
        defer { isConnecting = false }
        
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        let state = UUID().uuidString
        
        var urlComponents = URLComponents(string: authURL)!
        urlComponents.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: "openid profile email offline_access"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "id_token_add_organizations", value: "true"),
            URLQueryItem(name: "codex_cli_simplified_flow", value: "true"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "originator", value: "codex_cli_rs")
        ]
        
        guard let finalURL = urlComponents.url else {
            throw URLError(.badURL)
        }
        
        // Abre o link no navegador padrão
        DispatchQueue.main.async {
            NSWorkspace.shared.open(finalURL)
        }
        
        // Aguarda pelo callback via NWListener
        let code = try await waitForCallback()
        
        // Step 1: Exchange code for tokens (id_token + access_token + refresh_token)
        let tokens = try await exchangeCodeForTokens(code: code, codeVerifier: codeVerifier)
        
        // Salva refresh token para renovações futuras
        self.currentRefreshToken = tokens.refresh_token
        
        // Step 2: Exchange id_token for actual API Key
        let apiKey = try await obtainApiKey(idToken: tokens.id_token)
        return apiKey
    }
    
    // MARK: - Local Server Callback
    
    private func waitForCallback() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            self.authContinuation = continuation
            
            do {
                if listener != nil {
                    listener?.cancel()
                }
                
                let params = NWParameters.tcp
                let port = NWEndpoint.Port(integerLiteral: 1455)
                listener = try NWListener(using: params, on: port)
                
                listener?.stateUpdateHandler = { [weak self] state in
                    switch state {
                    case .failed(let error):
                        Task { await self?.failAuth(with: error) }
                    default:
                        break
                    }
                }
                
                listener?.newConnectionHandler = { [weak self] connection in
                    Task { await self?.handleConnection(connection) }
                }
                
                listener?.start(queue: .global())
                
                // Timeout de 2 minutos
                timeoutTask?.cancel()
                timeoutTask = Task {
                    try? await Task.sleep(nanoseconds: 120_000_000_000)
                    guard !Task.isCancelled else { return }
                    await self.failAuth(with: URLError(.timedOut))
                }
            } catch {
                continuation.resume(throwing: error)
                self.authContinuation = nil
                self.timeoutTask?.cancel()
                self.timeoutTask = nil
            }
        }
    }
    
    private func handleConnection(_ connection: NWConnection) {
        self.connection = connection
        connection.start(queue: .global())
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }
            
            if let error = error {
                Task { await self.failAuth(with: error) }
                return
            }
            
            if let data = content, let requestString = String(data: data, encoding: .utf8) {
                Task { await self.processHttpRequest(requestString) }
            }
            
            // Responde e fecha a conexão
            let responseString = "HTTP/1.1 200 OK\r\nContent-Length: 57\r\nContent-Type: text/html\r\n\r\n<html><body><h2>Login successful. You can close this window.</h2><script>window.close()</script></body></html>"
            let responseData = responseString.data(using: .utf8)!
            
            connection.send(content: responseData, completion: .contentProcessed({ _ in
                connection.cancel()
            }))
        }
    }
    
    private func processHttpRequest(_ request: String) {
        // Ex: GET /auth/callback?code=ABC...&state=... HTTP/1.1
        guard let firstLine = request.components(separatedBy: "\n").first else { return }
        let components = firstLine.components(separatedBy: " ")
        guard components.count >= 2, components[0] == "GET" else { return }
        
        let path = components[1]
        guard let urlComponents = URLComponents(string: path),
              urlComponents.path == "/auth/callback",
              let queryItems = urlComponents.queryItems else { return }
        
        if let code = queryItems.first(where: { $0.name == "code" })?.value {
            authContinuation?.resume(returning: code)
            authContinuation = nil
            listener?.cancel()
            listener = nil
        }
    }
    
    private func failAuth(with error: Error) {
        authContinuation?.resume(throwing: error)
        authContinuation = nil
        listener?.cancel()
        listener = nil
    }
    
    // MARK: - Token Fetching
    
    // Step 1: Exchange authorization code for id_token + access_token + refresh_token
    private struct ExchangedTokens {
        let id_token: String
        let access_token: String
        let refresh_token: String
    }
    
    private func exchangeCodeForTokens(code: String, codeVerifier: String) async throws -> ExchangedTokens {
        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let body = [
            "grant_type=authorization_code",
            "code=\(code.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? code)",
            "redirect_uri=\(redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? redirectURI)",
            "client_id=\(clientId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? clientId)",
            "code_verifier=\(codeVerifier.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? codeVerifier)"
        ].joined(separator: "&")
        
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            self.lastErrorMessage = "Resposta de servidor inválida (token exchange)"
            throw URLError(.badServerResponse)
        }
        if !(200...299).contains(httpResponse.statusCode) {
            let errorStr = String(data: data, encoding: .utf8) ?? "Corpo de erro vazio"
            self.lastErrorMessage = "Token exchange HTTP \(httpResponse.statusCode): \(errorStr)"
            throw URLError(.badServerResponse)
        }
        
        struct InitialTokenResponse: Codable {
            let id_token: String
            let access_token: String
            let refresh_token: String
        }
        
        let tokens = try JSONDecoder().decode(InitialTokenResponse.self, from: data)
        return ExchangedTokens(
            id_token: tokens.id_token,
            access_token: tokens.access_token,
            refresh_token: tokens.refresh_token
        )
    }
    
    // Step 2: Exchange id_token for an actual OpenAI API Key
    private func obtainApiKey(idToken: String) async throws -> String {
        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let body = [
            "grant_type=\("urn:ietf:params:oauth:grant-type:token-exchange".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)",
            "client_id=\(clientId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)",
            "requested_token=openai-api-key",
            "subject_token=\(idToken.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)",
            "subject_token_type=\("urn:ietf:params:oauth:token-type:id_token".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)"
        ].joined(separator: "&")
        
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            self.lastErrorMessage = "Resposta inválida (API key exchange)"
            throw URLError(.badServerResponse)
        }
        if !(200...299).contains(httpResponse.statusCode) {
            let errorStr = String(data: data, encoding: .utf8) ?? "Corpo de erro vazio"
            self.lastErrorMessage = "API key exchange HTTP \(httpResponse.statusCode): \(errorStr)"
            throw URLError(.badServerResponse)
        }
        
        struct ApiKeyResponse: Codable {
            let access_token: String
        }
        
        let apiKeyResp = try JSONDecoder().decode(ApiKeyResponse.self, from: data)
        
        // Salva o API key e marca como válido
        self.currentAccessToken = apiKeyResp.access_token
        self.hasValidToken = true
        self.lastErrorMessage = nil
        
        // JWT expiration se aplicável
        if let expDate = JWTDecoder.decodeExpiration(jwtToken: apiKeyResp.access_token) {
            self.tokenExpirationDate = expDate.addingTimeInterval(-300)
        } else {
            self.tokenExpirationDate = Date().addingTimeInterval(3300) // ~1h fallback
        }
        
        return apiKeyResp.access_token
    }
    
    // Refresh: re-get tokens via refresh_token then exchange for new API key
    private func performRefreshToken(_ refreshToken: String) async throws -> String {
        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let refreshBody: [String: String] = [
            "client_id": clientId,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "scope": "openid profile email"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: refreshBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            self.lastErrorMessage = "Resposta inválida (refresh)"
            throw URLError(.badServerResponse)
        }
        if !(200...299).contains(httpResponse.statusCode) {
            let errorStr = String(data: data, encoding: .utf8) ?? "Corpo de erro vazio"
            self.lastErrorMessage = "Refresh HTTP \(httpResponse.statusCode): \(errorStr)"
            self.currentRefreshToken = nil // invalida o refresh token
            throw URLError(.badServerResponse)
        }
        
        struct RefreshResponse: Codable {
            let id_token: String?
            let access_token: String?
            let refresh_token: String?
        }
        
        let refreshResp = try JSONDecoder().decode(RefreshResponse.self, from: data)
        
        // Atualiza o refresh token se veio um novo
        if let newRefresh = refreshResp.refresh_token {
            self.currentRefreshToken = newRefresh
        }
        
        // Se veio id_token, troca por API key
        if let idToken = refreshResp.id_token {
            return try await obtainApiKey(idToken: idToken)
        }
        
        // Fallback: usa access_token direto
        if let accessToken = refreshResp.access_token {
            self.currentAccessToken = accessToken
            self.hasValidToken = true
            self.lastErrorMessage = nil
            return accessToken
        }
        
        self.lastErrorMessage = "Refresh não retornou tokens válidos"
        throw URLError(.badServerResponse)
    }
    
    // MARK: - Legacy fetchAndParseToken (unused, kept for reference)
    private func fetchAndParseToken(request: URLRequest) async throws -> String {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            self.lastErrorMessage = "Resposta de servidor inválida"
            clearTokens()
            throw URLError(.badServerResponse)
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let errorStr = String(data: data, encoding: .utf8) ?? "Corpo de erro vazio"
            self.lastErrorMessage = "Erro HTTP \(httpResponse.statusCode): \(errorStr)"
            clearTokens()
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        do {
            let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
            
            self.currentAccessToken = tokenResponse.access_token
            self.currentRefreshToken = tokenResponse.refresh_token
            self.hasValidToken = true
            self.lastErrorMessage = nil
            
            // Custom JWT Decoding para identificar tempo real de expiração
            if let expDate = JWTDecoder.decodeExpiration(jwtToken: tokenResponse.access_token) {
                // Antecipa em 5 minutos a renovação (margem de segurança)
                self.tokenExpirationDate = expDate.addingTimeInterval(-300)
            } else {
                // Fallback
                self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval((tokenResponse.expires_in ?? 3600) - 300))
            }
            
            return tokenResponse.access_token
        } catch {
            self.lastErrorMessage = "Erro decodificando token: \(error.localizedDescription)"
            clearTokens()
            throw error
        }
    }
    
    // MARK: - PKCE Helpers
    
    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64URLEncoded()
    }
    
    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .ascii) else { return "" }
        let hash = SHA256.hash(data: data)
        return Data(hash).base64URLEncoded()
    }
    
    // MARK: - Internal Models
    private struct TokenResponse: Codable {
        let access_token: String
        let refresh_token: String?
        let id_token: String?
        let expires_in: Int?
        let token_type: String?
    }

    struct PreallocatedCircularBuffer<T> {
        private var buffer: [T?]
        private var head: Int = 0
        private var tail: Int = 0
        private var count: Int = 0
        private let capacity: Int
        
        init(capacity: Int) {
            self.capacity = capacity
            self.buffer = [T?](repeating: nil, count: capacity)
        }
        
        mutating func enqueue(_ element: T) -> Bool {
            if count == capacity { return false } // Full
            buffer[head] = element
            head = (head + 1) % capacity
            count += 1
            return true
        }
        
        mutating func dequeue() -> T? {
            if count == 0 { return nil } // Empty
            let element = buffer[tail]
            buffer[tail] = nil
            tail = (tail + 1) % capacity
            count -= 1
            return element
        }
        
        mutating func removeAll() -> [T] {
            var elements = [T]()
            while let el = dequeue() {
                elements.append(el)
            }
            return elements
        }
    }

    private struct JWTDecoder {
        static func decodeExpiration(jwtToken: String) -> Date? {
            let segments = jwtToken.components(separatedBy: ".")
            guard segments.count > 1 else { return nil }
            
            var base64String = segments[1]
            let requiredLength = (4 - base64String.count % 4) % 4
            base64String.append(String(repeating: "=", count: requiredLength))
            
            let safeBase64 = base64String
                .replacingOccurrences(of: "-", with: "+")
                .replacingOccurrences(of: "_", with: "/")
            
            guard let data = Data(base64Encoded: safeBase64),
                  let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let exp = json["exp"] as? TimeInterval else {
                return nil
            }
            
            return Date(timeIntervalSince1970: exp)
        }
    }
}

// MARK: - Extension

extension Data {
    func base64URLEncoded() -> String {
        self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
