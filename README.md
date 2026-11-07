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

## Instalar

Requer macOS 14 Sonoma ou mais novo, num Mac com Apple Silicon. A interface é em português.

Escolha um jeito:

1. **Terminal, uma linha (recomendado).** Cole no Terminal:
   ```sh
   curl -fsSL https://witchmymac.com/install.sh | bash -s excaliburforms
   ```
   Baixa a versão mais recente do GitHub, confere o SHA-256, instala em Aplicativos e abre. Não aparece aviso do macOS, porque arquivos baixados pelo `curl` não ganham a marca de "baixado da internet". Rode a mesma linha de novo para atualizar. O script é aberto: [install.sh](https://witchmymac.com/install.sh).
2. **Baixe o DMG** em [Releases](https://github.com/matthfaria96/ExcaliburForms/releases) ou em [witchmymac.com/excaliburforms](https://witchmymac.com/excaliburforms/), arraste o ExcaliburForms para Aplicativos e libere uma vez com:
   ```sh
   xattr -dr com.apple.quarantine "/Applications/ExcaliburForms.app"
   ```
3. **Baixe o DMG** e libere em Ajustes do Sistema: abra o app, clique em OK no aviso e vá em Ajustes do Sistema › Privacidade e Segurança › Abrir Mesmo Assim.

As atualizações seguintes chegam dentro do app (ExcaliburForms › Verificar Atualizações…).

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

MIT ([`LICENSE`](LICENSE)). O editor é o Excalidraw, também distribuído sob a licença MIT. Veja [`NOTICE`](NOTICE) e [`excalidraw/LICENSE`](excalidraw/LICENSE).
