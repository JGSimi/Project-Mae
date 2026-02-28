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
import PDFKit

// MARK: - Shortcut Name definition
extension KeyboardShortcuts.Name {
    static let processClipboard = Self("processClipboard", default: .init(.x, modifiers: [.command, .shift]))
    static let processScreen = Self("processScreen", default: .init(.z, modifiers: [.command, .shift]))
    static let quickInput = Self("quickInput", default: .init(.space, modifiers: [.command, .shift]))
}



// MARK: - Models
enum MessageSource {
    case chat
    case screenAnalysis
}

struct ChatAttachment: Identifiable {
    let id = UUID()
    let name: String
    let data: Data?
    let content: String?
    let image: NSImage?
    let isImage: Bool
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    var images: [NSImage]? = nil
    var attachments: [ChatAttachment]? = nil
    let isUser: Bool
    let source: MessageSource
    let timestamp = Date()
    
    init(content: String, images: [NSImage]? = nil, attachments: [ChatAttachment]? = nil, isUser: Bool, source: MessageSource = .chat) {
        self.content = content
        self.images = images
        self.attachments = attachments
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
    @Published var attachedImages: [NSImage] = [] // Deprecated logic soon
    @Published var pendingAttachments: [ChatAttachment] = []
    
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

    func attachment(from url: URL) -> ChatAttachment? {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }

        let type = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType

        if (type?.conforms(to: .image) == true || NSImage(contentsOf: url) != nil),
           let image = NSImage(contentsOf: url) {
            return ChatAttachment(name: url.lastPathComponent, data: nil, content: nil, image: image, isImage: true)
        }

        if type?.conforms(to: .pdf) == true || url.pathExtension.lowercased() == "pdf" {
            let pdfText = extractPDFText(from: url)
            let normalized = pdfText.trimmingCharacters(in: .whitespacesAndNewlines)
            let content = normalized.isEmpty
                ? "[PDF anexado: \(url.lastPathComponent)]\nNão foi possível extrair texto pesquisável deste PDF."
                : pdfText
            return ChatAttachment(name: url.lastPathComponent, data: nil, content: content, image: nil, isImage: false)
        }

        if let textContent = extractTextFileContent(from: url) {
            return ChatAttachment(name: url.lastPathComponent, data: nil, content: textContent, image: nil, isImage: false)
        }

        if let data = try? Data(contentsOf: url) {
            let content = "[Arquivo binário anexado: \(url.lastPathComponent)]\nO conteúdo não é texto e não pôde ser extraído automaticamente."
            return ChatAttachment(name: url.lastPathComponent, data: data, content: content, image: nil, isImage: false)
        }

        return nil
    }

    private func extractPDFText(from url: URL) -> String {
        guard let document = PDFDocument(url: url), document.pageCount > 0 else { return "" }
        return document.string ?? ""
    }

    private func extractTextFileContent(from url: URL) -> String? {
        if let utf8 = try? String(contentsOf: url, encoding: .utf8) {
            let trimmed = utf8.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return utf8 }
        }

