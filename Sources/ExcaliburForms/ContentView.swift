import AppKit
import SwiftUI

/// Janela principal: lista de quadros + editor, barra de ferramentas com as
/// ferramentas e menus de exportação/apariência.
struct ContentView: View {
    @EnvironmentObject private var library: BoardLibrary
    @EnvironmentObject private var editor: EditorController

    @AppStorage("appearance") private var appearance: Appearance = .system

    var body: some View {
        NavigationSplitView {
            BoardList()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            EditorView(webView: editor.webView)
                .navigationTitle(library.selectedBoard?.name ?? "ExcaliburForms")
        }
        .frame(minWidth: 900, minHeight: 560)
        .toolbar { toolbarContent }
        .alert(
            "ExcaliburForms",
            isPresented: errorPresented
        ) {
            Button("OK", role: .cancel) { editor.lastError = nil }
        } message: {
            Text(editor.lastError ?? "")
        }
        .preferredColorScheme(colorScheme)
        .onAppear { applyAppearance() }
        .onChange(of: appearance) { _, _ in applyAppearance() }
    }

    // MARK: - Barra de ferramentas

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .principal) {
            toolsBar
        }
        ToolbarItemGroup(placement: .primaryAction) {
            exportMenu
            appearanceMenu
        }
    }

    private var toolsBar: some View {
        HStack(spacing: 2) {
            toolButton(.selection)
            toolButton(.hand)
            Divider()
            toolButton(.image)
            toolButton(.text)
            toolButton(.highlight)
            toolButton(.stickynote)
            Divider()
            shapesMenu
            toolButton(.arrow)
            toolButton(.freedraw)
        }
    }

    private func toolButton(_ tool: Tool) -> some View {
        Button {
            editor.setTool(tool)
        } label: {
            Image(systemName: tool.systemImage)
                .frame(minWidth: 24)
        }
        .help(tool.label)
        .buttonStyle(.borderless)
        .background(editor.activeTool == tool ? Color.accentColor.opacity(0.25) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private var shapesMenu: some View {
        Menu {
            ForEach([Tool.rectangle, .ellipse, .diamond, .line]) { tool in
                Button {
                    editor.setTool(tool)
                } label: {
                    Label(tool.label, systemImage: tool.systemImage)
                }
            }
        } label: {
            Image(systemName: "square.on.circle")
                .frame(minWidth: 24)
        }
        .help("Formas")
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var exportMenu: some View {
        Menu {
            Button("Copiar imagem (PNG)") {
                ExportService.copyPNG(editor)
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            Divider()
            ForEach(ExportFormat.allCases) { format in
                Menu(format.label) {
                    ForEach([ExportScope.board, .selection, .viewport]) { scope in
                        Button(scope.label) {
                            ExportService.export(editor, format: format, scope: scope)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .help("Exportar")
    }

    private var appearanceMenu: some View {
        Menu {
            ForEach(Appearance.allCases) { mode in
                Button {
                    appearance = mode
                } label: {
                    if appearance == mode {
                        Label(mode.label, systemImage: "checkmark")
                    } else {
                        Text(mode.label)
                    }
                }
            }
        } label: {
            Image(systemName: appearanceSymbol)
        }
        .help("Aparência")
    }

    // MARK: - Aparência

    private func applyAppearance() {
        editor.setTheme(resolvedEditorTheme)
    }

    private var resolvedEditorTheme: EditorTheme {
        switch appearance {
        case .light: return .light
        case .dark: return .dark
        case .system:
            let match = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
            return match == .darkAqua ? .dark : .light
        }
    }

    private var colorScheme: ColorScheme? {
        switch appearance {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    private var appearanceSymbol: String {
        switch appearance {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { editor.lastError != nil },
            set: { if !$0 { editor.lastError = nil } }
        )
    }
}
