import ExcaliburCore
import SwiftUI

/// Painel flutuante da esquerda: quadros e camadas do quadro aberto.
struct BoardsPanel: View {
    @EnvironmentObject private var ui: WorkspaceUI
    @EnvironmentObject private var library: BoardLibrary

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Picker("Painel", selection: $ui.panelTab) {
                    ForEach(WorkspaceUI.PanelTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Button {
                    library.createBoard()
                    ui.panelTab = .boards
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 26, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .help("Novo quadro (⌘N)")
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 6)

            switch ui.panelTab {
            case .boards: BoardList()
            case .layers: LayerList()
            }
        }
    }
}

/// Lista de quadros: clicar abre, dois cliques renomeia, menu de contexto
/// duplica ou exclui (com confirmação).
struct BoardList: View {
    @EnvironmentObject private var ui: WorkspaceUI
    @EnvironmentObject private var library: BoardLibrary
    @EnvironmentObject private var editor: EditorController

    @State private var renameText = ""
    @FocusState private var renameFocused: Bool

    var body: some View {
        List(selection: $library.selectedID) {
            ForEach(library.boards) { board in
                row(board)
                    .tag(board.id)
                    .contextMenu {
                        Button("Renomear") { ui.beginRename(board) }
                        Button("Duplicar") { BoardActions.duplicate(board, library: library, editor: editor) }
                        Divider()
                        Button("Excluir…", role: .destructive) { ui.boardToDelete = board }
                    }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .onChange(of: library.selectedID) { _, newID in
            ui.renamingID = nil
            if let newID, let board = library.boards.first(where: { $0.id == newID }) {
                editor.loadBoard(board)
            }
        }
        .onChange(of: ui.renamingID) { _, id in
            if let board = library.boards.first(where: { $0.id == id }) {
                renameText = board.name
                renameFocused = true
            }
        }
    }

    @ViewBuilder
    private func row(_ board: Board) -> some View {
        if ui.renamingID == board.id {
            TextField("Nome do quadro", text: $renameText)
                .textFieldStyle(.plain)
                .focused($renameFocused)
                .onSubmit { commitRename(board) }
                .onExitCommand { ui.renamingID = nil }
                .onChange(of: renameFocused) { _, focused in
                    if !focused, ui.renamingID == board.id { commitRename(board) }
                }
        } else {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(board.name).lineLimit(1)
                    Text(board.updatedAt, format: .relative(presentation: .named))
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture(count: 2).onEnded { ui.beginRename(board) })
        }
    }

    private func commitRename(_ board: Board) {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != board.name {
            library.rename(board, to: trimmed)
        }
        ui.renamingID = nil
    }
}

/// Ações sobre quadros que gravam o que estiver pendente antes (lista e menus).
@MainActor
enum BoardActions {
    static func duplicate(_ board: Board, library: BoardLibrary, editor: EditorController) {
        Task {
            if board.id == library.selectedID { await editor.flushAndWait() }
            library.flushSaves()
            library.duplicate(board)
        }
    }

    static func delete(_ board: Board, library: BoardLibrary, editor: EditorController) {
        Task {
            if board.id == library.selectedID { await editor.flushAndWait() }
            library.flushSaves()
            library.delete(board)
        }
    }
}
