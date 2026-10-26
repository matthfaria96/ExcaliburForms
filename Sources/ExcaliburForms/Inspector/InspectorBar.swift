import SwiftUI

/// Barra flutuante do rodapé com as opções do que está selecionado (ou da
/// ferramenta ativa). Só ícones, agrupados; quando a janela estreita, quebra
/// em duas linhas — estilo à esquerda, ações da seleção à direita/embaixo.
struct InspectorBar: View {
    @EnvironmentObject private var editor: EditorController

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                styleControls
                if hasActions {
                    InspectorDivider()
                    actionControls
                }
            }
            .inspectorCapsule()

            VStack(spacing: 8) {
                HStack(spacing: 10) { styleControls }
                if hasActions {
                    HStack(spacing: 10) { actionControls }
                }
            }
            .inspectorCapsule()

            // janela bem estreita: rola na horizontal em vez de transbordar
            ScrollView(.horizontal) {
                VStack(spacing: 8) {
                    HStack(spacing: 10) { styleControls }
                    if hasActions {
                        HStack(spacing: 10) { actionControls }
                    }
                }
                .inspectorCapsule()
            }
            .scrollIndicators(.never)
        }
        .padding(.horizontal, 16)
    }

    private var hasActions: Bool { editor.hasSelection }

    // MARK: - Estilo

    @ViewBuilder
    private var styleControls: some View {
        if let sticky = editor.stickySelection {
            stickyControls(sticky)
        } else if editor.textSelection != nil || editor.activeTool == .text {
            textControls
        } else if editor.activeTool == .stickynote {
            fontMenu(current: editor.fontFamily)
            fontSizePicker(current: nil)
        } else if let shape = editor.shapeSelection {
            shapeControls(shape)
        } else if editor.selectionTypes.contains("image") {
            Button {
                editor.command(.crop)
            } label: {
                Label("Recortar", systemImage: "crop")
            }
            .buttonStyle(InspectorButtonStyle(showsTitle: true))
            .help("Recortar imagem (ou dê dois cliques na imagem)")
        }
    }

    @ViewBuilder
    private var textControls: some View {
        let text = editor.textSelection
        ColorWell(
            help: "Cor do texto",
            current: text?.strokeColor ?? editor.strokeColor,
            options: TextColor.options.map { ($0.hex, $0.name) }
        ) { hex in
            guard let hex else { return }
            if text != nil {
                editor.performAction("changeStrokeColor", value: ["color": hex])
            } else {
                editor.setStrokeColor(hex)
            }
        }
        ColorWell(
            help: "Marca-texto",
            symbol: "highlighter",
            current: markerColor(text),
            options: HighlightColor.options.map { ($0.hex, $0.name) },
            noneLabel: "Sem marca-texto"
        ) { hex in
            editor.setHighlight(hex)
            if text != nil {
                editor.performAction("toggleTextHighlight", value: hex != nil)
            }
        }
        InspectorDivider()
        fontMenu(current: text?.fontFamily ?? editor.fontFamily)
        fontSizePicker(current: text?.fontSize)
        InspectorDivider()
        SegmentedIcons(
            items: [("bold", "bold", "Negrito")],
            selection: text?.fontWeight == "bold" ? "bold" : nil
        ) { _ in
            let next = text?.fontWeight == "bold" ? "normal" : "bold"
            editor.performAction("changeFontWeight", value: next)
        }
        SegmentedIcons(
            items: [
                ("left", "text.alignleft", "Alinhar à esquerda"),
                ("center", "text.aligncenter", "Centralizar"),
                ("right", "text.alignright", "Alinhar à direita"),
            ],
            selection: text?.textAlign
        ) { editor.performAction("changeTextAlign", value: $0) }
    }

    private func markerColor(_ text: TextSelection?) -> String? {
        guard let text else { return editor.highlightColor }
        return text.highlighted ? text.backgroundColor : nil
    }

    @ViewBuilder
    private func stickyControls(_ sticky: StickySelection) -> some View {
        ColorWell(
            help: "Cor da nota",
            current: sticky.backgroundColor,
            options: StickyColor.options.map { ($0.hex, $0.name) }
        ) { hex in
            if let hex { editor.performAction("changeBackgroundColor", value: ["color": hex]) }
        }
        InspectorDivider()
        fontMenu(current: sticky.fontFamily)
        fontSizePicker(current: sticky.fontSize)
    }

    /// Fonte: "Aa" com a prévia; o menu mostra cada fonte no seu estilo.
    private func fontMenu(current: Int) -> some View {
        let selected = FontChoice(rawValue: current)
        return Menu {
            ForEach(FontChoice.allCases) { font in
                Button {
                    editor.setFontFamily(font)
                } label: {
                    if font == selected {
                        Label(font.label, systemImage: "checkmark")
                    } else {
                        Text(font.label)
                    }
                }
            }
        } label: {
            // um só Text: o menu sem borda não reordena as partes
            (Text("Aa").font((selected ?? .handwritten).previewFont)
                + Text(" ")
                + Text(Image(systemName: "chevron.down")).font(.system(size: 7, weight: .bold)))
            .frame(height: 26)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Fonte: \(selected?.label ?? "outra")")
    }

    @ViewBuilder
    private func shapeControls(_ shape: ShapeSelection) -> some View {
        ColorWell(
            help: "Cor do traço",
            current: shape.strokeColor,
            options: ShapeColor.stroke.map { ($0.hex, $0.name) }
        ) { hex in
            if let hex { editor.performAction("changeStrokeColor", value: ["color": hex]) }
        }
        if shape.fillable {
            ColorWell(
                help: "Preenchimento",
                symbol: "drop.fill",
                current: shape.backgroundColor == "transparent" ? nil : shape.backgroundColor,
                options: ShapeColor.fill.dropFirst().map { ($0.hex, $0.name) },
                noneLabel: "Sem preenchimento"
            ) { hex in
                editor.performAction("changeBackgroundColor", value: ["color": hex ?? "transparent"])
                if hex != nil, shape.fillStyle != "solid" {
                    editor.performAction("changeFillStyle", value: "solid")
                }
            }
        }
        InspectorDivider()
        SegmentedIcons(
            items: StrokeWidth.allCases.map { ($0.rawValue, "", $0.label) },
            selection: shape.strokeWidth,
            customLabel: { key in
                let width = StrokeWidth(rawValue: key) ?? .medium
                return AnyView(
                    Capsule().frame(width: 14, height: width.lineHeight)
                )
            }
        ) { editor.performAction("changeStrokeWidth", value: $0) }
        SegmentedIcons(
            items: [
                ("solid", "line.diagonal", "Traço contínuo"),
                ("dashed", "line.3.horizontal.decrease", "Tracejado"),
                ("dotted", "ellipsis", "Pontilhado"),
            ],
            selection: shape.strokeStyle
        ) { editor.performAction("changeStrokeStyle", value: $0) }
    }

    private func fontSizePicker(current: Double?) -> some View {
        SegmentedText(
            items: TextSelection.sizes.map { ($0, TextSelection.sizeLabels[$0] ?? "?") },
            selection: current,
            help: "Tamanho do texto"
        ) { editor.performAction("changeFontSize", value: $0) }
    }

    // MARK: - Ações da seleção

    @ViewBuilder
    private var actionControls: some View {
        Menu {
            Button("Trazer para a frente") { editor.command(.bringToFront) }
            Button("Trazer para frente") { editor.command(.bringForward) }
            Button("Enviar para trás") { editor.command(.sendBackward) }
            Button("Enviar para o fundo") { editor.command(.sendToBack) }
        } label: {
            Image(systemName: "square.3.layers.3d")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .frame(width: 30, height: 26)
        .help("Organizar camadas")

        Button {
            editor.command(.toggleLock)
        } label: {
            Image(systemName: editor.selectionLocked ? "lock.fill" : "lock.open")
        }
        .buttonStyle(InspectorButtonStyle(isActive: editor.selectionLocked))
        .help(editor.selectionLocked ? "Desbloquear" : "Bloquear")

        Button {
            editor.command(.duplicate)
        } label: {
            Image(systemName: "plus.square.on.square")
        }
        .buttonStyle(InspectorButtonStyle())
        .help("Duplicar (⌘D)")

        Button(role: .destructive) {
            editor.command(.delete)
        } label: {
            Image(systemName: "trash")
        }
        .buttonStyle(InspectorButtonStyle())
        .help("Apagar (⌫)")
    }
}

// MARK: - Peças

private struct InspectorDivider: View {
    var body: some View {
        Divider().frame(height: 18)
    }
}

/// Botão de ícone do inspetor: discreto, com destaque quando ativo.
struct InspectorButtonStyle: ButtonStyle {
    var isActive = false
    var showsTitle = false

    func makeBody(configuration: Configuration) -> some View {
        Group {
            if showsTitle {
                configuration.label.labelStyle(.titleAndIcon)
                    .padding(.horizontal, 8)
            } else {
                configuration.label.labelStyle(.iconOnly)
                    .frame(width: 30)
            }
        }
        .font(.system(size: 13, weight: .medium))
        .frame(height: 26)
        .foregroundStyle(isActive ? Color.white : Color.primary)
        .background(
            Capsule(style: .continuous)
                .fill(configuration.isPressed
                      ? Color.primary.opacity(0.14)
                      : isActive ? Color.accentColor : Color.clear)
        )
        .contentShape(Capsule(style: .continuous))
    }
}

/// Grupo de botões com ícone em que um fica marcado (como um segmented).
private struct SegmentedIcons: View {
    let items: [(value: String, symbol: String, help: String)]
    let selection: String?
    var customLabel: ((String) -> AnyView)?
    let onSelect: (String) -> Void

    init(
        items: [(String, String, String)],
        selection: String?,
        customLabel: ((String) -> AnyView)? = nil,
        onSelect: @escaping (String) -> Void
    ) {
        self.items = items.map { (value: $0.0, symbol: $0.1, help: $0.2) }
        self.selection = selection
        self.customLabel = customLabel
        self.onSelect = onSelect
    }

    var body: some View {
        HStack(spacing: 1) {
            ForEach(items, id: \.value) { item in
                Button {
                    onSelect(item.value)
                } label: {
                    if let customLabel {
                        customLabel(item.value)
                    } else {
                        Image(systemName: item.symbol)
                    }
                }
                .buttonStyle(InspectorButtonStyle(isActive: selection == item.value))
                .help(item.help)
            }
        }
    }
}

/// Grupo de rótulos curtos (S M L XL) em que um fica marcado.
private struct SegmentedText: View {
    let items: [(value: Double, label: String)]
    let selection: Double?
    let help: String
    let onSelect: (Double) -> Void

    var body: some View {
        HStack(spacing: 1) {
            ForEach(items, id: \.value) { item in
                Button {
                    onSelect(item.value)
                } label: {
                    Text(item.label)
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .frame(width: 30)
                }
                .buttonStyle(InspectorButtonStyle(isActive: selection == item.value))
            }
        }
        .help(help)
    }
}

/// Um botão de cor: mostra a cor atual e abre uma grade de cores.
struct ColorWell: View {
    let help: String
    var symbol: String?
    let current: String?
    let options: [(hex: String, name: String)]
    var noneLabel: String?
    let onPick: (String?) -> Void

    @State private var open = false

    init(
        help: String,
        symbol: String? = nil,
        current: String?,
        options: [(String, String)],
        noneLabel: String? = nil,
        onPick: @escaping (String?) -> Void
    ) {
        self.help = help
        self.symbol = symbol
        self.current = current
        self.options = options.map { (hex: $0.0, name: $0.1) }
        self.noneLabel = noneLabel
        self.onPick = onPick
    }

    var body: some View {
        Button {
            open.toggle()
        } label: {
            ZStack {
                swatch(current, size: 18)
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.black.opacity(0.6))
                        .opacity(current == nil ? 0 : 1)
                }
            }
        }
        .buttonStyle(InspectorButtonStyle(isActive: open))
        .help(help)
        .popover(isPresented: $open, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 10) {
                Text(help)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(26), spacing: 8), count: 5), spacing: 8) {
                    if let noneLabel {
                        cell(nil, name: noneLabel)
                    }
                    ForEach(options, id: \.hex) { option in
                        cell(option.hex, name: option.name)
                    }
                }
            }
            .padding(12)
        }
    }

    private func cell(_ hex: String?, name: String) -> some View {
        Button {
            onPick(hex)
            open = false
        } label: {
            swatch(hex, size: 22)
                .overlay(
                    Circle()
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                        .padding(-3)
                        .opacity(isCurrent(hex) ? 1 : 0)
                )
        }
        .buttonStyle(.plain)
        .help(name)
    }

    private func isCurrent(_ hex: String?) -> Bool {
        hex?.lowercased() == current?.lowercased()
    }

    /// Círculo da cor; "nenhuma" é um círculo vazio cortado por um traço.
    @ViewBuilder
    private func swatch(_ hex: String?, size: CGFloat) -> some View {
        if let hex, hex != "transparent" {
            Circle()
                .fill(Color(hexString: hex))
                .frame(width: size, height: size)
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.15)))
        } else {
            Circle()
                .strokeBorder(Color.secondary.opacity(0.6), lineWidth: 1.2)
                .frame(width: size, height: size)
                .overlay(
                    Rectangle()
                        .fill(Color.red.opacity(0.85))
                        .frame(width: 1.5, height: size * 0.9)
                        .rotationEffect(.degrees(45))
                )
        }
    }
}

extension View {
    /// Cápsula de vidro do inspetor (Liquid Glass no macOS 26+, material antes).
    @ViewBuilder
    func inspectorCapsule() -> some View {
        let padded = self
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
        if #available(macOS 26.0, *) {
            // raio = metade da altura de uma linha: pílula numa linha, cantos
            // bem redondos em duas
            padded.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else {
            padded
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08))
                )
                .shadow(color: .black.opacity(0.18), radius: 18, y: 6)
        }
    }

    /// Painel de vidro flutuante (lista de quadros).
    @ViewBuilder
    func floatingPanel(cornerRadius: CGFloat = 18) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08))
                )
                .shadow(color: .black.opacity(0.16), radius: 16, y: 6)
        }
    }
}
