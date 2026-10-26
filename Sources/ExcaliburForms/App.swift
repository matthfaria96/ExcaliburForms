import AppKit
import SwiftUI

@main
struct ExcaliburFormsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var library: BoardLibrary
    @StateObject private var editor: EditorController
    @StateObject private var ui = WorkspaceUI()

    init() {
        let library = BoardLibrary()
        let editor = EditorController(library: library)
        _library = StateObject(wrappedValue: library)
        _editor = StateObject(wrappedValue: editor)
    }

    var body: some Scene {
        Window("ExcaliburForms", id: "main") {
            ContentView()
                .environmentObject(library)
                .environmentObject(editor)
                .environmentObject(ui)
                .onAppear {
                    appDelegate.library = library
                    appDelegate.editor = editor
                }
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1240, height: 800)
        .commands {
            fileCommands
            editCommands
            viewCommands
            arrangeCommands
            helpCommands
        }

        Settings {
            SettingsView()
        }
    }
}

// MARK: - Menus

extension ExcaliburFormsApp {
    /// Arquivo: quadros e exportação.
    @CommandsBuilder
    private var fileCommands: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Novo Quadro") { library.createBoard() }
                .keyboardShortcut("n")
            Button("Duplicar Quadro") {
                if let board = library.selectedBoard {
                    BoardActions.duplicate(board, library: library, editor: editor)
                }
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
            Button("Renomear Quadro…") {
                if let board = library.selectedBoard { ui.beginRename(board) }
            }
            Divider()
            Button("Excluir Quadro…") { ui.boardToDelete = library.selectedBoard }
                .keyboardShortcut(.delete, modifiers: [.command, .option])
        }
        CommandGroup(replacing: .importExport) {
            Button("Copiar como Imagem") { ExportService.copyPNG(editor) }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            Button("Exportar como PNG…") { export(.png, .auto) }
                .keyboardShortcut("e")
            Button("Exportar como SVG…") { export(.svg, .auto) }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            Menu("Exportar Área Visível") {
                Button("PNG…") { export(.png, .viewport) }
                Button("SVG…") { export(.svg, .viewport) }
            }
        }
    }

    private func export(_ format: ExportFormat, _ scope: ExportScope) {
        ExportService.export(
            editor,
            format: format,
            scope: scope,
            suggestedName: library.selectedBoard?.name ?? "Quadro"
        )
    }

    /// Editar: desfazer/refazer do editor (o ⌘Z chega primeiro à página).
    @CommandsBuilder
    private var editCommands: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button("Desfazer") { editor.command(.undo) }
                .keyboardShortcut("z")
            Button("Refazer") { editor.command(.redo) }
                .keyboardShortcut("z", modifiers: [.command, .shift])
        }
        CommandGroup(after: .pasteboard) {
            Button("Duplicar") { editor.command(.duplicate) }
                .keyboardShortcut("d")
        }
    }

    /// Visualizar: painéis, zoom e guias.
    @CommandsBuilder
    private var viewCommands: some Commands {
        CommandGroup(before: .toolbar) {
            Button(ui.panelVisible && ui.panelTab == .boards ? "Ocultar Quadros" : "Mostrar Quadros") {
                ui.show(.boards)
            }
            .keyboardShortcut("s", modifiers: [.command, .control])
            Button(ui.panelVisible && ui.panelTab == .layers ? "Ocultar Camadas" : "Mostrar Camadas") {
                ui.show(.layers)
            }
            .keyboardShortcut("l", modifiers: [.command, .control])
            Divider()
            Button("Aproximar") { editor.command(.zoomIn) }
                .keyboardShortcut("+")
            Button("Afastar") { editor.command(.zoomOut) }
                .keyboardShortcut("-")
            Button("Tamanho Real") { editor.command(.resetZoom) }
                .keyboardShortcut("0")
            Button("Ajustar ao Conteúdo") { editor.command(.zoomToFit) }
                .keyboardShortcut("1", modifiers: [.command, .shift])
            Button("Ajustar à Seleção") { editor.command(.zoomToSelection) }
                .keyboardShortcut("2", modifiers: [.command, .shift])
            Divider()
            Button("Grade") { editor.command(.toggleGrid) }
                .keyboardShortcut("'", modifiers: [.command])
            Button("Alinhar a Objetos") { editor.command(.toggleSnap) }
            Divider()
        }
    }

    /// Organizar (como no Keynote e no Freeform): camadas, bloqueio, grupos.
    @CommandsBuilder
    private var arrangeCommands: some Commands {
        CommandMenu("Organizar") {
            Button("Trazer para a Frente") { editor.command(.bringToFront) }
                .keyboardShortcut("]", modifiers: [.command, .shift])
            Button("Trazer para Frente") { editor.command(.bringForward) }
                .keyboardShortcut("]")
            Button("Enviar para Trás") { editor.command(.sendBackward) }
                .keyboardShortcut("[")
            Button("Enviar para o Fundo") { editor.command(.sendToBack) }
                .keyboardShortcut("[", modifiers: [.command, .shift])
            Divider()
            Button("Agrupar") { editor.command(.group) }
                .keyboardShortcut("g")
            Button("Desagrupar") { editor.command(.ungroup) }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            Divider()
            Button(editor.selectionLocked ? "Desbloquear" : "Bloquear") { editor.command(.toggleLock) }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            Button("Desbloquear Tudo") { editor.command(.unlockAll) }
            Divider()
            Button("Recortar Imagem") { editor.command(.crop) }
                .disabled(!editor.selectionTypes.contains("image"))
        }
    }

    @CommandsBuilder
    private var helpCommands: some Commands {
        CommandGroup(replacing: .help) {
            Button("Atalhos de Teclado") { editor.command(.shortcuts) }
                .keyboardShortcut("/", modifiers: [.command])
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
