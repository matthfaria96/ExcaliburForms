import AppKit
import SwiftUI

@main
struct ExcaliburFormsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var library: BoardLibrary
    @StateObject private var editor: EditorController

    init() {
        let library = BoardLibrary()
        let editor = EditorController(library: library)
        _library = StateObject(wrappedValue: library)
        _editor = StateObject(wrappedValue: editor)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
                .environmentObject(editor)
                .onAppear {
                    appDelegate.library = library
                    appDelegate.editor = editor
                }
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1200, height: 760)
        .commands {
            boardCommands
            layerCommands
            viewCommands
            exportCommands
        }
    }
}

// MARK: - Menus

extension ExcaliburFormsApp {
    @CommandsBuilder
    private var boardCommands: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Novo Quadro") {
                library.createBoard()
            }
            .keyboardShortcut("n")
        }
        CommandMenu("Quadro") {
            Button("Duplicar Quadro") {
                duplicateSelectedBoard()
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
            Divider()
            Button("Excluir Quadro…") {
                deleteSelectedBoard()
            }
        }
    }

    @CommandsBuilder
    private var layerCommands: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button("Desfazer") { editor.command(.undo) }
                .keyboardShortcut("z")
            Button("Refazer") { editor.command(.redo) }
                .keyboardShortcut("z", modifiers: [.command, .shift])
        }
        CommandMenu("Camada") {
            Button("Trazer para frente") { editor.command(.bringForward) }
                .keyboardShortcut("]", modifiers: [.command])
            Button("Enviar para trás") { editor.command(.sendBackward) }
                .keyboardShortcut("[", modifiers: [.command])
            Button("Trazer para a frente de tudo") { editor.command(.bringToFront) }
                .keyboardShortcut("]", modifiers: [.command, .shift])
            Button("Enviar para trás de tudo") { editor.command(.sendToBack) }
                .keyboardShortcut("[", modifiers: [.command, .shift])
            Divider()
            Button("Bloquear/Desbloquear") { editor.command(.toggleLock) }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            Button("Desbloquear tudo") { editor.command(.unlockAll) }
            Divider()
            Button("Agrupar") { editor.command(.group) }
                .keyboardShortcut("g")
            Button("Desagrupar") { editor.command(.ungroup) }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            Divider()
            Button("Duplicar seleção") { editor.command(.duplicate) }
                .keyboardShortcut("d")
            Button("Recortar") { editor.command(.crop) }
        }
    }

    @CommandsBuilder
    private var viewCommands: some Commands {
        CommandMenu("Visualizar") {
            Button("Aproximar") { editor.command(.zoomIn) }
                .keyboardShortcut("+")
            Button("Afastar") { editor.command(.zoomOut) }
                .keyboardShortcut("-")
            Button("Zoom 100%") { editor.command(.resetZoom) }
                .keyboardShortcut("0")
            Button("Ajustar ao quadro") { editor.command(.zoomToFit) }
                .keyboardShortcut("0", modifiers: [.command, .option])
            Divider()
            Button("Mostrar grade") { editor.command(.toggleGrid) }
            Button("Ajustar a objetos") { editor.command(.toggleSnap) }
        }
    }

    @CommandsBuilder
    private var exportCommands: some Commands {
        CommandMenu("Exportar") {
            Menu("PNG") {
                Button("Quadro inteiro") { ExportService.export(editor, format: .png, scope: .board) }
                Button("Seleção") { ExportService.export(editor, format: .png, scope: .selection) }
                Button("Área visível") { ExportService.export(editor, format: .png, scope: .viewport) }
            }
            Menu("SVG") {
                Button("Quadro inteiro") { ExportService.export(editor, format: .svg, scope: .board) }
                Button("Seleção") { ExportService.export(editor, format: .svg, scope: .selection) }
                Button("Área visível") { ExportService.export(editor, format: .svg, scope: .viewport) }
            }
            Divider()
            Button("Exportar PNG (quadro)…") {
                ExportService.export(editor, format: .png, scope: .board)
            }
            .keyboardShortcut("e")
            Button("Copiar imagem (PNG)") {
                ExportService.copyPNG(editor)
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
        }
    }

    // MARK: - Ações do menu Quadro

    private func duplicateSelectedBoard() {
        guard let board = library.selectedBoard else { return }
        Task {
            await editor.flushAndWait()
            library.flushSaves()
            library.duplicate(board)
        }
    }

    private func deleteSelectedBoard() {
        guard let board = library.selectedBoard else { return }
        Task {
            await editor.flushAndWait()
            library.flushSaves()
            library.delete(board)
        }
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var library: BoardLibrary?
    weak var editor: EditorController?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated {
            editor?.flush()
            library?.flushSaves()
        }
    }
}
