import Foundation

/// Ferramentas expostas na barra nativa. Os `rawValue` são os mesmos ids de
/// `excalibur-web/src/tools.ts`, para a ponte não precisar de tradução.
enum Tool: String, CaseIterable, Identifiable, Sendable {
    case selection
    case hand
    case image
    case text
    case stickynote
    case rectangle
    case ellipse
    case diamond
    case arrow
    case line
    case freedraw
    case eraser

    var id: String { rawValue }

    var label: String {
        switch self {
        case .selection: return "Seleção"
        case .hand: return "Mão"
        case .image: return "Imagem"
        case .text: return "Texto"
        case .stickynote: return "Nota"
        case .rectangle: return "Retângulo"
        case .ellipse: return "Elipse"
        case .diamond: return "Losango"
        case .arrow: return "Seta"
        case .line: return "Linha"
        case .freedraw: return "Desenho"
        case .eraser: return "Borracha"
        }
    }

    var systemImage: String {
        switch self {
        case .selection: return "cursorarrow"
        case .hand: return "hand.raised"
        case .image: return "photo"
        case .text: return "textformat"
        case .stickynote: return "note.text"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .diamond: return "diamond"
        case .arrow: return "arrow.up.right"
        case .line: return "line.diagonal"
        case .freedraw: return "scribble"
        case .eraser: return "eraser"
        }
    }

    /// Atalho do editor (exibido na dica de ferramenta), ou `nil` sem atalho.
    var shortcut: String? {
        switch self {
        case .selection: return "V"
        case .hand: return "H"
        case .image: return nil
        case .text: return "T"
        case .stickynote: return "N"
        case .rectangle: return "R"
        case .ellipse: return "O"
        case .diamond: return "D"
        case .arrow: return "A"
        case .line: return "L"
        case .freedraw: return "P"
        case .eraser: return nil
        }
    }
}

/// Comandos de menu que o editor executa como ações próprias (mesmos nomes do
/// mapa `COMMANDS` em `excalibur-web/src/index.tsx`).
enum Command: String, CaseIterable, Identifiable, Sendable {
    case undo
    case redo
    case zoomIn
    case zoomOut
    case resetZoom
    case zoomToFit
    case zoomToSelection
    case bringForward
    case sendBackward
    case bringToFront
    case sendToBack
    case toggleLock
    case unlockAll
    case crop
    case group
    case ungroup
    case duplicate
    case delete
    case selectAll
    case toggleGrid
    case toggleSnap

    var id: String { rawValue }

    var label: String {
        switch self {
        case .undo: return "Desfazer"
        case .redo: return "Refazer"
        case .zoomIn: return "Aproximar"
        case .zoomOut: return "Afastar"
        case .resetZoom: return "Zoom 100%"
        case .zoomToFit: return "Ajustar ao quadro"
        case .zoomToSelection: return "Ajustar à seleção"
        case .bringForward: return "Trazer para frente"
        case .sendBackward: return "Enviar para trás"
        case .bringToFront: return "Trazer para a frente de tudo"
        case .sendToBack: return "Enviar para trás de tudo"
        case .toggleLock: return "Bloquear/Desbloquear"
        case .unlockAll: return "Desbloquear tudo"
        case .crop: return "Recortar"
        case .group: return "Agrupar"
        case .ungroup: return "Desagrupar"
        case .duplicate: return "Duplicar seleção"
        case .delete: return "Apagar"
        case .selectAll: return "Selecionar tudo"
        case .toggleGrid: return "Mostrar grade"
        case .toggleSnap: return "Ajustar a objetos"
        }
    }
}

/// Aparência da janela (o editor recebe só claro/escuro, resolvido a partir
/// do tema do sistema quando for "Sistema").
enum Appearance: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Sistema"
        case .light: return "Claro"
        case .dark: return "Escuro"
        }
    }
}

/// Tema que o editor entende.
enum EditorTheme: String, Sendable {
    case light
    case dark
}

enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case png
    case svg

    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
}

/// `auto`: a seleção quando houver, senão o quadro inteiro.
enum ExportScope: String, CaseIterable, Identifiable, Sendable {
    case auto
    case board
    case selection
    case viewport

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: return "Seleção (ou quadro)"
        case .board: return "Quadro inteiro"
        case .selection: return "Seleção"
        case .viewport: return "Área visível"
        }
    }
}
