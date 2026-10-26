import ExcaliburCore
import SwiftUI

/// Lista lateral de quadros: criar, renomear inline, duplicar, excluir.
struct BoardList: View {
    @EnvironmentObject private var library: BoardLibrary
    @EnvironmentObject private var editor: EditorController

    @State private var renamingID: Board.ID?
    @State private var renameText = ""
    @State private var boardToDelete: Board?
    @FocusState private var renameFocused: Board.ID?

    var body: some View {
        List(selection: $library.selectedID) {
            ForEach(library.boards) { board in
                row(board)
                    .tag(board.id)
                    .contextMenu { contextMenu(board) }
            }
        }
        .navigationTitle("Quadros")
        .safeAreaInset(edge: .bottom) { bottomBar }
        .confirmationDialog(
            "Excluir quadro",
            isPresented: deleteConfirmation,
            presenting: boardToDelete
        ) { board in
            Button("Excluir \"\(board.name)\"", role: .destructive) {
                delete(board)
                boardToDelete = nil
            }
            Button("Cancelar", role: .cancel) { boardToDelete = nil }
        } message: { board in
            Text("O quadro \"\(board.name)\" será movido para o Lixo. Os demais quadros não são afetados.")
        }
        .onChange(of: library.selectedID) { _, newID in
            renamingID = nil
            if let newID, let board = library.boards.first(where: { $0.id == newID }) {
                editor.loadBoard(board)
            }
        }
    }

    // MARK: - Linhas

    @ViewBuilder
    private func row(_ board: Board) -> some View {
        if renamingID == board.id {
            TextField("Nome do quadro", text: $renameText)
                .textFieldStyle(.roundedBorder)
                .focused($renameFocused, equals: board.id)
                .onSubmit { commitRename(board) }
        } else {
            Label {
                Text(board.name)
                    .lineLimit(1)
            } icon: {
                Image(systemName: "square.on.square")
            }
        }
    }

    @ViewBuilder
    private func contextMenu(_ board: Board) -> some View {
        Button("Renomear") { beginRename(board) }
        Button("Duplicar") { duplicate(board) }
        Divider()
        Button("Excluir…", role: .destructive) { boardToDelete = board }
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button {
                library.createBoard()
            } label: {
                Label("Novo quadro", systemImage: "plus")
            }
            .buttonStyle(.borderless)

            Spacer()

            if let board = library.selectedBoard {
                Menu {
                    Button("Renomear") { beginRename(board) }
                    Button("Duplicar") { duplicate(board) }
                    Divider()
                    Button("Excluir…", role: .destructive) { boardToDelete = board }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .padding(10)
        .background(.bar)
    }

    // MARK: - Ações

    private func beginRename(_ board: Board) {
        renameText = board.name
        renamingID = board.id
        renameFocused = board.id
    }

    private func commitRename(_ board: Board) {
        library.rename(board, to: renameText)
        renamingID = nil
    }

    private func duplicate(_ board: Board) {
        Task {
            if board.id == library.selectedID {
                await editor.flushAndWait()
            }
            library.flushSaves()
            library.duplicate(board)
        }
    }

    private func delete(_ board: Board) {
        Task {
            if board.id == library.selectedID {
                await editor.flushAndWait()
            }
            library.flushSaves()
            library.delete(board)
        }
    }

    private var deleteConfirmation: Binding<Bool> {
        Binding(
            get: { boardToDelete != nil },
            set: { if !$0 { boardToDelete = nil } }
        )
    }
}
