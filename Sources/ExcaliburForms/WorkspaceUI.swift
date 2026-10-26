import ExcaliburCore
import SwiftUI

/// Estado da janela que a barra de menus também comanda: painel de quadros,
/// aba, renomear e excluir.
@MainActor
final class WorkspaceUI: ObservableObject {
    enum PanelTab: String, CaseIterable, Identifiable {
        case boards = "Quadros"
        case layers = "Camadas"
        var id: String { rawValue }
    }

    @Published var panelVisible = UserDefaults.standard.object(forKey: "panelVisible") as? Bool ?? true {
        didSet { UserDefaults.standard.set(panelVisible, forKey: "panelVisible") }
    }
    @Published var panelTab: PanelTab = .boards
    /// Quadro em edição de nome na lista.
    @Published var renamingID: Board.ID?
    /// Quadro aguardando a confirmação de exclusão.
    @Published var boardToDelete: Board?

    func togglePanel() {
        withAnimation(.smooth(duration: 0.28)) { panelVisible.toggle() }
    }

    func show(_ tab: PanelTab) {
        withAnimation(.smooth(duration: 0.28)) {
            if panelVisible, panelTab == tab {
                panelVisible = false
            } else {
                panelTab = tab
                panelVisible = true
            }
        }
    }

    func beginRename(_ board: Board) {
        withAnimation(.smooth(duration: 0.28)) {
            panelTab = .boards
            panelVisible = true
        }
        renamingID = board.id
    }
}
