import SwiftUI
import Combine
import Sparkle

final class UpdaterController: ObservableObject {
    static let shared = UpdaterController()
    
    private let updaterController: SPUStandardUpdaterController
    
    @Published var canCheckForUpdates = false
    
    private init() {
        // Inicializa o Sparkle
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        
        // Mantém a propriedade `canCheckForUpdates` sincronizada
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
    
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
    
    // Verifica por atualizações sem exibir a janela visual, a menos que haja uma atualização
    func checkForUpdatesInBackground() {
        updaterController.updater.checkForUpdatesInBackground()
    }
}
