import AppKit
import SwiftUI

/// Janela principal: lista de quadros + editor, barra de ferramentas com as
/// ferramentas e menus de exportação/apariência.
struct ContentView: View {
    @EnvironmentObject private var library: BoardLibrary
    @EnvironmentObject private var editor: EditorController

    @AppStorage("appearance") private var appearance: Appearance = .system
    @State private var shapesHovering = false
    @State private var boardsVisible = true

    var body: some View {
        ZStack(alignment: .topLeading) {
            EditorView(webView: editor.webView)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // clicar fora fecha a lista de quadros
            if boardsVisible {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.smooth(duration: 0.28)) { boardsVisible = false }
                    }
                    .zIndex(1)
            }

            if boardsVisible {
                LeftPanel()
                    .frame(width: 250)
                    .frame(maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08))
                    )
                    .shadow(color: .black.opacity(0.16), radius: 16, y: 6)
                    .padding(.leading, 12)
                    .padding(.top, 52)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .zIndex(2)
            }

            // painel fixo de propriedades, à direita
            propertiesPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, 14)
                .padding(.top, 14)
                .opacity(showsProperties ? 1 : 0)
                .offset(x: showsProperties ? 0 : 14)
                .allowsHitTesting(showsProperties)
                .animation(.smooth(duration: 0.22), value: showsProperties)
                .zIndex(3)

            floatingBoardButton
                .padding(.leading, 12)
                .padding(.top, 12)
                .zIndex(4)
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

    private var showsProperties: Bool {
        editor.textSelection != nil || editor.activeTool == .text
    }

    /// Painel fixo de propriedades do texto, no canto direito.
    private var propertiesPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Texto")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Cor")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    ForEach(TextColor.options.prefix(7)) { option in
                        colorDot(option.hex, selected: editor.strokeColor == option.hex) {
                            editor.performAction("changeStrokeColor", value: ["color": option.hex])
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Marca-texto")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Sem grifo") {
                        editor.performAction("toggleTextHighlight", value: false)
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    ForEach(HighlightColor.options) { option in
                        colorDot(option.hex, selected: editor.highlightColor == option.hex) {
                            editor.performAction("toggleTextHighlight", value: true)
                            editor.performAction("changeBackgroundColor", value: ["color": option.hex])
                        }
                    }
                }
            }

            if let text = editor.textSelection {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tamanho")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        ForEach(TextSelection.sizes, id: \.self) { size in
                            sizeButton(size, current: text.fontSize)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Peso")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        weightButton("normal", label: "Normal", current: text.fontWeight)
                        weightButton("bold", label: "Negrito", current: text.fontWeight)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Alinhamento")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        alignButton("left", icon: "text.alignleft", current: text.textAlign)
                        alignButton("center", icon: "text.aligncenter", current: text.textAlign)
                        alignButton("right", icon: "text.alignright", current: text.textAlign)
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 220, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
        .shadow(color: .black.opacity(0.16), radius: 16, y: 6)
    }

    private func colorDot(_ hex: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Color(hexString: hex))
                Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                if selected {
                    Circle().strokeBorder(Color.accentColor, lineWidth: 2)
                }
            }
            .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
    }

    private func sizeButton(_ size: Double, current: Double) -> some View {
        Button {
            editor.performAction("changeFontSize", value: size)
        } label: {
            Text(TextSelection.sizeLabels[size] ?? "?")
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 32, height: 26)
                .background(chipBackground(current == size))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func weightButton(_ weight: String, label: String, current: String) -> some View {
        Button {
            editor.performAction("changeFontWeight", value: weight)
        } label: {
            Text(label)
                .font(.system(size: 11, weight: weight == "bold" ? .bold : .regular))
                .frame(maxWidth: .infinity)
                .frame(height: 26)
                .background(chipBackground(current == weight))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func alignButton(_ align: String, icon: String, current: String) -> some View {
        Button {
            editor.performAction("changeTextAlign", value: align)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: 26)
                .background(chipBackground(current == align))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func chipBackground(_ selected: Bool) -> Color {
        selected ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.06)
    }

    /// Botão flutuante no canto superior esquerdo que abre/fecha a lista de
    /// quadros (que flutua sobre o canvas, sem empurrar o conteúdo).
    private var floatingBoardButton: some View {
        Button {
            withAnimation(.smooth(duration: 0.28)) {
                boardsVisible.toggle()
            }
        } label: {
            Image(systemName: "sidebar.left")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial, in: Circle())
        .overlay(Circle().strokeBorder(Color.primary.opacity(0.1)))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        .help(boardsVisible ? "Ocultar quadros" : "Mostrar quadros")
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
        HStack(spacing: 4) {
            ToolButton(tool: .selection, isActive: editor.activeTool == .selection) {
                editor.setTool(.selection)
            }
            ToolButton(tool: .hand, isActive: editor.activeTool == .hand) {
                editor.setTool(.hand)
            }
            separator
            ToolButton(tool: .image, isActive: editor.activeTool == .image) {
                editor.setTool(.image)
            }
            ToolButton(tool: .text, isActive: editor.activeTool == .text) {
                editor.setTool(.text)
            }
            textColorSwatch
            highlightSwatch
            ToolButton(tool: .stickynote, isActive: editor.activeTool == .stickynote) {
                editor.setTool(.stickynote)
            }
            separator
            shapesMenu
            ToolButton(tool: .arrow, isActive: editor.activeTool == .arrow) {
                editor.setTool(.arrow)
            }
            ToolButton(tool: .freedraw, isActive: editor.activeTool == .freedraw) {
                editor.setTool(.freedraw)
            }
        }
    }

    private var separator: some View {
        Divider()
            .frame(height: 16)
            .padding(.horizontal, 3)
    }

    private var shapesActive: Bool {
        [Tool.rectangle, .ellipse, .diamond, .line].contains(editor.activeTool ?? .selection)
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
                .font(.system(size: 13, weight: .medium))
                .frame(width: 30, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(shapesBackground)
                )
                .foregroundStyle(shapesActive ? Color.accentColor : .secondary)
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .onHover { shapesHovering = $0 }
        .fixedSize()
        .help("Formas")
    }

    private var shapesBackground: Color {
        if shapesActive {
            return Color.accentColor.opacity(0.2)
        }
        if shapesHovering {
            return Color.primary.opacity(0.07)
        }
        return .clear
    }

    /// Cor padrão do texto (o traço): um ponto ao lado do ícone que abre o
    /// seletor de cores.
    private var textColorSwatch: some View {
        Menu {
            ForEach(TextColor.options) { option in
                Button {
                    editor.setStrokeColor(option.hex)
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hexString: option.hex))
                            .frame(width: 12, height: 12)
                        Text(option.name)
                        if editor.strokeColor == option.hex {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            swatchButton(
                "textformat",
                color: editor.strokeColor.map { Color(hexString: $0) }
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Cor do texto")
    }

    /// Cor padrão do grifo da ferramenta texto: um ponto ao lado do ícone que
    /// abre o seletor (desligado, amarelo, ciano, verde, rosa, violeta).
    private var highlightSwatch: some View {
        Menu {
            Button {
                editor.setHighlight(nil)
            } label: {
                Label("Sem grifo", systemImage: "line.diagonal")
            }
            Divider()
            ForEach(HighlightColor.options) { option in
                Button {
                    editor.setHighlight(option.hex)
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hexString: option.hex))
                            .frame(width: 12, height: 12)
                        Text(option.name)
                        if editor.highlightColor == option.hex {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            swatchButton(
                "highlighter",
                color: editor.highlightColor.map { Color(hexString: $0) },
                disabled: editor.highlightColor == nil
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Cor do grifo")
    }

    /// Botão de cor da barra nativa: ícone + faixa com a cor atual.
    private func swatchButton(
        _ icon: String,
        color: Color?,
        disabled: Bool = false
    ) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(height: 15)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(disabled ? Color.clear : (color ?? Color.clear))
                .frame(width: 20, height: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .strokeBorder(
                            disabled ? Color.secondary.opacity(0.6) : Color.primary.opacity(0.12),
                            lineWidth: 1
                        )
                )
        }
        .frame(width: 30, height: 26)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .contentShape(Rectangle())
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
        .menuStyle(.borderlessButton)
        .fixedSize()
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
        .menuStyle(.borderlessButton)
        .fixedSize()
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

// MARK: - Botão de ferramenta

/// Botão de ferramenta da barra nativa: discreto, com hover e estado ativo.
private struct ToolButton: View {
    let tool: Tool
    let isActive: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: tool.systemImage)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 30, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(background)
                )
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(helpText)
    }

    private var background: Color {
        if isActive {
            return Color.accentColor.opacity(0.2)
        }
        if hovering {
            return Color.primary.opacity(0.07)
        }
        return .clear
    }

    private var helpText: String {
        if let shortcut = tool.shortcut {
            return "\(tool.label)  (\(shortcut))"
        }
        return tool.label
    }
}
