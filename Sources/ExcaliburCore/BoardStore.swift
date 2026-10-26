import Foundation

/// Quadros em disco, um por pasta:
///
///     <raiz>/boards.json                 índice (nome, datas, ordem)
///     <raiz>/Boards/<id>/scene.excalidraw cena sem imagens (JSON do editor)
///     <raiz>/Boards/<id>/files/<fid>.json  uma imagem por arquivo, gravada uma vez
///
/// Toda escrita é atômica (arquivo temporário + troca), então um quadro nunca
/// fica pela metade. Seguro para uso de várias threads.
public final class BoardStore: @unchecked Sendable {
    public let root: URL
    private let fileManager: FileManager
    private let usesTrash: Bool
    private let lock = NSLock()
    private var _boards: [Board] = []

    private static let sceneFileName = "scene.excalidraw"
    private static let filesFolderName = "files"

    /// - Parameter usesTrash: quadros excluídos vão para o Lixo (`false` apaga
    ///   de vez, para testes).
    public init(root: URL, fileManager: FileManager = .default, usesTrash: Bool = true) throws {
        self.root = root
        self.fileManager = fileManager
        self.usesTrash = usesTrash
        try fileManager.createDirectory(at: boardsFolder, withIntermediateDirectories: true)
        _boards = try loadIndex()
    }

    /// Os quadros na ordem de criação.
    public var boards: [Board] {
        lock.withLock { _boards }
    }

    public func board(id: String) -> Board? {
        lock.withLock { _boards.first { $0.id == id } }
    }

    // MARK: - Quadros

    @discardableResult
    public func create(name: String) throws -> Board {
        let board = Board(name: try Self.validatedName(name))
        try lock.withLock {
            try fileManager.createDirectory(at: filesFolder(board.id), withIntermediateDirectories: true)
            _boards.append(board)
            try writeIndex()
        }
        return board
    }

    public func rename(id: String, to name: String) throws {
        let name = try Self.validatedName(name)
        try lock.withLock {
            let index = try indexOf(id)
            _boards[index].name = name
            try writeIndex()
        }
    }

    /// Copia cena e imagens: a cópia é independente do original.
    @discardableResult
    public func duplicate(id: String, name: String) throws -> Board {
        let name = try Self.validatedName(name)
        return try lock.withLock {
            let index = try indexOf(id)
            let copy = Board(name: name)
            try fileManager.copyItem(at: folder(id), to: folder(copy.id))
            _boards.insert(copy, at: index + 1)
            try writeIndex()
            return copy
        }
    }

    /// Manda a pasta do quadro para o Lixo (dá para recuperar pelo Finder);
    /// os outros quadros não são tocados.
    public func delete(id: String) throws {
        try lock.withLock {
            let index = try indexOf(id)
            let url = folder(id)
            if fileManager.fileExists(atPath: url.path) {
                if usesTrash, (try? fileManager.trashItem(at: url, resultingItemURL: nil)) != nil {
                    // no Lixo
                } else {
                    try fileManager.removeItem(at: url)
                }
            }
            _boards.remove(at: index)
            try writeIndex()
        }
    }

    // MARK: - Conteúdo

