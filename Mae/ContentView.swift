//
//  ContentView.swift
//  Mae
//
//  Created by Joao Simi on 19/02/26.
//

import SwiftUI
import AppKit
import UserNotifications
import Combine
import KeyboardShortcuts
import UniformTypeIdentifiers

// MARK: - Shortcut Name definition
extension KeyboardShortcuts.Name {
    static let processClipboard = Self("processClipboard", default: .init(.x, modifiers: [.command, .shift]))
    static let processScreen = Self("processScreen", default: .init(.z, modifiers: [.command, .shift]))
}



// MARK: - Models
enum MessageSource {
    case chat
    case screenAnalysis
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    var images: [NSImage]? = nil
    let isUser: Bool
    let source: MessageSource
    let timestamp = Date()
    
    init(content: String, images: [NSImage]? = nil, isUser: Bool, source: MessageSource = .chat) {
        self.content = content
        self.images = images
        self.isUser = isUser
        self.source = source
    }
}

// MARK: - Protocols for Testing
protocol PasteboardClient {
    func string(forType type: NSPasteboard.PasteboardType) -> String?
    func data(forType type: NSPasteboard.PasteboardType) -> Data?
    @discardableResult func clearContents() -> Int
    @discardableResult func copyString(_ string: String, forType type: NSPasteboard.PasteboardType) -> Bool
    func readObjects(forClasses classArray: [AnyClass], options searchOptions: [NSPasteboard.ReadingOptionKey: Any]?) -> [Any]?
}

extension NSPasteboard: PasteboardClient {
    @discardableResult
    func copyString(_ string: String, forType type: NSPasteboard.PasteboardType) -> Bool {
        self.declareTypes([type], owner: nil)
        return self.setString(string, forType: type)
    }
}

// MARK: - NSImage Extension
extension NSImage {
    func resizedAndCompressedBase64(maxDimension: CGFloat = 1024) -> String? {
        guard let tiffData = self.tiffRepresentation,
              let imageSource = CGImageSourceCreateWithData(tiffData as CFData, nil) else {
            return nil
        }
        
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }
        
        let newImage = NSImage(cgImage: cgImage, size: .zero)
        guard let compressedTiff = newImage.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: compressedTiff),
              let jpegData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
            return nil
        }
        
        return jpegData.base64EncodedString()
    }
}

// MARK: - ViewModel
@MainActor
class AssistantViewModel: ObservableObject {
    static let shared = AssistantViewModel()
    
    @Published var isProcessing = false
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var attachedImages: [NSImage] = []
    
    // Análise de Tela - Novas Propriedades
    @Published var isAnalyzingScreen = false
    @Published var analysisResult: String = ""
    @Published var analysisImage: NSImage? = nil
    
    private let pasteboard: PasteboardClient
    private let session: URLSession
    
    init(pasteboard: PasteboardClient = NSPasteboard.general, session: URLSession = .shared) {
        self.pasteboard = pasteboard
        self.session = session
    }
    
    /// Chamado pelo atalho global (Processa Clipboard)
    func processarIA() async {
        guard !isProcessing else { return }
        
        var textoClipboard = pasteboard.string(forType: .string) ?? ""
        var copiedImage: NSImage? = nil
        
        if let objects = pasteboard.readObjects(forClasses: [NSImage.self], options: nil),
           let image = objects.first as? NSImage {
            copiedImage = image
        }
        
        if copiedImage != nil {
            let lowercased = textoClipboard.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if lowercased.hasPrefix("data:image/") ||
               lowercased.hasPrefix("http://") ||
               lowercased.hasPrefix("https://") ||
               lowercased.hasPrefix("file://") {
                textoClipboard = ""
            }
        }

        guard !textoClipboard.isEmpty || copiedImage != nil else { return }

        await executeRequest(prompt: textoClipboard, rawImages: copiedImage != nil ? [copiedImage!] : nil)
    }

    /// Chamado pelo atalho global (Intelligent Screen Analysis)
    func processarScreen() async {
        guard !isAnalyzingScreen else { return }
        
        // Ativar o app e trazer para frente
        NSApp.activate(ignoringOtherApps: true)
        
        guard let screenImage = captureScreen() else {
            print("Failed to capture screen")
            return
        }

        // Abrir a nova janela de análise
        DispatchQueue.main.async {
            AnalysisWindowManager.shared.showWindow()
            self.analysisImage = screenImage
            self.analysisResult = ""
            self.isAnalyzingScreen = true
        }

        let defaultPrompt = "Analise o que está na minha tela e me ajude de forma proativa. Não me pergunte o que fazer, apenas forneça a análise ou ajuda diretamente com base no contexto (por exemplo, se for um currículo, dê dicas; se for código, analise bugs, etc). Por favor, use formatação Markdown em sua resposta para garantir uma boa legibilidade."
        
        await executeSilentRequest(prompt: defaultPrompt, rawImages: [screenImage])
    }
    
