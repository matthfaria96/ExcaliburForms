import Foundation

/// Um quadro: a entrada da lista lateral. O conteúdo (cena e imagens) fica na
/// pasta do quadro, gerida pelo `BoardStore`.
public struct Board: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public var name: String
    public let createdAt: Date
    public var updatedAt: Date

    public init(id: String = Board.newID(), name: String, createdAt: Date = Date(), updatedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    public static func newID() -> String {
        UUID().uuidString.lowercased()
    }

    /// Ids de quadro e de arquivo viram nomes de pasta e de arquivo: só
    /// letras, dígitos, `-` e `_` (nada de `/` ou `..`).
    public static func isSafeIdentifier(_ value: String) -> Bool {
        !value.isEmpty
            && value.count <= 128
            && value.unicodeScalars.allSatisfy { scalar in
                CharacterSet.alphanumerics.contains(scalar) && scalar.isASCII
                    || scalar == "-" || scalar == "_"
            }
    }
}

/// O conteúdo de um quadro como o editor o recebe e devolve.
public struct BoardContent: Equatable, Sendable {
    /// JSON `.excalidraw` sem as imagens; `nil` num quadro novo.
    public var scene: String?
    /// Imagens (`BinaryFileData` do editor), cada uma um objeto JSON.
    public var files: [Data]

    public init(scene: String?, files: [Data]) {
        self.scene = scene
        self.files = files
    }
}

public enum BoardStoreError: LocalizedError, Equatable {
    case boardNotFound(String)
    case invalidIdentifier(String)
    case invalidName
    case invalidFile(String)

    public var errorDescription: String? {
        switch self {
        case .boardNotFound:
            return "O quadro não existe mais."
        case .invalidIdentifier:
            return "Identificador inválido."
        case .invalidName:
            return "O nome do quadro não pode ficar vazio."
        case let .invalidFile(reason):
            return "Imagem inválida: \(reason)."
        }
    }
}
