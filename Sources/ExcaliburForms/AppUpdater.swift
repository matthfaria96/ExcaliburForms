import AppKit
import Sparkle
import SwiftUI

/// Atualizações dentro do app pelo Sparkle, como nos outros apps do witchmymac.com.
/// O feed (`SUFeedURL`), a chave pública EdDSA (`SUPublicEDKey`) e a verificação
/// diária ficam no Info.plist (gerado por `scripts/build-app.sh`); cada versão é
/// assinada com a chave EdDSA do witchmymac e o app com o certificado witchmymac.
@MainActor
final class AppUpdater: NSObject, ObservableObject {
    static let shared = AppUpdater()

    /// Falso enquanto uma verificação ou instalação já está em andamento.
    @Published private(set) var canCheckForUpdates = false

    private var controller: SPUStandardUpdaterController?
    private var canCheckObservation: NSKeyValueObservation?

    /// Inicia o agendador do Sparkle. Cópias de teste (outro bundle id, como a
    /// de vitrine) não verificam, a menos que `EXCALIBUR_UPDATES` esteja definida.
    func start() {
        guard controller == nil else { return }
        let env = ProcessInfo.processInfo.environment
        guard Bundle.main.bundleIdentifier == "com.excaliburforms.app" || env["EXCALIBUR_UPDATES"] != nil
        else { return }
        let controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.controller = controller
        canCheckObservation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) {
            [weak self] updater, _ in
            let canCheck = updater.canCheckForUpdates
            DispatchQueue.main.async { self?.canCheckForUpdates = canCheck }
        }
        controller.startUpdater()
    }

    /// "Verificar Atualizações…": sempre mostra um resultado, mesmo "está atualizado".
    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}

/// Item do menu do app e botão em Ajustes › Sobre.
struct CheckForUpdatesButton: View {
    @ObservedObject private var updater = AppUpdater.shared

    var body: some View {
        Button("Verificar Atualizações…") { updater.checkForUpdates() }
            .disabled(!updater.canCheckForUpdates)
    }
}