    private func executeSilentRequest(prompt: String, rawImages: [NSImage]?) async {
        defer { 
            DispatchQueue.main.async {
                self.isAnalyzingScreen = false
            }
        }

        let inferenceMode = SettingsManager.inferenceMode
        let systemPrompt = SettingsManager.systemPrompt
        let base64Images = rawImages?.compactMap { $0.resizedAndCompressedBase64() }
        
        do {
            let finalResponse: String
            if inferenceMode == .local {
                finalResponse = try await executeLocalRequest(prompt: systemPrompt + prompt, images: base64Images)
            } else {
                finalResponse = try await executeAPIRequest(prompt: systemPrompt + prompt, images: base64Images)
            }

            DispatchQueue.main.async {
                self.analysisResult = finalResponse
            }
            
            if SettingsManager.playNotifications {
                await sendNotification(text: "Análise de tela concluída!")
                NSSound(named: "Glass")?.play()
            }
            
        } catch {
            DispatchQueue.main.async {
                self.analysisResult = "Erro: \(error.localizedDescription)"
            }
            print("Error processing AI: \(error)")
        }
    }

    /// Transfere a análise atual para o chat principal
    func continueWithAnalysis(followUp: String? = nil) {
        guard !analysisResult.isEmpty else { return }
        
        let prompt = "📸 Análise de Tela"
        
        let userMsg = ChatMessage(content: prompt, images: analysisImage != nil ? [analysisImage!] : nil, isUser: true, source: .screenAnalysis)
        let assistantMsg = ChatMessage(content: analysisResult, images: nil, isUser: false, source: .screenAnalysis)
        
        messages.append(userMsg)
        messages.append(assistantMsg)
        
        // Se houver follow-up, enviar como nova mensagem
        if let followUp = followUp, !followUp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Task {
                await executeRequest(prompt: followUp, rawImages: nil)
            }
        }
        
