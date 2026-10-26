import AppKit
import Foundation
import UniformTypeIdentifiers

/// Copiar e salvar as exportações do editor (PNG/SVG) no formato do macOS.
@MainActor
enum ExportService {
    /// Copia o PNG (seleção quando houver, senão o quadro) para a área de
    /// transferência — atalho ⌘⇧C.
    static func copyPNG(_ editor: EditorController) {
        Task {
            do {
                let image = try await editor.exportImage(format: .png, scope: .auto)
                putOnPasteboard(image)
            } catch {
                editor.lastError = "Não foi possível copiar a imagem: \(error.localizedDescription)"
            }
        }
    }

    /// Exporta para um arquivo escolhido pelo usuário.
    static func export(_ editor: EditorController, format: ExportFormat, scope: ExportScope) {
        Task {
            do {
                let image = try await editor.exportImage(format: format, scope: scope)
                save(image, format: format)
            } catch {
                editor.lastError = "Não foi possível exportar: \(error.localizedDescription)"
            }
        }
    }

    private static func putOnPasteboard(_ image: ExportedImage) {
        guard let nsImage = NSImage(data: image.data) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([nsImage])
    }

    private static func save(_ image: ExportedImage, format: ExportFormat) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format == .png ? .png : .svg]
        panel.nameFieldStringValue = "Quadro.\(format == .png ? "png" : "svg")"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try image.data.write(to: url, options: .atomic)
        } catch {
            // melhor esforço: o painel já foi fechado
        }
    }
}
