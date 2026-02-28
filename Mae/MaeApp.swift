//
//  MaeApp.swift
//  Mae
//
//  Created by Joao Simi on 19/02/26.
//

import SwiftUI
import KeyboardShortcuts
import UserNotifications

// MARK: - App Delegate para gerenciar notificações
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configura o delegado para capturar notificações em primeiro plano
        UNUserNotificationCenter.current().delegate = self
        
        // Verifica primeiro acesso para mostrar a janela de boas vindas
        let hasSeenWelcome = UserDefaults.standard.bool(forKey: "hasSeenWelcome")
        if !hasSeenWelcome {
            WelcomeWindowManager.shared.showWindow()
            UserDefaults.standard.set(true, forKey: "hasSeenWelcome")
        }
        
        // Solicita permissão de notificação apenas se ainda não foi definida (primeira vez)
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .sound])
            }
        }
        
        // Verifica atualizações silenciosamente
        UpdaterController.shared.checkForUpdatesInBackground()
    }
    
    // Esta função permite que a notificação apareça mesmo que o app esteja focado
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Define que queremos mostrar o banner e tocar o som mesmo com o app aberto
        completionHandler([.banner, .sound])
    }
}

@main
struct MaeApp: App {
    // Adaptador para usar o AppDelegate em SwiftUI
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = AssistantViewModel.shared
    
    init() {
        // Registramos o listener global para o atalho quando o app inicia
        KeyboardShortcuts.onKeyDown(for: .processClipboard) {
            Task {
                await AssistantViewModel.shared.processarIA()
            }
        }
        
        KeyboardShortcuts.onKeyDown(for: .processScreen) {
            Task {
                await AssistantViewModel.shared.processarScreen()
            }
        }
        
        KeyboardShortcuts.onKeyDown(for: .quickInput) {
            QuickInputWindowManager.shared.toggleWindow()
        }
    }
    
    var body: some Scene {
        MenuBarExtra("Mãe", systemImage: viewModel.isProcessing ? "message.fill" : "message") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Welcome Window
class WelcomeWindowManager {
    static let shared = WelcomeWindowManager()
    private var window: NSWindow?

    func showWindow() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 960)
        let width = screenRect.width * 0.5
        let height = screenRect.height * 0.5
        
        let contentView = WelcomeView(width: width, height: height)
        
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.isMovableByWindowBackground = true
        newWindow.isReleasedWhenClosed = false
        newWindow.center()
        
        newWindow.contentView = NSHostingView(rootView: contentView)
        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func closeWindow() {
        window?.close()
        window = nil
    }
}

struct WelcomeView: View {
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: Theme.Metrics.spacingLarge) {
                Image("undraw_annotation_rz2w")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 350)
                    .padding(.horizontal, 40)
                
                Text("Bem-vindo")
                    .font(Theme.Typography.largeTitle)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .maeStaggered(index: 1, baseDelay: 0.15)
            }
            .padding(.top, 50)
            .padding(.bottom, 20)
            
            // Content
            VStack(spacing: Theme.Metrics.spacingXLarge) {
                
                VStack(spacing: 20) {
                    FeatureRow(
                        icon: "arrow.up.to.line.compact",
                        title: "Sempre Pronta",
                        description: "Clique no ícone na barra de menus no topo da tela (perto do relógio) para abrir o chat a qualquer momento."
                    )
                    .maeStaggered(index: 3, baseDelay: 0.10)
                    
                    FeatureRow(
                        icon: "macwindow.badge.plus",
                        title: "Análise de Tela Inteligente",
                        description: "Pressione ⌘ + ⇧ + Z para capturar sua tela e receber ajuda contextual automática."
                    )
                    .maeStaggered(index: 4, baseDelay: 0.10)
                    
                    FeatureRow(
                        icon: "doc.on.clipboard",
                        title: "Análise de Área de Transferência",
                        description: "Pressione ⌘ + ⇧ + X para que a IA analise imediatamente o que você copiou."
                    )
                    .maeStaggered(index: 5, baseDelay: 0.10)
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                Button(action: {
                    WelcomeWindowManager.shared.closeWindow()
                }) {
                    Text("Começar a Usar")
                        .font(Theme.Typography.bodyBold)
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 32)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Metrics.radiusMedium, style: .continuous)
                        .fill(Theme.Colors.accent.opacity(0.85))
                )
                .maeGlowHover()
                .maePressEffect()
                .maeStaggered(index: 6, baseDelay: 0.10)
                .padding(.bottom, 30)
            }
            .padding(.top, 10)
            .frame(maxHeight: .infinity)
        }
        .background(MaePageBackground(showGlow: true))
        .edgesIgnoringSafeArea(.all)
        .frame(width: width, height: height)
        .preferredColorScheme(.dark)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Metrics.spacingLarge) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .light))
                .foregroundColor(Theme.Colors.accent)
                .symbolEffect(.pulse.byLayer)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.Typography.bodyBold)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text(description)
                    .font(Theme.Typography.bodySmall)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }
}
