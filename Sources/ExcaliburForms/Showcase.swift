import AppKit
import SwiftUI

/// Modo vitrine para as capturas do witchmymac.com (`EXCALIBUR_SHOWCASE=1`).
/// Só vale numa cópia isolada do app (veja o CLAUDE.md); sem a variável, nada
/// aqui tem efeito. Variáveis aplicadas quando a janela aparece:
/// - `EXCALIBUR_SHOWCASE_SIZE=1440x900`: tamanho do conteúdo da janela.
/// - `EXCALIBUR_SHOWCASE_SCREEN=left`: janela na tela mais à esquerda, à frente
///   sem ativar o app (o WebKit não desenha o canvas numa janela encoberta).
/// - `EXCALIBUR_SHOWCASE_PANEL=boards|layers|none`: painel lateral.
/// - `EXCALIBUR_SHOWCASE_SELECT=<id do elemento>`: seleciona um elemento (mostra o inspetor).
/// - `EXCALIBUR_SHOWCASE_TOOL=<ferramenta>`: ferramenta ativa (`text`, `stickynote`…).
/// - `EXCALIBUR_SHOWCASE_COMMAND=zoomToFit`: comando do editor depois de abrir o quadro.
/// - `EXCALIBUR_SHOWCASE_SETTINGS=general|about`: abre os Ajustes nessa aba.
enum Showcase {
    private static let env = ProcessInfo.processInfo.environment

    static var isOn: Bool { env["EXCALIBUR_SHOWCASE"] == "1" }

    /// Aba inicial dos Ajustes na vitrine.
    static var settingsTab: String? { isOn ? env["EXCALIBUR_SHOWCASE_SETTINGS"] : nil }

    @MainActor
    static func apply(ui: WorkspaceUI, editor: EditorController, openSettings: @escaping () -> Void) {
        guard isOn else { return }
        switch env["EXCALIBUR_SHOWCASE_PANEL"] {
        case "boards": ui.panelTab = .boards; ui.panelVisible = true
        case "layers": ui.panelTab = .layers; ui.panelVisible = true
        case "none": ui.panelVisible = false
        default: break
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            if let size = env["EXCALIBUR_SHOWCASE_SIZE"]?.split(separator: "x").compactMap({ Double($0) }),
               size.count == 2,
               let window = NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain }) {
                window.setContentSize(NSSize(width: size[0], height: size[1]))
                window.center()
            }
            if env["EXCALIBUR_SHOWCASE_SCREEN"] == "left",
               let screen = NSScreen.screens.min(by: { $0.frame.minX < $1.frame.minX }),
               let window = NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain }) {
                let area = screen.visibleFrame
                let frame = window.frame
                window.setFrameOrigin(NSPoint(
                    x: area.midX - frame.width / 2,
                    y: area.midY - frame.height / 2
                ))
                window.orderFrontRegardless()
            }
            while !editor.isReady { try? await Task.sleep(for: .milliseconds(200)) }
            // o quadro chega à página depois do "ready" (leitura fora da thread principal)
            try? await Task.sleep(for: .seconds(2))
            if let tool = env["EXCALIBUR_SHOWCASE_TOOL"].flatMap(Tool.init(rawValue:)) {
                editor.setTool(tool)
            }
            if let command = env["EXCALIBUR_SHOWCASE_COMMAND"].flatMap(Command.init(rawValue:)) {
                editor.command(command)
                try? await Task.sleep(for: .milliseconds(500))
            }
            if let id = env["EXCALIBUR_SHOWCASE_SELECT"] {
                editor.layerAction(id, "select")
            }
            if settingsTab != nil {
                openSettings()
                try? await Task.sleep(for: .milliseconds(600))
                // à frente na mesma tela, sem ativar o app
                if let main = NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain && $0.frame.width > 700 }),
                   let settings = NSApp.windows.first(where: { $0.isVisible && $0 !== main && $0.frame.width < 700 }) {
                    settings.setFrameOrigin(NSPoint(
                        x: main.frame.midX - settings.frame.width / 2,
                        y: main.frame.midY - settings.frame.height / 2
                    ))
                    settings.orderFrontRegardless()
                }
            }
        }
    }
}
