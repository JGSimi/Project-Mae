import SwiftUI
import KeyboardShortcuts
import ServiceManagement

class AdvancedSettingsWindowManager {
    static let shared = AdvancedSettingsWindowManager()
    private var window: NSWindow?

    func showWindow() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = AdvancedSettingsView()
        
        // Window dimensions based on typical macOS preferences windows
        let windowRect = NSRect(x: 0, y: 0, width: 500, height: 400)
        let newWindow = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        newWindow.title = "Configurações"
        newWindow.isReleasedWhenClosed = false
        newWindow.center()
        
        newWindow.contentView = NSHostingView(rootView: contentView)
        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct AdvancedSettingsView: View {
    @AppStorage("inferenceMode") var inferenceMode: InferenceMode = .local
    @AppStorage("selectedProvider") var selectedProvider: CloudProvider = .google
    @AppStorage("systemPrompt") var systemPrompt: String = "Responda APENAS com a letra e o texto da alternativa. Sem introduções. Pergunta: "
    @AppStorage("localModelName") var localModelName: String = "gemma3:4b"
    @AppStorage("apiEndpoint") var apiEndpoint: String = "https://api.openai.com/v1/chat/completions"
    @AppStorage("apiModelName") var apiModelName: String = "gpt-4o-mini"
    @AppStorage("playNotifications") var playNotifications: Bool = true
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @State private var apiKey: String = KeychainManager.shared.loadKey() ?? ""
    @State private var fetchedModels: [String] = []
    @State private var isFetchingModels: Bool = false
    @State private var apiKeyTask: Task<Void, Never>? = nil
    @State private var fetchModelsTask: Task<Void, Never>? = nil

    var body: some View {
        TabView {
            // MARK: - General Tab
            Form {
                Section(header: Text("Comportamento do App").font(.headline)) {
                    Toggle("Tocar som e Notificar ao finalizar", isOn: $playNotifications)
                    
                    Toggle("Iniciar Mãe ao ligar o Mac", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, newValue in
                            do {
                                if newValue {
                                    try SMAppService.mainApp.register()
                                } else {
                                    try SMAppService.mainApp.unregister()
                                }
                            } catch {
                                print("Failed to change launchAtLogin state: \(error.localizedDescription)")
                                launchAtLogin = !newValue // Revert
                            }
                        }
                }
            }
            .padding()
            .tabItem {
                Label("Geral", systemImage: "gearshape")
            }

            // MARK: - Models Tab
            Form {
                Section(header: Text("Processamento da IA").font(.headline)) {
                    Picker("Modo:", selection: $inferenceMode) {
                        ForEach(InferenceMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }

                Divider()

                if inferenceMode == .local {
                    Section(header: Text("Configurações Locais").font(.headline)) {
                        TextField("Nome do Modelo (Ollama):", text: $localModelName)
                            .textFieldStyle(.roundedBorder)
                        
                        Text("Certifique-se de que o aplicativo Ollama está rodando na porta padrão (11434).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section(header: Text("Configuração Cloud").font(.headline)) {
                        Picker("Provedor:", selection: $selectedProvider) {
                            ForEach(CloudProvider.allCases) { provider in
                                Text(provider.rawValue).tag(provider)
                            }
                        }
                        .onChange(of: selectedProvider) { _, newValue in
                            fetchModelsTask?.cancel()
                            fetchModelsTask = Task {
                                try? await Task.sleep(nanoseconds: 300_000_000)
                                guard !Task.isCancelled else { return }
                                apiEndpoint = newValue.defaultEndpoint
                                fetchedModels = []
                                if let firstModel = newValue.availableModels.first {
                                    apiModelName = firstModel
                                }
                                await reloadModels()
                            }
                        }
                        
                        if selectedProvider == .custom {
                            TextField("URL do Endpoint:", text: $apiEndpoint)
                                .textFieldStyle(.roundedBorder)
                            
                            TextField("Nome Extato do Modelo:", text: $apiModelName)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            HStack {
                                Picker("Modelo:", selection: $apiModelName) {
                                    let displayModels = !fetchedModels.isEmpty ? fetchedModels : selectedProvider.availableModels
                                    ForEach(displayModels, id: \.self) { model in
                                        Text(model).tag(model)
                                    }
                                }
                                
                                if isFetchingModels {
                                    ProgressView().controlSize(.small).padding(.leading, 4)
                                }
                            }
                        }
                        
                        SecureField("Chave de API:", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: apiKey) { _, newValue in
                                apiKeyTask?.cancel()
                                apiKeyTask = Task {
                                    try? await Task.sleep(nanoseconds: 500_000_000)
                                    guard !Task.isCancelled else { return }
                                    KeychainManager.shared.saveKey(newValue)
                                    await reloadModels()
                                }
                            }
                        Text("Sua chave está protegida na Keychain do macOS.")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
            }
            .padding()
            .tabItem {
                Label("Modelos", systemImage: "cpu")
            }
            .task {
                await reloadModels()
            }

            // MARK: - AI/Prompt Tab
            Form {
                Section(header: Text("Personalidade da IA (System Prompt)").font(.headline)) {
                    Text("Instruções que ditam como a IA vai agir e responder às suas perguntas.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    TextEditor(text: $systemPrompt)
                        .font(.body)
                        .frame(minHeight: 120)
                        .padding(4)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }
            }
            .padding()
            .tabItem {
                Label("IA", systemImage: "sparkles")
            }

            // MARK: - Shortcuts Tab
            Form {
                Section(header: Text("Atalhos Globais").font(.headline)) {
                    HStack {
                        Text("Analisar Área de Transferência:")
                        Spacer()
                        KeyboardShortcuts.Recorder(for: .processClipboard)
                    }
                    .padding(.vertical, 4)
                    
                    HStack {
                        Text("Analisar Tela Automaticamente:")
                        Spacer()
                        KeyboardShortcuts.Recorder(for: .processScreen)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .tabItem {
                Label("Atalhos", systemImage: "keyboard")
            }
        }
        .frame(width: 500, height: 400) // Fixed size for standard Mac settings feel
    }
    
    private func reloadModels() async {
        guard selectedProvider.modelsEndpoint != nil, !apiKey.isEmpty else { return }
        isFetchingModels = true
        defer { isFetchingModels = false }
        
        do {
            let models = try await ModelFetcher.shared.fetchModels(for: selectedProvider, apiKey: apiKey)
            if !models.isEmpty {
                fetchedModels = models
                if !models.contains(apiModelName), let first = models.first {
                    apiModelName = first
                }
            }
        } catch {
            print("Failed to fetch models dynamically: \(error)")
        }
    }
}