        guard let data = try? Data(contentsOf: url) else { return nil }
        let encodings: [String.Encoding] = [.utf16, .unicode, .isoLatin1, .windowsCP1252, .ascii]
        for encoding in encodings {
            if let decoded = String(data: data, encoding: encoding) {
                let trimmed = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return decoded }
            }
        }
        return nil
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

        await executeRequest(prompt: textoClipboard, rawImages: copiedImage != nil ? [copiedImage!] : nil, attachments: nil)
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
        
        let userMsg = ChatMessage(content: prompt, images: analysisImage != nil ? [analysisImage!] : nil, attachments: nil, isUser: true, source: .screenAnalysis)
        let assistantMsg = ChatMessage(content: analysisResult, images: nil, attachments: nil, isUser: false, source: .screenAnalysis)
        
        messages.append(userMsg)
        messages.append(assistantMsg)
        
        // Se houver follow-up, enviar como nova mensagem
        if let followUp = followUp, !followUp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Task {
                await executeRequest(prompt: followUp, rawImages: nil, attachments: nil)
            }
        }
        
        // Limpa a análise atual após transferir
        analysisResult = ""
        analysisImage = nil
    }
    
    func captureScreen() -> NSImage? {
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
        let attachmentsToProcess = pendingAttachments
        
        guard !isProcessing && (!text.isEmpty || !attachmentsToProcess.isEmpty) else { return }
        
        inputText = ""
        pendingAttachments.removeAll()
        attachedImages.removeAll()
        
        var finalPrompt = text
        var extractedImages: [NSImage] = []
        
        for attachment in attachmentsToProcess {
            if attachment.isImage, let img = attachment.image {
                extractedImages.append(img)
            } else if let content = attachment.content {
                finalPrompt += "\n\n[Arquivo: \(attachment.name)]\n\(content)"
            }
        }
        
        await executeRequest(prompt: finalPrompt, rawImages: extractedImages.isEmpty ? nil : extractedImages, attachments: attachmentsToProcess.isEmpty ? nil : attachmentsToProcess)
    }

    private func executeRequest(prompt: String, rawImages: [NSImage]?, attachments: [ChatAttachment]?) async {
        isProcessing = true
        defer { isProcessing = false }

        let inferenceMode = SettingsManager.inferenceMode
        let systemPrompt = SettingsManager.systemPrompt
        
        // Convert to Base64 for processing but store the raw `NSImage` locally
        let base64Images = rawImages?.compactMap { $0.resizedAndCompressedBase64() }
        
        // Adiciona a pergunta ao histórico
        let userMsg = ChatMessage(content: prompt, images: rawImages, attachments: attachments, isUser: true)
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
        content.title = ">_"
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
    var animationIndex: Int = 0
    @State private var markdownHeight: CGFloat = 40

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 40) }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                // Context label for screen analysis messages
                if message.source == .screenAnalysis && message.isUser {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.viewfinder")
                            .font(Theme.Typography.caption)
                            .symbolEffect(.pulse)
                        Text("Análise de Tela")
                            .font(Theme.Typography.caption)
                    }
                    .foregroundStyle(Theme.Colors.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Theme.Colors.accentSubtle)
                    .clipShape(Capsule())
                }
                
                if let attachments = message.attachments {
                    ForEach(Array(attachments.enumerated()), id: \.offset) { _, attachment in
                        if attachment.isImage, let img = attachment.image {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 250)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusMedium, style: .continuous))
                                .maeMediumShadow()
                        } else if !attachment.isImage {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text.fill")
                                    .foregroundStyle(Theme.Colors.accent)
                                    .symbolEffect(.bounce, options: .nonRepeating)
                                Text(attachment.name)
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.Colors.surfaceSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusSmall))
                            .maeSoftShadow()
                        }
                    }
                }
                
                // Fallback for screen analysis and backward compatibility
                if message.attachments == nil, let images = message.images {
                    ForEach(images.indices, id: \.self) { index in
                        Image(nsImage: images[index])
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 250)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusMedium, style: .continuous))
                            .maeMediumShadow()
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
                            .maeSoftShadow()
                            .textSelection(.enabled)
                    } else {
                        AutoSizingMarkdownWebView(markdown: message.content, measuredHeight: $markdownHeight)
                            .frame(height: markdownHeight)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .maeSurfaceBackground(cornerRadius: Theme.Metrics.radiusMedium)
                            .maeSoftShadow()
                    }
                }
            }
            .maeHover()
            
            if !message.isUser { Spacer(minLength: 40) }
        }
        .padding(.horizontal, Theme.Metrics.spacingLarge)
        .padding(.vertical, 4)
        .maeStaggered(index: animationIndex, baseDelay: 0.05)
    }
}