    /// Cena e imagens do quadro. Imagens que nenhum elemento usa mais (nem os
    /// apagados, que o desfazer ainda alcança) são removidas aqui.
    public func loadContent(id: String) throws -> BoardContent {
        try lock.withLock {
            _ = try indexOf(id)
            let sceneURL = folder(id).appendingPathComponent(Self.sceneFileName)
            let scene = fileManager.fileExists(atPath: sceneURL.path)
                ? try String(contentsOf: sceneURL, encoding: .utf8)
                : nil
            let referenced = scene.map(SceneInspector.referencedFileIDs) ?? []
            var files: [Data] = []
            let folder = filesFolder(id)
            let urls = (try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            for url in urls where url.pathExtension == "json" {
                let fileID = url.deletingPathExtension().lastPathComponent
                if scene != nil, !referenced.contains(fileID) {
                    try? fileManager.removeItem(at: url)
                    continue
                }
                if let data = try? Data(contentsOf: url) {
                    files.append(data)
                }
            }
            return BoardContent(scene: scene, files: files)
        }
    }

    /// Grava a cena e as imagens novas (uma imagem nunca muda depois de
    /// inserida, então uma já gravada não é reescrita).
    public func save(id: String, scene: String, files: [Data]) throws {
        let validated = try files.map { data -> (String, Data) in
            (try Self.fileID(of: data), data)
        }
        try lock.withLock {
            let index = try indexOf(id)
            let folder = filesFolder(id)
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            for (fileID, data) in validated {
                let url = folder.appendingPathComponent("\(fileID).json")
                if !fileManager.fileExists(atPath: url.path) {
                    try data.write(to: url, options: .atomic)
                }
            }
            try Data(scene.utf8).write(
                to: self.folder(id).appendingPathComponent(Self.sceneFileName),
                options: .atomic
            )
            _boards[index].updatedAt = Date()
            try writeIndex()
        }
    }

    // MARK: - Validação

    static func validatedName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw BoardStoreError.invalidName }
        return String(trimmed.prefix(120))
    }

    /// O id de uma imagem vira nome de arquivo: só ids seguros passam.
    static func fileID(of data: Data) throws -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BoardStoreError.invalidFile("não é um objeto JSON")
        }
        guard let id = object["id"] as? String, Board.isSafeIdentifier(id) else {
            throw BoardStoreError.invalidFile("id ausente ou inválido")
        }
        guard object["dataURL"] is String else {
            throw BoardStoreError.invalidFile("sem conteúdo")
        }
        return id
    }

    // MARK: - Caminhos e índice

    private var boardsFolder: URL { root.appendingPathComponent("Boards", isDirectory: true) }
    private var indexURL: URL { root.appendingPathComponent("boards.json") }

    private func folder(_ id: String) -> URL {
        boardsFolder.appendingPathComponent(id, isDirectory: true)
    }

    private func filesFolder(_ id: String) -> URL {
        folder(id).appendingPathComponent(Self.filesFolderName, isDirectory: true)
    }

    private func indexOf(_ id: String) throws -> Int {
        guard Board.isSafeIdentifier(id) else { throw BoardStoreError.invalidIdentifier(id) }
        guard let index = _boards.firstIndex(where: { $0.id == id }) else {
            throw BoardStoreError.boardNotFound(id)
        }
        return index
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private func writeIndex() throws {
        try Self.encoder.encode(_boards).write(to: indexURL, options: .atomic)
    }

    /// Lê o índice; pastas de quadro que ele não conhece (índice perdido ou
    /// corrompido) voltam como "Quadro recuperado", sem perder conteúdo.
    private func loadIndex() throws -> [Board] {
        var boards: [Board] = []
        if let data = try? Data(contentsOf: indexURL),
           let decoded = try? Self.decoder.decode([Board].self, from: data) {
            boards = decoded.filter { Board.isSafeIdentifier($0.id) }
        }
        let known = Set(boards.map(\.id))
        let folders = (try? fileManager.contentsOfDirectory(
            at: boardsFolder,
            includingPropertiesForKeys: [.creationDateKey]
        )) ?? []
        let orphans = folders
            .filter { Board.isSafeIdentifier($0.lastPathComponent) && !known.contains($0.lastPathComponent) }
            .map { url -> Board in
                let created = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
                return Board(id: url.lastPathComponent, name: "Quadro recuperado", createdAt: created)
            }
            .sorted { $0.createdAt < $1.createdAt }
        // quadros do índice cuja pasta sumiu ficam (abrem vazios) — melhor que sumirem da lista
        if !orphans.isEmpty {
            boards += orphans
            _boards = boards
            try writeIndex()
        }
        return boards
    }
}
