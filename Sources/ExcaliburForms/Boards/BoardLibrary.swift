import ExcaliburCore
import Foundation
import SwiftUI

/// Lista de quadros da janela: estado observável sobre o `BoardStore`.
/// Gravações da cena vão para uma fila própria, fora da thread principal.
@MainActor
final class BoardLibrary: ObservableObject {
    @Published private(set) var boards: [Board] = []
    @Published var selectedID: Board.ID? {
        didSet {
            if let selectedID { UserDefaults.standard.set(selectedID, forKey: Self.lastBoardKey) }
        }
    }
    @Published var errorMessage: String?

    var store: BoardStore?
    private let saveQueue = DispatchQueue(label: "ExcaliburForms.save", qos: .userInitiated)
    private static let lastBoardKey = "lastBoardID"

    init(root: URL = BoardLibrary.defaultRoot) {
        do {
            let store = try BoardStore(root: root)
            self.store = store
            if store.boards.isEmpty {
                try store.create(name: "Meu primeiro quadro")
            }
            boards = store.boards
            let last = UserDefaults.standard.string(forKey: Self.lastBoardKey)
            selectedID = boards.first { $0.id == last }?.id ?? boards.first?.id
        } catch {
            store = nil
            errorMessage = "Não foi possível abrir a pasta dos quadros: \(error.localizedDescription)"
        }
    }

    nonisolated static var defaultRoot: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("ExcaliburForms", isDirectory: true)
    }

    var selectedBoard: Board? {
        boards.first { $0.id == selectedID }
    }

    // MARK: - Ações da lista

    func createBoard() {
        perform {
            let board = try $0.create(name: nextName(base: "Quadro"))
            selectedID = board.id
        }
    }

    func rename(_ board: Board, to name: String) {
        perform { try $0.rename(id: board.id, to: name) }
    }

    func duplicate(_ board: Board) {
        // a cena pendente do quadro aberto precisa estar no disco antes da cópia
        flushSaves()
        perform {
            let copy = try $0.duplicate(id: board.id, name: nextName(base: "\(board.name) (cópia)"))
            selectedID = copy.id
        }
    }

    func delete(_ board: Board) {
        let index = boards.firstIndex(of: board) ?? 0
        flushSaves()
        perform {
            try $0.delete(id: board.id)
            if $0.boards.isEmpty {
                try $0.create(name: "Quadro")
            }
            let remaining = $0.boards
            if selectedID == board.id {
                selectedID = remaining[min(index, remaining.count - 1)].id
            }
        }
    }

    // MARK: - Conteúdo

    func loadContent(_ id: Board.ID) -> BoardContent? {
        guard let store else { return nil }
        do {
            return try store.loadContent(id: id)
        } catch {
            errorMessage = "Não foi possível abrir o quadro: \(error.localizedDescription)"
            return nil
        }
    }

    /// Grava fora da thread principal, na ordem de chegada.
    func save(id: Board.ID, scene: String, files: [Data]) {
        guard let store else { return }
        saveQueue.async { [weak self] in
            do {
                try store.save(id: id, scene: scene, files: files)
                let boards = store.boards
                Task { @MainActor in self?.boards = boards }
            } catch {
                Task { @MainActor in
                    self?.errorMessage = "Não foi possível salvar o quadro: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Espera as gravações pendentes (antes de copiar, excluir ou sair).
    func flushSaves() {
        saveQueue.sync {}
    }

    // MARK: - Auxiliares

    private func perform(_ body: (BoardStore) throws -> Void) {
        guard let store else { return }
        do {
            try body(store)
        } catch {
            errorMessage = error.localizedDescription
        }
        boards = store.boards
    }

    /// "Quadro", "Quadro 2", "Quadro 3"… sem repetir nomes da lista.
    private func nextName(base: String) -> String {
        let names = Set(boards.map(\.name))
        guard names.contains(base) else { return base }
        var number = 2
        while names.contains("\(base) \(number)") { number += 1 }
        return "\(base) \(number)"
    }
}
