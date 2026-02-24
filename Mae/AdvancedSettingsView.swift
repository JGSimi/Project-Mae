import SwiftUI
import KeyboardShortcuts
import ServiceManagement

// Estilos customizados para o design Premium Dark

struct PremiumSectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.5))
            .padding(.bottom, 4)
            .padding(.top, 16)
            .padding(.horizontal, 4)
    }
}

struct PremiumGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            configuration.content
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.8)) // Darker grouped background
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct PremiumRow: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let iconColor: Color
    
    init(title: String, subtitle: String? = nil, icon: String? = nil, iconColor: Color = .white) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 24, height: 24)
                    .background(iconColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundStyle(.white)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }
            Spacer()
        }
    }
}

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
            .preferredColorScheme(.dark)
        
        let windowRect = NSRect(x: 0, y: 0, width: 700, height: 500)
        let newWindow = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Premium transparent titlebar look
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.isMovableByWindowBackground = true
        
        // Window general dark appearance
        newWindow.appearance = NSAppearance(named: .darkAqua)
        newWindow.backgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.11, alpha: 1.0) // Solid dark gray/black
        
        newWindow.isReleasedWhenClosed = false
        newWindow.center()
        
        newWindow.contentView = NSHostingView(rootView: contentView)
        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "Geral"
    case models = "Modelos & IA"
    case prompt = "Comportamento"
    case shortcuts = "Atalhos"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .models: return "cpu"
        case .prompt: return "text.bubble"
        case .shortcuts: return "command"
        }
    }
}

