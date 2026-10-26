# ExcaliburForms

App nativo de macOS (Swift/SwiftUI) feito a partir do Excalidraw: um quadro infinito minimalista para screenshots, anotações visuais e organização de referências.

## O que o usuário pediu (resumo)

- Usar o Excalidraw (https://github.com/excalidraw/excalidraw) como motor. **Não reescrever o editor**, preservar o que já funciona (imagens, seleção, mover, redimensionar, recorte, formas, setas, desenho livre, zoom, desfazer/refazer, exportação). Manter licença (MIT) e avisos.
- Remover/simplificar ferramentas, menus e opções não essenciais.
- Ferramentas essenciais: seleção, imagem, texto, **texto com marca-texto** (fundo colorido: amarelo, verde, azul, rosa, roxo; cor do texto e do fundo separadas), **nota adesiva**, formas, setas, desenho livre.
- Texto com tamanho, **peso**, cor e alinhamento.
- Ordem de camadas (frente/trás), bloquear/desbloquear; anotações sempre podendo ficar acima das imagens.
- **Vários quadros** numa barra lateral: criar, renomear, duplicar, abrir, excluir (com confirmação). Cada quadro guarda seu próprio estado. Salvamento automático e persistência local confiável (não só armazenamento do navegador).
- Exportar PNG e SVG (quadro, seleção ou área); copiar imagem para a área de transferência rapidamente.
- Interface minimalista estilo macOS nativo, tema claro/escuro, atalhos de teclado do macOS, sem painéis que roubem área do canvas.
- Critérios de conclusão: criar quadro e importar várias screenshots; posicioná-las e recortá-las; sobrepor textos, marca-textos, notas, setas e desenhos; mudar camadas sem perder elementos; criar e alternar quadros; fechar/reabrir sem perder nada; exportar com aparência fiel; excluir quadros sem afetar os outros.
- Fluxo pedido: inspecionar, planejar, implementar em etapas, rodar testes e corrigir regressões.

## Arquitetura escolhida

- `excalidraw/` — fork do monorepo (upstream `b7de45e`, commit base sem modificações). Mudanças no núcleo ficam em `packages/*`, seguindo os padrões do projeto.
- `excalidraw/excalibur-web/` — página hospedeira (Vite, workspace do monorepo) com o editor em `UIOptions.minimalUI`, autosave por quadro e ponte `window.excalibur` para o Swift. Build: `npx vite build excalibur-web --config excalibur-web/vite.config.mts` (na pasta `excalidraw/`) → `excalibur-web/build` (fontes empacotadas, offline).
- Raiz: pacote SwiftPM (macOS 14, ferramentas 5.9), no padrão dos outros apps do usuário (ViewTube):
  - `Sources/ExcaliburCore` — núcleo puro e testado: `Board`, `BoardStore`, `SceneInspector`.
  - `Sources/ExcaliburForms` — app SwiftUI: janela com lista de quadros + WKWebView com o editor.
  - Persistência: `~/Library/Application Support/ExcaliburForms/boards.json` (índice) e `Boards/<id>/scene.excalidraw` + `Boards/<id>/files/<fileId>.json` (cada imagem gravada uma vez). Escritas atômicas; excluir manda a pasta para o Lixo.
- Build/teste Swift exigem `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Testes JS: `npx vitest run` na pasta `excalidraw/`.

## Feito até agora

1. Commit `06bfce6` — Excalidraw vendorizado sem modificações.
2. Commit `5bf78b3` — núcleo do editor:
   - Texto ganhou `fontWeight` ("bold") e `highlighted` (marca-texto por linha, cor em `backgroundColor`), desenhados no canvas, no SVG exportado e durante a edição; `restore` preserva/normaliza. Helper `packages/element/src/textHighlight.ts`.
   - Marca-texto é um domínio de cor próprio (`colorTargets.ts`): paleta `HIGHLIGHT_BACKGROUND_PICKS`, estados `currentItemHighlightColor`, `currentItemTextHighlight`, `currentItemFontWeight`, `colorTopPicks.highlightBackground`.
   - Ações de painel `changeFontWeight` e `toggleTextHighlight` (`actions/actionTextStyle.tsx`), com locais en e pt-BR.
   - `UIOptions.minimalUI`: esconde toolbar de formas, menu principal, biblioteca, ajuda e itens avançados do menu de contexto.
   - Nota adesiva e recorte de imagem **já existiam** no upstream (ferramenta `stickynote`, `cropEditor`) e foram reaproveitados.
   - Suíte completa: 2578 testes passando; snapshots atualizados (só os 4 campos novos de estado) + `tests/textStyle.test.tsx`.
3. Commit `a48fdf0` — `api.executeAction(name)` na API imperativa (com testes) e a página `excalibur-web` (`bridge.ts`, `tools.ts`, `autosave.ts`, `exporter.ts`, `board.ts`, `App.tsx`, `index.tsx`, `host.test.ts` com 9 testes). Build da página OK; typecheck limpo.
4. **Não commitado ainda**: `.gitignore` já existe; `Package.swift`, `Sources/ExcaliburCore/*` e `Tests/ExcaliburCoreTests/BoardStoreTests.swift` (10 testes passando), `Sources/ExcaliburForms/Editor/WebAssetsSchemeHandler.swift` (serve a página por `excalibur://app/`), `Sources/ExcaliburForms/Boards/BoardLibrary.swift`, e um `Sources/ExcaliburForms/main.swift` provisório (só `import Foundation`, para o pacote compilar; deve ser removido quando existir o `@main`).

## Próximos passos (ainda não feitos)

- `EditorController`: WKWebView com handler de mensagens `excalibur` (proxy fraco), esquema `excalibur://`, `WKUIDelegate` com `NSOpenPanel` para o `<input type=file>` da ferramenta de imagem, links externos no navegador. Recebe `ready`/`save`/`state`/`error`; chama `window.excalibur.loadBoard/flush/setTool/setTheme/command/exportImage` via `callAsyncJavaScript(arguments:)` (nunca interpolar texto em JS).
- Validar `boardId` e ids de arquivo vindos da página (o `BoardStore` já rejeita ids inseguros).
- UI SwiftUI: `NavigationSplitView` (lista com criar, renomear inline, duplicar, excluir com confirmação; evitar sidebar recolhida, que gera "»" vazio no macOS 26), toolbar nativa com as ferramentas (seleção, mão, imagem, texto, marca-texto, nota, formas em menu, seta, desenho livre), menu de exportação (PNG/SVG × quadro/seleção/área visível, copiar PNG ⌘⇧C, exportar ⌘E), menu Quadro (⌘N etc.), comandos de camadas/zoom/desfazer via `command`, aparência Sistema/Claro/Escuro.
- `AppDelegate`: no encerramento, `flush()` na página + `library.flushSaves()` antes de sair.
- `scripts/build-app.sh` no padrão do ViewTube (copiar `excalibur-web/build` para `Contents/Resources/web`, `Info.plist`, ícone, `vtool` regravando o SDK para Liquid Glass, assinatura ad-hoc, `--install`).
- Verificar no app real os 8 critérios de conclusão (colar screenshot do clipboard e arrastar/soltar no WKWebView precisam ser testados), capturando só a janela do app.
- README/NOTICE com a licença MIT do Excalidraw e as fontes.
- Não publicar release/site sem pedido explícito do usuário.
