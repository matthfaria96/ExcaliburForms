# ExcaliburForms

App nativo de macOS (Swift/SwiftUI) construído sobre o [Excalidraw](https://github.com/excalidraw/excalidraw): um quadro infinito minimalista para screenshots, anotações visuais e organização de referências.

O editor **não é reescrito** — o fork do monorepo Excalidraw é usado como motor, preservando o que já funciona (imagens, seleção, mover, redimensionar, recorte, formas, setas, desenho livre, zoom, desfazer/refazer, exportação) e mantendo a licença MIT.

## Recursos

- Ferramentas essenciais: seleção, mão, imagem, texto, **texto com marca-texto** (fundo colorido independente da cor do texto), **nota adesiva**, formas, setas e desenho livre.
- Texto com tamanho, peso, cor e alinhamento.
- Camadas (frente/trás), bloquear/desbloquear; anotações podem ficar acima das imagens.
- Vários quadros numa barra lateral (criar, renomear, duplicar, excluir com confirmação), cada um com estado próprio.
- Salvamento automático e persistência local confiável em `~/Library/Application Support/ExcaliburForms/` (escritas atômicas; excluir manda para o Lixo).
- Exportar PNG e SVG (quadro, seleção ou área visível) e copiar PNG para a área de transferência (⌘⇧C).
- Interface minimalista estilo macOS, tema claro/escuro/sistema, atalhos de teclado do macOS.

## Estrutura

- `excalidraw/` — fork do monorepo Excalidraw (upstream `b7de45e`). Mudanças no núcleo ficam em `packages/*`.
- `excalidraw/excalibur-web/` — página hospedeira (Vite) com o editor em `UIOptions.minimalUI`, autosave por quadro e a ponte `window.excalibur` para o Swift.
- `Sources/ExcaliburCore` — núcleo puro e testado (`Board`, `BoardStore`, `SceneInspector`).
- `Sources/ExcaliburForms` — app SwiftUI: janela, lista de quadros e `WKWebView` com o editor.
- `Tests/ExcaliburCoreTests` — testes do núcleo.

Persistência por quadro:

```
~/Library/Application Support/ExcaliburForms/
├── boards.json                     índice (nome, datas, ordem)
└── Boards/<id>/
    ├── scene.excalidraw            cena sem imagens (JSON do editor)
    └── files/<fileId>.json         uma imagem por arquivo, gravada uma vez
```

## Build

O build/teste de Swift exige o Xcode:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift build      # compila
swift test       # testes do núcleo
```

Testes JavaScript (na pasta `excalidraw/`):

```bash
./node_modules/.bin/vitest run
```

Gerar o `.app` (release, com página empacotada, Liquid Glass e assinatura ad-hoc):

```bash
scripts/build-app.sh --install   # monta e instala em /Applications
```

## Licença

O editor é o Excalidraw, distribuído sob a licença MIT. Veja [`NOTICE`](NOTICE) e [`excalidraw/LICENSE`](excalidraw/LICENSE).
