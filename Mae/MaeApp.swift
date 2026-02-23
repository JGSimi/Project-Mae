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
