# ExcaliburForms

App nativo de macOS (Swift/SwiftUI) feito a partir do Excalidraw: um quadro infinito minimalista para screenshots, anotações visuais e organização de referências.

## O que o usuário pediu (resumo)

- Usar o Excalidraw (https://github.com/excalidraw/excalidraw) como motor. **Não reescrever o editor**, preservar o que já funciona (imagens, seleção, mover, redimensionar, recorte, formas, setas, desenho livre, zoom, desfazer/refazer, exportação). Manter licença (MIT) e avisos.
- Remover/simplificar ferramentas, menus e opções não essenciais.
- Ferramentas essenciais: seleção, imagem, texto, **texto com marca-texto**, **nota adesiva**, formas, setas, desenho livre.
- Texto com tamanho, **peso**, cor e alinhamento.
- Ordem de camadas (frente/trás), bloquear/desbloquear; **painel de camadas** para ver, selecionar, reordenar e apagar qualquer elemento.
- **Vários quadros** num painel lateral: criar, renomear, duplicar, abrir, excluir (com confirmação). Cada quadro guarda seu próprio estado. Salvamento automático e persistência local confiável.
- Exportar PNG e SVG (quadro, seleção ou área); copiar imagem para a área de transferência rapidamente.
- Interface **muito minimalista** estilo macOS: canvas limpo, painéis flutuantes/translúcidos, controles contextuais discretos, tema claro/escuro/sistema, atalhos do macOS.
- **Cores vivas e vibrantes** (marca-texto neon, notas e preenchimentos sólidos) funcionando nos temas claro **e** escuro.
- Texto: **sempre com marca-texto por padrão** (com opção explícita "sem fundo"), e quando texto e grifo têm a mesma cor, o **texto** é ajustado para ficar legível.
- Notas adesivas com **texto preto**.
- Critérios de conclusão: criar quadro e importar várias screenshots; posicioná-las e recortá-las; sobrepor textos, marca-textos, notas, setas e desenhos; mudar camadas sem perder elementos; criar e alternar quadros; fechar/reabrir sem perder nada; exportar com aparência fiel; excluir quadros sem afetar os outros.
- Fluxo pedido: inspecionar, planejar, implementar em etapas, rodar testes e corrigir regressões.

## Arquitetura

- `excalidraw/` — fork do monorepo (upstream `b7de45e`). Mudanças no núcleo ficam em `packages/*`, seguindo os padrões do projeto.
- `excalidraw/excalibur-web/` — página hospedeira (Vite) com o editor em `UIOptions.minimalUI`, autosave por quadro e a ponte `window.excalibur` para o Swift. Build: `./node_modules/.bin/vite build excalibur-web --config excalibur-web/vite.config.mts` (na pasta `excalidraw/`) → `excalibur-web/build` (fontes empacotadas, offline).
- Raiz: pacote SwiftPM (macOS 14, ferramentas 5.9):
  - `Sources/ExcaliburCore` — núcleo puro e testado: `Board`, `BoardStore`, `SceneInspector` (10 testes).
  - `Sources/ExcaliburForms` — app SwiftUI:
    - `Editor/EditorController` — WKWebView no esquema `excalibur://` (serve `Resources/web` por `WebAssetsSchemeHandler`), handler de mensagens `excalibur` (proxy fraco), `WKUIDelegate` (NSOpenPanel para imagem), links externos no navegador, **web data store não persistente** (página sempre fresca). Recebe `ready`/`save`/`state`/`error`; chama `window.excalibur.*` via `callAsyncJavaScript(arguments:)` (nunca interpola texto em JS).
    - `Boards/BoardLibrary` — estado observável sobre o `BoardStore` (fila de gravação própria).
    - UI: `ContentView` (ZStack sobre o canvas + barra da janela), `WorkspaceUI` (painel/aba/renomear/excluir, compartilhado com os menus), `Boards/BoardsPanel` (painel de vidro Quadros/Camadas, fecha ao clicar fora), `Boards/LayerList`, `Inspector/InspectorBar` (inspetor adaptável), `Settings/` (Ajustes, Sobre, Licenças).
    - `ExportService` — PNG/SVG × quadro/seleção/área visível, copiar PNG (⌘⇧C).
    - `AppDelegate` — `applicationWillTerminate` faz `flush()` da página + `library.flushSaves()`.
  - Persistência: `~/Library/Application Support/ExcaliburForms/boards.json` (índice) e `Boards/<id>/scene.excalidraw` + `Boards/<id>/files/<fileId>.json` (cada imagem gravada uma vez). Escritas atômicas; excluir manda a pasta para o Lixo.
- Ponte (`excalibur-web/src/`): `bridge.ts` (mensagens), `App.tsx` (estado espelhado), `index.tsx` (API do host), `tools.ts` (ferramentas/atalhos), `autosave.ts`, `board.ts`, `exporter.ts`.
  - Native → página: `loadBoard`, `flush`, `setTool`, `setTheme`, `setHighlight(color|null)`, `setStrokeColor`, `action(name, value)`, `layerAction(id, action)`, `command(name)`, `exportImage(request)`.
  - Página → native: `ready`, `save` (scene + files novos), `state` (tool, hasSelection, theme, strokeColor, highlightColor, text selecionado, sticky selecionado, layers), `error`.
- Build/teste Swift exigem `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Testes JS: `./node_modules/.bin/vitest run` na pasta `excalidraw/`.

## Fluxo de trabalho (pedido do usuário)

- **Toda vez que o código do app for atualizado, instalar para o usuário testar**: rodar `scripts/build-app.sh --install` (build da página + Swift release + `vtool` Liquid Glass + assinatura ad-hoc + cópia para `/Applications` + `open`). Não esperar o usuário pedir.
- **Sempre terminar cada resposta dizendo se instalou o app ou não**.
- Sempre rodar os testes (`swift test` e `vitest run`) antes de instalar.
- Fazer commit e `git push origin main` das mudanças (repositório público `matthfaria96/ExcaliburForms`).
- Se o usuário disser que "está na versão antiga": encerrar o app, limpar `~/Library/WebKit/com.excaliburforms.app`, remover/reinstalar `/Applications/ExcaliburForms.app`, desregistrar a cópia de `build/` do LaunchServices (`lsregister -u`) e reabrir.

## Feito até agora (24 commits)

1. `06bfce6` — Excalidraw vendorizado sem modificações.
2. `5bf78b3` — Texto com `fontWeight`/`highlighted` (marca-texto por linha), domínio de cor próprio, `minimalUI`, nota adesiva e recorte reaproveitados.
3. `a48fdf0` — `api.executeAction(name)` e a página `excalibur-web` com a ponte.
4. `57d0356` — App nativo: `EditorController`, UI SwiftUI, `AppDelegate`, `scripts/build-app.sh`, README/NOTICE.
5. `5bf0124` — Ícone do app (`.icns` + gerador `scripts/make-icon.py`).
6. `8b87057` — Texto e marca-texto num só botão, cores do grifo mais vivas, polish da toolbar.
7. `0908197` — Texto com marca-texto por padrão + seletor de cor padrão ao lado do ícone.
8. `6fa7f25` — Remoção dos `.env` do upstream (continham chaves Firebase públicas; alertas do GitHub resolvidos).
9. `a57329e` — Menu de contexto minimalista + swatches de cor do texto/grifo.
10. `7700c8d` — Painel/popovers mantidos dentro da tela.
11. `a145cfc` — Lista de quadros flutuante/translúcida + botão flutuante no canto; painel à direita.
12. `1acbe72` — Painel de propriedades nativo à direita + fechar lista ao clicar fora.
13. `ded9664` — Painel de camadas; correção da cor do texto (`changeStrokeColor` precisa de `{ color }`); swatches mais claros.
14. `2a4254a` — Painel também para notas adesivas.
15. `19c5a65` — Paleta mais viva (grifo neon, notas/preenchimentos saturados) + painel refinado.
16. `80b3ff7` — Correção do filtro de tema escuro (fundos mantêm a cor exata; texto de grifo escuro; SVG idem).
17. `9f732d1` — Propriedades movidas para uma barra inferior centralizada.
18. `a5032df` — Texto sempre com grifo, texto de nota preto, `getReadableTextColor` (texto ajusta para ler sobre o grifo); cinza removido.
19. `5d9ad53` — Documentação: reportar sempre se instalou.
20. `58232bc` — Opção "sem fundo" (branco com risco vermelho), swatches agrupados ao "Aa" e refletindo as cores reais do texto.
21. `e136e72` — Web data store não persistente (sem cache entre builds).
22. `070445f` — Remoção das cores do menu inferior (só Tamanho/Peso/Alinhamento, segmentados com chip ativo em accent).

23. Redesenho da UI (macOS 27): título da janela = nome do quadro; barra com só painel, uma cápsula de ferramentas (formas lembram a última usada) e Compartilhar; aparência saiu da barra para **Ajustes (⌘,)** no padrão do MacDash (Geral + Sobre + Licenças); painel de quadros/camadas de vidro com "+" no topo (sem botões duplicados); **inspetor no rodapé** adaptável (uma linha, duas linhas ou rolagem conforme a largura) com estilo de texto/nota/forma e ações da seleção; menus como nos apps da Apple (Arquivo › Exportar, Visualizar, Organizar, Ajuda › Atalhos); desfazer/refazer saiu do rodapé do editor; formas/setas/desenho ganharam cor, preenchimento, espessura e estilo do traço; exportação com resolução e fundo configuráveis; app em pt-BR (`CFBundleDevelopmentRegion`); ícone novo no estilo Freeform (`scripts/make-icon.py`, precisa de numpy + Pillow num venv).

24. Correções: cor do texto não mudava (a legibilidade sobre o grifo exigia contraste 4,5 e escurecia quase toda cor; agora só ajusta abaixo de 2,0, quando texto e grifo quase se confundem); inspetor mostrava "sem marca-texto" em texto grifado por padrão; data no canto da nota segue a cor da nota (`getStickyNoteFooterColor`); fonte (À mão/Normal/Destaque/Código) para texto e notas; **pontos no fundo** como no Freeform (`UIOptions.dotGrid`, espaçamento adaptativo ao zoom, nunca exportado; liga/desliga em Ajustes).
- Testes JS rodando em paralelo podem falhar por falta de recursos da máquina (timeouts, "number of renders"); repetir os arquivos com `--no-file-parallelism` antes de concluir que é regressão.

## Estado atual / pendências

- **Verificar no app real** os 8 critérios de conclusão (colar screenshot do clipboard, arrastar/soltar no WKWebView, recorte, camadas, fechar/reabrir, exportação, exclusão de quadros) — interativo, não automatizável aqui.
- As cores de texto/grifo saíram da barra da janela e voltaram ao inspetor como **um botão de cor cada** (abre uma grade); confirmar com o usuário, que antes pediu para tirar as cores da barra inferior.
- Rodar `scripts/build-app.sh --install` + reiniciar o app após cada mudança.
- Não publicar release/site sem pedido explícito do usuário.
