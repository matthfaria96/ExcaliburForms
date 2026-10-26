#!/usr/bin/env bash
#
# ExcaliburForms — monta o app .app (release) a partir do pacote Swift e da
# página do editor (Vite). Copia os artefatos, regrava o SDK para Liquid Glass,
# assina ad-hoc e, com --install, instala em /Applications.
#
# Uso:
#   scripts/build-app.sh [--install] [--no-web] [--debug]
#
# Variáveis opcionais:
#   DEVELOPER_DIR      caminho do Xcode (padrão: /Applications/Xcode.app/...)
#   LIQUID_GLASS_SDK   versão de SDK gravada no Mach-O (padrão: 26.0)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ExcaliburForms"
BUNDLE_ID="com.excaliburforms.app"
MIN_OS="14.0"
LIQUID_GLASS_SDK="${LIQUID_GLASS_SDK:-26.0}"

BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

: "${DEVELOPER_DIR:=/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR

CONFIG="release"
INSTALL=0
BUILD_WEB=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --install) INSTALL=1 ;;
    --no-web) BUILD_WEB=0 ;;
    --debug) CONFIG="debug" ;;
    *) echo "Opção desconhecida: $1" >&2; exit 1 ;;
  esac
  shift
done

# 1) Página do editor (Vite), empacotada para rodar offline.
if [[ "$BUILD_WEB" == "1" ]]; then
  echo "==> Build da página do editor (Vite)"
  (cd "$ROOT/excalidraw" && ./node_modules/.bin/vite build excalibur-web --config excalibur-web/vite.config.mts)
fi
WEB_ROOT="$ROOT/excalidraw/excalibur-web/build"
[[ -f "$WEB_ROOT/index.html" ]] || { echo "Página do editor não encontrada em $WEB_ROOT" >&2; exit 1; }

# 2) Binário Swift.
echo "==> Build Swift ($CONFIG)"
(cd "$ROOT" && swift build -c "$CONFIG")
BIN="$ROOT/.build/$CONFIG/$APP_NAME"
[[ -f "$BIN" ]] || { echo "Binário não encontrado: $BIN" >&2; exit 1; }

# 3) Estrutura do .app.
echo "==> Montando $APP"
rm -rf "$APP"
mkdir -p "$MACOS_DIR" "$RESOURCES"
cp "$BIN" "$MACOS_DIR/$APP_NAME"
cp -R "$WEB_ROOT" "$RESOURCES/web"
# a pasta de idioma faz o macOS usar o português nos menus e janelas do sistema
mkdir -p "$RESOURCES/pt-BR.lproj"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>pt-BR</string>
    <key>CFBundleLocalizations</key><array><string>pt-BR</string></array>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>$MIN_OS</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.graphics-design</string>
    <key>NSHumanReadableCopyright</key><string>Copyright © 2026. Editor baseado no Excalidraw (licença MIT).</string>
</dict>
</plist>
PLIST

# Ícone, se existir.
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$RESOURCES/AppIcon.icns"
fi

# 4) Liquid Glass (macOS 26): o SwiftPM grava SDK = min OS (14.0) no Mach-O;
#    regravamos para 26.x para o app ganhar a nova aparência.
if command -v vtool >/dev/null 2>&1; then
  echo "==> vtool: SDK $LIQUID_GLASS_SDK (Liquid Glass)"
  TMP_BIN="$MACOS_DIR/$APP_NAME.vtool"
  if vtool -set-build-version macos "$MIN_OS" "$LIQUID_GLASS_SDK" -replace \
      -output "$TMP_BIN" "$MACOS_DIR/$APP_NAME"; then
    mv "$TMP_BIN" "$MACOS_DIR/$APP_NAME"
  else
    rm -f "$TMP_BIN"
    echo "aviso: vtool não aplicou o SDK; seguindo sem Liquid Glass" >&2
  fi
else
  echo "aviso: vtool não encontrado; pulando rewrite de SDK" >&2
fi

# 5) Assinatura ad-hoc (após o vtool, que invalida assinaturas).
echo "==> Assinando (ad-hoc)"
codesign --force --deep --sign - "$APP"

# 6) Instalação.
if [[ "$INSTALL" == "1" ]]; then
  echo "==> Instalando em /Applications"
  ditto "$APP" "/Applications/$APP_NAME.app"
  open "/Applications/$APP_NAME.app"
fi

echo "OK: $APP"
