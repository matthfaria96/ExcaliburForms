import AppKit
import Foundation
import UniformTypeIdentifiers

/// Preferências de exportação (Ajustes › Geral).
enum ExportSettings {
    static let scaleKey = "exportScale"
    static let backgroundKey = "exportBackground"

    /// Densidade do PNG: 1×, 2× (padrão) ou 3×.
    static var scale: Double {
        let value = UserDefaults.standard.double(forKey: scaleKey)
        return value > 0 ? value : 2
    }

    /// Pintar a cor do canvas atrás do conteúdo (desligado = fundo transparente).
    static var includesBackground: Bool {
        UserDefaults.standard.object(forKey: backgroundKey) as? Bool ?? true
    }
}

/// Copiar e salvar as exportações do editor (PNG/SVG) no formato do macOS.
@MainActor
enum ExportService {
    /// Copia o PNG (seleção quando houver, senão o quadro) — atalho ⌘⇧C.
    static func copyPNG(_ editor: EditorController) {
        Task {
            do {
                let image = try await editor.exportImage(format: .png, scope: .auto)
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                // PNG de verdade (preserva transparência); TIFF fica de reserva
                pasteboard.setData(image.data, forType: .png)
                if let tiff = NSImage(data: image.data)?.tiffRepresentation {
                    pasteboard.setData(tiff, forType: .tiff)
                }
            } catch {
                editor.lastError = "Não foi possível copiar a imagem: \(error.localizedDescription)"
            }
        }
    }

    /// Exporta para um arquivo escolhido pelo usuário (folha da janela).
    static func export(
        _ editor: EditorController,
        format: ExportFormat,
        scope: ExportScope,
        suggestedName: String = "Quadro"
    ) {
        Task {
            do {
                let image = try await editor.exportImage(format: format, scope: scope)
                save(image, format: format, name: suggestedName, editor: editor)
            } catch {
                editor.lastError = "Não foi possível exportar: \(error.localizedDescription)"
            }
        }
    }

    private static func save(
        _ image: ExportedImage,
        format: ExportFormat,
        name: String,
        editor: EditorController
    ) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format == .png ? .png : .svg]
        let safeName = name.replacingOccurrences(of: "/", with: "-")
        panel.nameFieldStringValue = "\(safeName).\(format.rawValue)"
        panel.canCreateDirectories = true
        let write: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try image.data.write(to: url, options: .atomic)
            } catch {
                editor.lastError = "Não foi possível salvar o arquivo: \(error.localizedDescription)"
            }
        }
        if let window = editor.webView.window {
            panel.beginSheetModal(for: window, completionHandler: write)
        } else {
            write(panel.runModal())
        }
    }
}
