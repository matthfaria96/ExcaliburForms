import Foundation
import SwiftUI

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

/// Cor de fundo do marca-texto que a ferramenta texto usa por padrão.
struct HighlightColor: Identifiable, Equatable {
    let hex: String
    let name: String
    var id: String { hex }

    static let options: [HighlightColor] = [
        HighlightColor(hex: "#ffe600", name: "Amarelo"),
        HighlightColor(hex: "#00e5ff", name: "Ciano"),
        HighlightColor(hex: "#00e676", name: "Verde"),
        HighlightColor(hex: "#ff4fd8", name: "Rosa"),
        HighlightColor(hex: "#b45cff", name: "Roxo"),
    ]

    static let defaultHex = "#ffe600"
}

/// Cor padrão do texto (a cor do traço que a ferramenta texto usa).
struct TextColor: Identifiable, Equatable {
    let hex: String
    let name: String
    var id: String { hex }

    static let options: [TextColor] = [
        TextColor(hex: "#1e1e1e", name: "Preto"),
        TextColor(hex: "#ff3b30", name: "Vermelho"),
        TextColor(hex: "#ff9500", name: "Laranja"),
        TextColor(hex: "#ffcc00", name: "Amarelo"),
        TextColor(hex: "#34c759", name: "Verde"),
        TextColor(hex: "#32ade6", name: "Ciano"),
        TextColor(hex: "#007aff", name: "Azul"),
        TextColor(hex: "#af52de", name: "Roxo"),
        TextColor(hex: "#ff2d55", name: "Rosa"),
    ]

    static let defaultHex = "#1e1e1e"
}

/// Uma camada (elemento) do quadro, para o painel de camadas.
struct LayerItem: Identifiable, Equatable {
    let id: String
    let label: String
    let type: String
    let selected: Bool

    var icon: String {
        switch type {
        case "text": return "textformat"
        case "image": return "photo"
        case "rectangle": return "rectangle"
        case "ellipse": return "circle"
        case "diamond": return "diamond"
        case "arrow": return "arrow.up.right"
        case "line": return "line.diagonal"
        case "freedraw": return "scribble"
        case "stickynote": return "note.text"
        case "frame": return "rectangle.dashed"
        case "embeddable": return "globe"
        default: return "square"
        }
    }
}

/// Propriedades da nota adesiva selecionada (painel da direita).
struct StickySelection: Equatable {
    var backgroundColor: String
    var fontSize: Double
}

/// Cores de fundo da nota adesiva.
struct StickyColor: Identifiable, Equatable {
    let hex: String
    let name: String
    var id: String { hex }

    static let options: [StickyColor] = [
        StickyColor(hex: "#ffd93d", name: "Amarelo"),
        StickyColor(hex: "#ff6fa5", name: "Rosa"),
        StickyColor(hex: "#5ce65c", name: "Verde"),
        StickyColor(hex: "#4cc3ff", name: "Azul"),
        StickyColor(hex: "#ffa14a", name: "Laranja"),
    ]
}

/// Propriedades do texto selecionado, lidas do editor para o painel da direita.
struct TextSelection: Equatable {
    var fontSize: Double
    var fontWeight: String
    var textAlign: String
    var highlighted: Bool
    var backgroundColor: String
    var strokeColor: String

    static let sizes: [Double] = [16, 20, 28, 36]
    static let sizeLabels: [Double: String] = [16: "S", 20: "M", 28: "L", 36: "XL"]
}

extension Color {
    init(hexString: String) {
        let cleaned = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255
        )
    }
}