        // Limpa a análise atual após transferir
        analysisResult = ""
        analysisImage = nil
    }
    
    private func captureScreen() -> NSImage? {
        // Obsolete in macOS 15.0: CGDisplayCreateImage(CGMainDisplayID())
        // Using screencapture CLI as a robust workaround that also triggers the permission prompt
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("png")
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-x", tempURL.path] // -x = no sound
        task.launch()
        task.waitUntilExit()
        
        let image = NSImage(contentsOf: tempURL)
        try? FileManager.default.removeItem(at: tempURL)
        return image
    }

    /// Chamado pela interface via TextField
    func sendManualMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let imagesToProcess = attachedImages
        
        guard !isProcessing && (!text.isEmpty || !imagesToProcess.isEmpty) else { return }
        
        inputText = ""
        attachedImages.removeAll()
        
        await executeRequest(prompt: text, rawImages: imagesToProcess.isEmpty ? nil : imagesToProcess)
    }

    private func executeRequest(prompt: String, rawImages: [NSImage]?) async {
        isProcessing = true
        defer { isProcessing = false }

        let inferenceMode = SettingsManager.inferenceMode
        let systemPrompt = SettingsManager.systemPrompt
        
        // Convert to Base64 for processing but store the raw `NSImage` locally
        let base64Images = rawImages?.compactMap { $0.resizedAndCompressedBase64() }
        
        // Adiciona a pergunta ao histórico
        let userMsg = ChatMessage(content: prompt, images: rawImages, isUser: true)
        messages.append(userMsg)

        do {
            let finalResponse: String
            
            if inferenceMode == .local {
                finalResponse = try await executeLocalRequest(prompt: systemPrompt + prompt, images: base64Images)
            } else {
                finalResponse = try await executeAPIRequest(prompt: systemPrompt + prompt, images: base64Images)
            }

            // Adiciona a resposta ao histórico
            let assistantMsg = ChatMessage(content: finalResponse, images: nil, isUser: false)
            messages.append(assistantMsg)

            // Update Clipboard and Notify
            pasteboard.clearContents()
            pasteboard.copyString(finalResponse, forType: .string)
            
            if SettingsManager.playNotifications {
                await sendNotification(text: finalResponse)
                NSSound(named: "Glass")?.play()
            }
            
        } catch {
            let errorMsg = ChatMessage(content: "Erro: \(error.localizedDescription)", images: nil, isUser: false)
            messages.append(errorMsg)
            print("Error processing AI: \(error)")
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
        
        let (data, _) = try await session.data(for: request)
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
            if let httpRes = response as? HTTPURLResponse, !(200...299).contains(httpRes.statusCode) {
                let errorStr = String(data: data, encoding: .utf8) ?? "Unknown HTTP ERROR"
                throw NSError(domain: "AssistantAPIError", code: httpRes.statusCode, userInfo: [NSLocalizedDescriptionKey: "API Error: \(errorStr)"])
            }
            
            let result = try JSONDecoder().decode(AnthropicResponse.self, from: data)
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
            if let httpRes = response as? HTTPURLResponse, !(200...299).contains(httpRes.statusCode) {
                let errorStr = String(data: data, encoding: .utf8) ?? "Unknown HTTP ERROR"
                throw NSError(domain: "AssistantAPIError", code: httpRes.statusCode, userInfo: [NSLocalizedDescriptionKey: "API Error: \(errorStr)"])
            }
            
            let result = try JSONDecoder().decode(APIResponse.self, from: data)
            
            if let firstChoice = result.choices.first {
                return firstChoice.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                throw NSError(domain: "AssistantError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No response from API."])
            }
        }
    }

    private func sendNotification(text: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Mãe"
        content.body = text
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        _ = try? await UNUserNotificationCenter.current().add(request)
    }

    func clearHistory() {
        messages.removeAll()
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    @State private var isHovered = false
    @State private var markdownHeight: CGFloat = 40

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 40) }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                // Context label for screen analysis messages
                if message.source == .screenAnalysis && message.isUser {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 10))
                        Text("Análise de Tela")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(Theme.Colors.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.Colors.accentSubtle)
                    .clipShape(Capsule())
                }
                
                if let images = message.images {
                    ForEach(images.indices, id: \.self) { index in
                        Image(nsImage: images[index])
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: .black.opacity(0.15), radius: 6)
                    }
                }
                
                if !message.content.isEmpty {
                    if message.isUser {
                        Text(.init(message.content))
                            .font(Theme.Typography.bodySmall)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .maeGlassBackground(cornerRadius: Theme.Metrics.radiusMedium)
                            .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                            .textSelection(.enabled)
                    } else {
                        AutoSizingMarkdownWebView(markdown: message.content, measuredHeight: $markdownHeight)
                            .frame(height: markdownHeight)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .maeSurfaceBackground(cornerRadius: Theme.Metrics.radiusMedium)
                            .shadow(color: Color.black.opacity(0.10), radius: 4, x: 0, y: 2)
                    }
                }
            }
            .scaleEffect(isHovered ? 1.005 : 1.0)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.25)) {
                    isHovered = hovering
                }
            }
            
            if !message.isUser { Spacer(minLength: 40) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

struct ContentView: View {
    @ObservedObject private var viewModel = AssistantViewModel.shared
    @Namespace private var bottomID
    @State private var showSettings = false
    @State private var isAppearing = false

    var body: some View {
        ZStack {
            chatView
                .opacity(showSettings ? 0.0 : 1.0)
                .offset(x: showSettings ? -20 : 0)
                // We keep chatView in the hierarchy so it doesn't have to be recreated
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showSettings)
                .zIndex(1)

            if showSettings {
                SettingsView()
                    .overlay(alignment: .topTrailing) {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showSettings = false
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.cormorantGaramond(size: 20))
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(6)
                                .background(Color.black.opacity(0.3).clipShape(Circle()))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 12)
                        .padding(.trailing, 16)
                        .help("Fechar Configurações")
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .frame(width: 450, height: 650)
        .scaleEffect(isAppearing ? 1.0 : 0.95)
        .opacity(isAppearing ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isAppearing = true
            }
        }
    }

    private var chatView: some View {
        VStack(spacing: 0) {
            // Header — minimal with gradient fade
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.Colors.accent)
                    Text("Mãe")
                        .font(Theme.Typography.heading)
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
                
                Spacer()
                
                HStack(spacing: 14) {
                    headerButton(icon: "macwindow.badge.plus", help: "Abrir Janela de Análise") {
                        AnalysisWindowManager.shared.showWindow()
                    }
                    headerButton(icon: "trash", help: "Limpar histórico") {
                        withAnimation { viewModel.clearHistory() }
                    }
                    headerButton(icon: "gearshape", help: "Configurações") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showSettings = true
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Theme.Colors.background)
            .overlay(
                LinearGradient(
                    colors: [Theme.Colors.border, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 1),
                alignment: .bottom
            )
            .zIndex(1)

            // Chat List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if viewModel.messages.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 32, weight: .light))
                                    .foregroundStyle(Theme.Colors.accent.opacity(0.4))
                                Text("Comece uma conversa")
                                    .font(Theme.Typography.bodyBold)
                                    .foregroundStyle(Theme.Colors.textMuted)
                                Text("Pergunte qualquer coisa à Mãe.")
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.textMuted.opacity(0.6))
                            }
                            .padding(.top, 120)
                            .frame(maxWidth: .infinity)
                        } else {
                            ForEach(viewModel.messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.8)
                                            .combined(with: .opacity)
                                            .combined(with: .move(edge: .bottom)),
                                        removal: .opacity
                                    ))
                            }
                        }
                        Color.clear.frame(height: 10).id(bottomID)
                    }
                    .padding(.vertical, 12)
                }
                .scrollContentBackground(.hidden)
                .background(Theme.Colors.background)
                .onChange(of: viewModel.messages.count) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        proxy.scrollTo(bottomID, anchor: .bottom)
                    }
                }
            }

            // Footer / Input Area
            VStack(spacing: 0) {
                // Attached Images Preview
                if !viewModel.attachedImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.attachedImages.indices, id: \.self) { index in
                                ZStack(alignment: .topTrailing) {
                                    Image(nsImage: viewModel.attachedImages[index])
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .shadow(radius: 2)
                                    
                                    Button {
                                        viewModel.attachedImages.remove(at: index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.white, .black.opacity(0.7))
                                    }
                                    .buttonStyle(.plain)
                                    .offset(x: 6, y: -6)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 6)
                    }
                }

                // Gradient divider instead of hard line
                LinearGradient(
                    colors: [.clear, Theme.Colors.border, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 1)
                
                HStack(alignment: .center, spacing: 12) {
                    Button {
                        let panel = NSOpenPanel()
                        panel.allowedContentTypes = [UTType.image]
                        panel.allowsMultipleSelection = true
                        if panel.runModal() == .OK {
                            for url in panel.urls {
                                if let image = NSImage(contentsOf: url) {
                                    viewModel.attachedImages.append(image)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 18, weight: .light))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("Anexar imagem")

                    TextField("Pergunte à Mãe...", text: $viewModel.inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(Theme.Typography.bodySmall)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(Theme.Colors.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusLarge, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Metrics.radiusLarge, style: .continuous)
                                .stroke(Theme.Colors.border, lineWidth: 1)
                        )
                        .lineLimit(1...6)
                        .onSubmit {
                            Task { await viewModel.sendManualMessage() }
                        }
                        .disabled(viewModel.isProcessing)
                    
                    if viewModel.isProcessing {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 32, height: 32)
                    } else {
                        Button {
                            Task { await viewModel.sendManualMessage() }
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(Font.system(size: 28))
                                .foregroundStyle(
                                    (viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.attachedImages.isEmpty)
                                    ? Theme.Colors.textMuted : Theme.Colors.accent
                                )
                                .background(Theme.Colors.background.clipShape(Circle()))
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.attachedImages.isEmpty)
                        .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Theme.Colors.background)
            }
            .zIndex(1)
        }
        .preferredColorScheme(.dark)
        .onDrop(of: [.image, .fileURL], isTargeted: nil) { providers in
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { (item, error) in
                        if let url = item as? URL, let image = NSImage(contentsOf: url) {
                            DispatchQueue.main.async {
                                self.viewModel.attachedImages.append(image)
                            }
                        } else if let data = item as? Data, let image = NSImage(data: data) {
                            DispatchQueue.main.async {
                                self.viewModel.attachedImages.append(image)
                            }
                        }
                    }
                }
            }
            return true
        }
    }
    
    /// Reusable header icon button with hover gold tint
    @ViewBuilder
    private func headerButton(icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

#Preview {
    ContentView()
}
