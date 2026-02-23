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
struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    var images: [NSImage]? = nil
    let isUser: Bool
    let timestamp = Date()
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

        let defaultPrompt = "Analise o que está na minha tela e me ajude de forma proativa. Não me pergunte o que fazer, apenas forneça a análise ou ajuda diretamente com base no contexto (por exemplo, se for um currículo, dê dicas; se for código, analise bugs, etc)."
        
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
            
            await sendNotification(text: "Análise de tela concluída!")
            NSSound(named: "Glass")?.play()
            
        } catch {
            DispatchQueue.main.async {
                self.analysisResult = "Erro: \(error.localizedDescription)"
            }
            print("Error processing AI: \(error)")
        }
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
            
            await sendNotification(text: finalResponse)
            NSSound(named: "Glass")?.play()
            
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
        var content: [MessageContent] = [.text(prompt)]
        if let images = images {
            for img in images {
                content.append(.image(base64: img))
            }
        }
        
        let userMessage = APIMessage(role: "user", content: content)
        
        let payload = APIRequest(
            model: SettingsManager.apiModelName,
            messages: [userMessage],
            temperature: 0.0,
            stream: false
        )
        
        guard let url = URL(string: SettingsManager.apiEndpoint) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let apiKey = SettingsManager.apiKey
        if !apiKey.isEmpty {
            switch SettingsManager.selectedProvider {
            case .google, .openai, .custom:
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            case .anthropic:
                // Fallback structure in case it's native Anthropic proxy, usually proxy adapters handle Beaer or x-api-key
                request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            }
        }
        
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

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 40) }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                if let images = message.images {
                    ForEach(images.indices, id: \.self) { index in
                        Image(nsImage: images[index])
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(radius: 2)
                    }
                }
                
                if !message.content.isEmpty {
                    Text(.init(message.content))
                        .font(.body)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .foregroundStyle(message.isUser ? .white : .primary)
                        .background(
                            message.isUser
                                ? AnyShapeStyle(LinearGradient(colors: [Color.blue, Color(red: 0.1, green: 0.4, blue: 0.9)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                : AnyShapeStyle(Color(NSColor.windowBackgroundColor))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.black.opacity(message.isUser ? 0.15 : 0.05), radius: message.isUser ? 5 : 3, x: 0, y: 2)
                        .textSelection(.enabled)
                }
            }
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
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
                                .font(.title3)
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
            // Header
            HStack {
                Label("Chat", systemImage: "bubble.left.and.bubble.right.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: {
                        AnalysisWindowManager.shared.showWindow()
                    }) {
                        Image(systemName: "macwindow.badge.plus")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .help("Abrir Janela de Análise")
                    
                    Button(action: {
                        withAnimation {
                            viewModel.clearHistory()
                        }
                    }) {
                        Image(systemName: "trash.circle.fill")
                            .font(.title)
                            .foregroundStyle(.secondary.opacity(0.6), .secondary.opacity(0.1))
                    }
                    .buttonStyle(.plain)
                    .help("Limpar histórico")
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showSettings = true
                        }
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .help("Configurações")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial)
            .overlay(Divider(), alignment: .bottom)
            .zIndex(1)

            // Chat List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if viewModel.messages.isEmpty {
                            VStack(spacing: 16) {
                                Text("Sem Mensagens.")
                                    .font(.title3.weight(.medium))
                                    .foregroundStyle(.gray)
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

                Divider()
                HStack(alignment: .bottom, spacing: 12) {
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
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Anexar imagem")
                    .padding(.bottom, 8)

                    TextField("Envie uma mensagem...", text: $viewModel.inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
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
                            .padding(.bottom, 4)
                    } else {
                        Button {
                            Task { await viewModel.sendManualMessage() }
                        } label: {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background((viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.attachedImages.isEmpty) ? Color.gray.opacity(0.5) : Color.blue)
                                .clipShape(Circle())
                                .shadow(color: (viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.attachedImages.isEmpty) ? .clear : .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.attachedImages.isEmpty)
                        .keyboardShortcut(.defaultAction)
                        .padding(.bottom, 2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial)
            }
            .zIndex(1)
        }
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
}

#Preview {
    ContentView()
}