struct ContentView: View {
    @ObservedObject private var viewModel = AssistantViewModel.shared
    @Namespace private var bottomID
    @State private var showSettings = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack {
            chatView
                .opacity(showSettings ? 0.0 : 1.0)
                .offset(x: showSettings ? -30 : 0)
                .blur(radius: showSettings ? 3 : 0)
                .scaleEffect(showSettings ? 0.97 : 1.0)
                .animation(Theme.Animation.responsive, value: showSettings)
                .zIndex(1)

            if showSettings {
                SettingsView(isPresented: $showSettings)
                    .transition(.maeSlideIn)
                    .zIndex(2)
            }
        }
        .frame(width: 450, height: 650)
        .maeAppearAnimation(animation: Theme.Animation.expressive, scale: 0.92)
        .onAppear {
            isInputFocused = true
        }
        .onChange(of: showSettings) { _, newValue in
            if !newValue {
                // Focus back on input when settings close
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isInputFocused = true
                }
            }
        }
    }

    private var chatView: some View {
        VStack(spacing: 0) {
            // ... (keeping previous header content)
            // Header
            HStack {
                HStack(spacing: 6) {
                    Text(">_")
                        .font(Theme.Typography.heading)
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
                
                Spacer()
                
                HStack(spacing: 14) {
                    MaeIconButton(icon: "macwindow.badge.plus", helpText: "Abrir Janela de Análise") {
                        AnalysisWindowManager.shared.showWindow()
                    }
                    MaeIconButton(icon: "trash", helpText: "Limpar histórico") {
                        withAnimation { viewModel.clearHistory() }
                    }
                    MaeIconButton(icon: "gearshape", helpText: "Configurações") {
                        withAnimation(Theme.Animation.smooth) {
                            showSettings = true
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Theme.Colors.background)
            .overlay(MaeGradientDivider(), alignment: .bottom)
            .zIndex(1)

            // Chat List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if viewModel.messages.isEmpty {
                            VStack(spacing: Theme.Metrics.spacingDefault) {
                                Image(systemName: "sun.horizon.fill")
                                    .font(.system(size: 32, weight: .light))
                                    .foregroundStyle(Theme.Colors.accent.opacity(0.4))
                                    .symbolEffect(.breathe.plain)
                                    .maeFloating(amplitude: 4, duration: 3.5)
                                Text("Comece uma conversa")
                                    .font(Theme.Typography.bodyBold)
                                    .foregroundStyle(Theme.Colors.textMuted)
                                    .maeStaggered(index: 1, baseDelay: 0.12)
                                Text("Pergunte qualquer coisa.")
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.textMuted.opacity(0.6))
                                    .maeStaggered(index: 2, baseDelay: 0.12)
                            }
                            .padding(.top, 120)
                            .frame(maxWidth: .infinity)
                            .maeAppearAnimation(animation: Theme.Animation.expressive)
                        } else {
                            ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                                ChatBubble(message: message, animationIndex: index)
                                    .id(message.id)
                                    .transition(.maePopIn)
                            }
                        }
                        Color.clear.frame(height: 10).id(bottomID)
                    }
                    .padding(.vertical, Theme.Metrics.spacingDefault)
                }
                .scrollContentBackground(.hidden)
                .background(Theme.Colors.background)
                .onChange(of: viewModel.messages.count) {
                    withAnimation(Theme.Animation.responsive) {
                        proxy.scrollTo(bottomID, anchor: .bottom)
                    }
                }
            }

            // Footer / Input Area
            VStack(spacing: 0) {
                // Attached Images and Files Preview
                if !viewModel.pendingAttachments.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(viewModel.pendingAttachments.enumerated()), id: \.offset) { index, attachment in
                                ZStack(alignment: .topTrailing) {
                                    if attachment.isImage, let img = attachment.image {
                                        Image(nsImage: img)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 60, height: 60)
                                            .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusSmall))
                                            .shadow(radius: 2)
                                    } else {
                                        VStack(spacing: 4) {
                                            Image(systemName: "doc.text.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(Theme.Colors.accent)
                                                .symbolEffect(.bounce, options: .nonRepeating)
                                            Text(attachment.name)
                                                .font(.system(size: 9))
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                                .frame(width: 50)
                                        }
                                        .frame(width: 60, height: 60)
                                        .background(Theme.Colors.surfaceSecondary)
                                        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusSmall))
                                        .shadow(radius: 2)
                                    }
                                    
                                    Button {
                                        withAnimation(Theme.Animation.snappy) {
                                            let _ = viewModel.pendingAttachments.remove(at: index)
                                        }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundStyle(Theme.Colors.textPrimary, Theme.Colors.background)
                                            .symbolEffect(.bounce, options: .nonRepeating)
                                            .frame(width: 28, height: 28)
                                    }
                                    .buttonStyle(.plain)
                                    .offset(x: 6, y: -6)
                                }
                                .transition(.maeScaleFade)
                                .maeStaggered(index: index, baseDelay: 0.06)
                            }
                        }
                        .padding(.horizontal, Theme.Metrics.spacingLarge)
                        .padding(.top, 10)
                        .padding(.bottom, 6)
                    }
                    .transition(.maeSlideUp)
                }

                MaeGradientDivider()
                
                HStack(alignment: .center, spacing: Theme.Metrics.spacingDefault) {
                    MaeIconButton(icon: "plus.circle.fill", size: 18, color: Theme.Colors.textSecondary, helpText: "Anexar arquivo/imagem") {
                        let panel = NSOpenPanel()
                        panel.allowedContentTypes = [UTType.image, UTType.plainText, UTType.pdf, UTType.json, UTType.sourceCode, UTType.data]
                        panel.allowsMultipleSelection = true
                        if panel.runModal() == .OK {
                            for url in panel.urls {
                                if let attachment = viewModel.attachment(from: url) {
                                    viewModel.pendingAttachments.append(attachment)
                                } else {
                                    print("Erro ao ler arquivo selecionado: \(url.lastPathComponent)")
                                }
                            }
                        }
                    }

                    TextField("Pergunte à Mãe...", text: $viewModel.inputText, axis: .vertical)
                        .maeInputStyle(cornerRadius: Theme.Metrics.radiusLarge)
                        .lineLimit(1...6)
                        .focused($isInputFocused)
                        .onSubmit {
                            Task { await viewModel.sendManualMessage() }
                        }
                        .disabled(viewModel.isProcessing)
                    
                    if viewModel.isProcessing {
                        MaeTypingDots()
                            .frame(width: 32, height: 32)
                            .transition(.maeScaleFade)
                    } else {
                        Button {
                            Task { await viewModel.sendManualMessage() }
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(
                                    (viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.pendingAttachments.isEmpty)
                                    ? Theme.Colors.textMuted : Theme.Colors.accent
                                )
                                .symbolEffect(.bounce, options: .nonRepeating)
                                .background(Theme.Colors.background.clipShape(Circle()))
                                .frame(width: 40, height: 40)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.pendingAttachments.isEmpty)
                        .keyboardShortcut(.defaultAction)
                        .maePressEffect()
                        .transition(.maeScaleFade)
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
                                let attachment = ChatAttachment(name: url.lastPathComponent, data: nil, content: nil, image: image, isImage: true)
                                self.viewModel.pendingAttachments.append(attachment)
                            }
                        } else if let data = item as? Data, let image = NSImage(data: data) {
                            DispatchQueue.main.async {
                                let attachment = ChatAttachment(name: "Imagem", data: nil, content: nil, image: image, isImage: true)
                                self.viewModel.pendingAttachments.append(attachment)
                            }
                        }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                        if let url = Self.resolveDroppedFileURL(item) {
                            DispatchQueue.main.async {
                                if let attachment = self.viewModel.attachment(from: url) {
                                    self.viewModel.pendingAttachments.append(attachment)
                                } else {
                                    print("Erro ao ler arquivo do drop: \(url.lastPathComponent)")
                                }
                            }
                        }
                    }
                }
            }
            return true
        }
    }

    private static func resolveDroppedFileURL(_ item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }
        if let data = item as? Data {
            if let url = NSURL(absoluteURLWithDataRepresentation: data, relativeTo: nil) as URL? {
                return url
            }
            if let urlString = String(data: data, encoding: .utf8) {
                return URL(string: urlString)
            }
        }
        if let urlString = item as? String {
            return URL(string: urlString)
        }
        return nil
    }
}

#Preview {
    ContentView()
}
