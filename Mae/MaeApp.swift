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
        
        // Solicita permissão logo ao abrir o app
        Task {
            try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
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
    @ObservedObject private var viewModel = AssistantViewModel.shared
    
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

        let contentView = WelcomeView()
        
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 480),
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
    var body: some View {
        VStack(spacing: 0) {
            // Header Image / Icon
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(.primary)
                
                Text("Bem-vindo à Mãe")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .padding(.top, 50)
            .padding(.bottom, 20)
            
            // Content
            VStack(spacing: 24) {
                Text("Sua assistente inteligente sempre disponível na barra de menus.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                VStack(spacing: 20) {
                    FeatureRow(
                        icon: "arrow.up.to.line.compact",
                        iconColor: .primary,
                        title: "Sempre Pronta",
                        description: "Clique no ícone na barra de menus no topo da tela (perto do relógio) para abrir o chat a qualquer momento."
                    )
                    
                    FeatureRow(
                        icon: "macwindow.badge.plus",
                        iconColor: .primary,
                        title: "Análise de Tela Inteligente",
                        description: "Pressione ⌘ + ⇧ + Z para capturar sua tela e receber ajuda contextual automática."
                    )
                    
                    FeatureRow(
                        icon: "doc.on.clipboard",
                        iconColor: .primary,
                        title: "Análise de Área de Transferência",
                        description: "Pressione ⌘ + ⇧ + X para que a IA analise imediatamente o que você copiou."
                    )
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                Button(action: {
                    WelcomeWindowManager.shared.closeWindow()
                }) {
                    Text("Começar a Usar")
                        .font(.headline)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 30)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.bottom, 30)
            }
            .padding(.top, 10)
            .frame(maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .edgesIgnoringSafeArea(.all)
        .frame(width: 600, height: 500)
    }
}

struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }
}