struct AdvancedSettingsView: View {
    @State private var selectedTab: SettingsTab? = .general
    
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
        NavigationSplitView {
            // MARK: - Sidebar Setup
            List(selection: $selectedTab) {
                Spacer().frame(height: 20)
                
                ForEach(SettingsTab.allCases) { tab in
                    NavigationLink(value: tab) {
                        Label {
                            Text(tab.rawValue)
                                .font(.system(size: 14, weight: .medium))
                        } icon: {
                            Image(systemName: tab.icon)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 250)
            // Override sidebar background for that solid dark look
            .scrollContentBackground(.hidden)
            .background(Color(NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)))
            
        } detail: {
            // MARK: - Detail Setup
            ZStack {
                Color(NSColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1.0)) // Even darker content bg
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        Text(selectedTab?.rawValue ?? "")
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.top, 40) // padding for transparent titlebar
                            .padding(.bottom, 8)
                        
                        switch selectedTab {
                        case .general:
                            generalSettings
                        case .models:
                            modelSettings
                        case .prompt:
                            promptSettings
                        case .shortcuts:
                            shortcutSettings
                        case .none:
                            Text("Selecione uma categoria")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                    .frame(maxWidth: 600, alignment: .leading)
                }
            }
            .task {
                await reloadModels()
            }
        }
    }
    
    // MARK: - Views for Tabs
    
    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 0) {
            PremiumSectionHeader(title: "Sistema & Notificações")
            
            GroupBox {
                VStack(spacing: 0) {
                    HStack {
                        PremiumRow(title: "Início Automático", subtitle: "Abrir a Mãe junto com o Mac", icon: "macwindow", iconColor: .blue)
                        Toggle("", isOn: $launchAtLogin)
                            .toggleStyle(.switch)
                    }
                    .padding(16)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            print("Failed to change launchAtLogin state: \(error.localizedDescription)")
                            launchAtLogin = !newValue
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    HStack {
                        PremiumRow(title: "Sons e Alertas", subtitle: "Tocar som quando a resposta terminar", icon: "bell.fill", iconColor: .orange)
                        Toggle("", isOn: $playNotifications)
                            .toggleStyle(.switch)
                    }
                    .padding(16)
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    Button {
                        WelcomeWindowManager.shared.showWindow()
                    } label: {
                        HStack {
                            PremiumRow(title: "Tela de Boas Vindas", subtitle: "Rever apresentação do aplicativo", icon: "hand.wave.fill", iconColor: .yellow)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.3))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(16)
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    Button {
                        UpdaterController.shared.checkForUpdates()
                    } label: {
                        HStack {
                            PremiumRow(title: "Atualizações", subtitle: "Buscar nova versão da Mãe", icon: "arrow.triangle.2.circlepath", iconColor: .cyan)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.3))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(16)
                }
            }
            .groupBoxStyle(PremiumGroupBoxStyle())
        }
    }
    
    private var modelSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            VStack(alignment: .leading, spacing: 0) {
                PremiumSectionHeader(title: "Modo de Inferência")
                
                GroupBox {
                    Picker("", selection: $inferenceMode) {
                        ForEach(InferenceMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                    .padding(16)
                }
                .groupBoxStyle(PremiumGroupBoxStyle())
            }
            
            if inferenceMode == .local {
                VStack(alignment: .leading, spacing: 0) {
                    PremiumSectionHeader(title: "Ollama (Local)")
                    
                    GroupBox {
                        VStack(spacing: 0) {
                            HStack {
                                PremiumRow(title: "Nome do Modelo", subtitle: "Deve estar baixado no Ollama", icon: "desktopcomputer", iconColor: .green)
                                Spacer()
                                TextField("ex: gemma3:4b", text: $localModelName)
                                    .textFieldStyle(.plain)
                                    .padding(8)
                                    .background(Color.white.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .frame(width: 150)
                            }
                            .padding(16)
                        }
                    }
                    .groupBoxStyle(PremiumGroupBoxStyle())
                }
                
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    PremiumSectionHeader(title: "Cloud API")
                    
                    GroupBox {
                        VStack(spacing: 0) {
                            HStack {
                                PremiumRow(title: "Provedor", icon: "cloud.fill", iconColor: .cyan)
                                Spacer()
                                Picker("", selection: $selectedProvider) {
                                    ForEach(CloudProvider.allCases) { provider in
                                        Text(provider.rawValue).tag(provider)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 160)
                            }
                            .padding(16)
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
                            
                            Divider().background(Color.white.opacity(0.1))
                            
                            if selectedProvider == .custom {
                                VStack(spacing: 12) {
                                    HStack {
                                        Text("URL Custom:").foregroundStyle(.white).font(.system(size: 13, weight: .medium))
                                        TextField("URL", text: $apiEndpoint)
                                            .textFieldStyle(.plain)
                                            .padding(8).background(Color.white.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                    HStack {
                                        Text("Modelo:").foregroundStyle(.white).font(.system(size: 13, weight: .medium))
                                        TextField("Nome do Modelo", text: $apiModelName)
                                            .textFieldStyle(.plain)
                                            .padding(8).background(Color.white.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                }.padding(16)
                                
                            } else {
                                HStack {
                                    PremiumRow(title: "Modelo", icon: "server.rack", iconColor: .purple)
                                    
                                    if isFetchingModels {
                                        ProgressView().controlSize(.small).padding(.trailing, 8)
                                    }
                                    
                                    Picker("", selection: $apiModelName) {
                                        let displayModels = !fetchedModels.isEmpty ? fetchedModels : selectedProvider.availableModels
                                        ForEach(displayModels, id: \.self) { model in
                                            Text(model).tag(model)
                                        }
                                    }
                                    .labelsHidden()
                                    .frame(width: 160)
                                }
                                .padding(16)
                            }
                            
                            Divider().background(Color.white.opacity(0.1))
                            
                            VStack(alignment: .leading, spacing: 12) {
                                PremiumRow(title: "Chave de API (Autenticação)", icon: "key.fill", iconColor: .yellow)
                                
                                SecureField("Cole sua API Key...", text: $apiKey)
                                    .textFieldStyle(.plain)
                                    .padding(10)
                                    .background(Color.white.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                                    .onChange(of: apiKey) { _, newValue in
                                        apiKeyTask?.cancel()
                                        apiKeyTask = Task {
                                            try? await Task.sleep(nanoseconds: 500_000_000)
                                            guard !Task.isCancelled else { return }
                                            KeychainManager.shared.saveKey(newValue)
                                            await reloadModels()
                                        }
                                    }
                            }
                            .padding(16)
                        }
                    }
                    .groupBoxStyle(PremiumGroupBoxStyle())
                }
            }
        }
    }
    
    private var promptSettings: some View {
        VStack(alignment: .leading, spacing: 0) {
            PremiumSectionHeader(title: "System Prompt")
            
            Text("Defina a personalidade e regras de resposta da IA.")
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.5))
                .padding(.bottom, 12)
            
            TextEditor(text: $systemPrompt)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white)
                .padding(12)
                .frame(minHeight: 180)
                // Use a standard custom background mimicking premium inputs
                .scrollContentBackground(.hidden)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }
    
    private var shortcutSettings: some View {
        VStack(alignment: .leading, spacing: 0) {
            PremiumSectionHeader(title: "Ações Globais")
            
            GroupBox {
                VStack(spacing: 0) {
                    HStack {
                        PremiumRow(title: "Analisar Clipboard", subtitle: "Manda o texto copiado para a IA", icon: "doc.on.clipboard", iconColor: .pink)
                        Spacer()
                        KeyboardShortcuts.Recorder(for: .processClipboard)
                    }
                    .padding(16)
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    HStack {
                        PremiumRow(title: "Analisar Tela", subtitle: "Tira print contínuo e analisa a tela", icon: "viewfinder", iconColor: .teal)
                        Spacer()
                        KeyboardShortcuts.Recorder(for: .processScreen)
                    }
                    .padding(16)
                }
            }
            .groupBoxStyle(PremiumGroupBoxStyle())
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
                if !models.contains(apiModelName), let first = models.first {
                    apiModelName = first
                }
            }
        } catch {
            print("Failed to fetch dynamically: \(error)")
        }
    }
}
