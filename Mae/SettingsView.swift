import SwiftUI
import KeyboardShortcuts
import ServiceManagement

struct SettingsView: View {
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
    @EnvironmentObject var updater: UpdaterController

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Configurações", systemImage: "gearshape.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.regularMaterial)
            .overlay(Divider(), alignment: .bottom)
            .zIndex(1)

            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: - Shortcuts Box
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Atalhos Globais")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            HStack {
                                Text("Área de Transferência")
                                    .font(.subheadline)
                                Spacer()
                                KeyboardShortcuts.Recorder(for: .processClipboard)
                            }
                            
                            HStack {
                                Text("Análise de Tela")
                                    .font(.subheadline)
                                Spacer()
                                KeyboardShortcuts.Recorder(for: .processScreen)
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .groupBoxStyle(GlassGroupBoxStyle())
                    
                    // MARK: - Inference Mode Box
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Processamento da IA")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            Picker("", selection: $inferenceMode) {
                                ForEach(InferenceMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.radioGroup)
                            .labelsHidden()
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .groupBoxStyle(GlassGroupBoxStyle())
                    
                    // MARK: - System Prompt Box
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Personalidade da IA (System Prompt)")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            Text("Instruções que ditam como a IA vai agir e responder às suas perguntas.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            TextEditor(text: $systemPrompt)
                                .font(.body)
                                .frame(height: 80)
                                .padding(8)
                                .background(Color(NSColor.controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .groupBoxStyle(GlassGroupBoxStyle())
                    
                    // MARK: - Dynamic Settings Box (Local vs API)
                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                            if inferenceMode == .local {
                                // --- LOCAL SETTINGS ---
                                Text("Configurações Locais")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Nome do Modelo")
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                    TextField("Ex: gemma3:4b", text: $localModelName)
                                        .textFieldStyle(.roundedBorder)
                                }
                                
                                HStack {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundStyle(.blue)
                                    Text("Certifique-se de que o aplicativo Ollama está rodando no seu Mac (porta 11434).")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.top, 4)
                                
                            } else {
                                // --- API SETTINGS ---
                                Text("Configuração Cloud")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    
                                    // Provedor Picker
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Provedor de Nuvem")
                                            .font(.caption)
                                            .foregroundStyle(.primary)
                                        
                                        Picker("", selection: $selectedProvider) {
                                            ForEach(CloudProvider.allCases) { provider in
                                                Text(provider.rawValue).tag(provider)
                                            }
                                        }
                                        .labelsHidden()
                                        .onChange(of: selectedProvider) { oldValue, newValue in
                                            fetchModelsTask?.cancel()
                                            fetchModelsTask = Task {
                                                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                                                guard !Task.isCancelled else { return }
                                                apiEndpoint = newValue.defaultEndpoint
                                                fetchedModels = []
                                                if let firstModel = newValue.availableModels.first {
                                                    apiModelName = firstModel
                                                }
                                                await reloadModels()
                                            }
                                        }
                                    }
                                    
                                    Divider().padding(.vertical, 4)
                                    
                                    if selectedProvider == .custom {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("URL do Endpoint Customizado")
                                                .font(.caption)
                                                .foregroundStyle(.primary)
                                            TextField("URL (ex: https://api.openai.com/...)", text: $apiEndpoint)
                                                .textFieldStyle(.roundedBorder)
                                        }
                                        .padding(.bottom, 4)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Nome exato do Modelo (Customizado)")
                                                .font(.caption)
                                                .foregroundStyle(.primary)
                                            TextField("Ex: Custom-Modelo-X", text: $apiModelName)
                                                .textFieldStyle(.roundedBorder)
                                        }
                                    } else {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text("Modelo de IA")
                                                    .font(.caption)
                                                    .foregroundStyle(.primary)
                                                
                                                if isFetchingModels {
                                                    ProgressView()
                                                        .controlSize(.small)
                                                        .scaleEffect(0.6)
                                                        .frame(height: 10)
                                                }
                                            }
                                            
                                            Picker("", selection: $apiModelName) {
                                                let displayModels = !fetchedModels.isEmpty ? fetchedModels : selectedProvider.availableModels
                                                ForEach(displayModels, id: \.self) { model in
                                                    Text(model).tag(model)
                                                }
                                            }
                                            .labelsHidden()
                                        }
                                    }
                                    
                                    Divider().padding(.vertical, 4)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Chave de API (Autenticação)")
                                            .font(.caption)
                                            .foregroundStyle(.primary)
                                        SecureField("Cole sua API Key", text: $apiKey)
                                            .textFieldStyle(.roundedBorder)
                                            .onChange(of: apiKey) { oldValue, newValue in
                                                apiKeyTask?.cancel()
                                                apiKeyTask = Task {
                                                    try? await Task.sleep(nanoseconds: 500_000_000)
                                                    guard !Task.isCancelled else { return }
                                                    KeychainManager.shared.saveKey(newValue)
                                                    await reloadModels()
                                                }
                                            }
                                        
                                        HStack(alignment: .top) {
                                            Image(systemName: "lock.shield.fill")
                                                .foregroundStyle(.green)
                                            Text("Sua chave esta protegida na Keychain.")
                                                .font(.caption2)
                                                .foregroundStyle(.green)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        .padding(.top, 2)
                                    }
                                }
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .groupBoxStyle(GlassGroupBoxStyle())
                    
                    // MARK: - App Updates Box
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Atualizações")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            HStack {
                                Text("Verificar novas versões do aplicativo")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                                
                                Button("Verificar") {
                                    updater.checkForUpdates()
                                }
                                .disabled(!updater.canCheckForUpdates)
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .groupBoxStyle(GlassGroupBoxStyle())
                    
                    // MARK: - App Behavior Box
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Comportamento do App")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            Toggle("Tocar som e Notificar ao finalizar", isOn: $playNotifications)
                                .toggleStyle(.switch)
                            
                            Toggle("Iniciar o app ao ligar o Mac", isOn: $launchAtLogin)
                                .toggleStyle(.switch)
                                .onChange(of: launchAtLogin) { oldValue, newValue in
                                    do {
                                        if newValue {
                                            try SMAppService.mainApp.register()
                                        } else {
                                            try SMAppService.mainApp.unregister()
                                        }
                                    } catch {
                                        print("Failed to change launchAtLogin state: \(error.localizedDescription)")
                                        launchAtLogin = oldValue
                                    }
                                }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .groupBoxStyle(GlassGroupBoxStyle())
                    
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .task {
                await reloadModels()
            }
        }
    }
    
    private func reloadModels() async {
        guard selectedProvider.modelsEndpoint != nil, !apiKey.isEmpty else { return }
        isFetchingModels = true
        defer { isFetchingModels = false }
        
        do {
            let models = try await ModelFetcher.shared.fetchModels(for: selectedProvider, apiKey: apiKey)
            if !models.isEmpty {
                fetchedModels = models
                // If current model is not in the new list, select the first one
                if !models.contains(apiModelName), let first = models.first {
                    apiModelName = first
                }
            }
        } catch {
            print("Failed to fetch models dynamically: \(error)")
        }
    }
}

// MARK: - Custom Glass GroupBox Style
struct GlassGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading) {
            configuration.label
            configuration.content
        }
        .padding(16)
        .background(.regularMaterial)
        // No hardcoded frame so it can expand within TabView
    }
}

#Preview {
    SettingsView()
        .frame(width: 350, height: 550)
}
