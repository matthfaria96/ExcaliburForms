#!/bin/bash
# showcase-shot.sh <out.png> [light|dark] [VAR=value ...]
# Captura a janela de uma cópia isolada do app (bundle com.excaliburforms.app.showcase)
# com os quadros fictícios em $SHOWCASE_HOME (gerados por excalibur-web/src/showcase.test.ts).
# Nunca toca no app instalado nem nos quadros reais. VAR=value vira --env (EXCALIBUR_SHOWCASE_*).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="${SHOWCASE_TOOLS:-$HOME/Documents/VSCode/witchmymac-release/tools/showcase}"
OUT="$1"; THEME="${2:-light}"; shift 2 || shift $#
HOMEDIR="${SHOWCASE_HOME:?defina SHOWCASE_HOME}"
COPY="$ROOT/build/showcase/ExcaliburForms Showcase.app"; DOM=com.excaliburforms.app.showcase
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

if [ ! -d "$COPY" ] || [ "$ROOT/build/ExcaliburForms.app/Contents/MacOS/ExcaliburForms" -nt "$COPY/Contents/MacOS/ExcaliburForms" ]; then
  rm -rf "$COPY"; mkdir -p "$(dirname "$COPY")"; ditto "$ROOT/build/ExcaliburForms.app" "$COPY"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $DOM" "$COPY/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Delete :SUFeedURL" "$COPY/Contents/Info.plist"
  codesign --force --deep --sign - "$COPY" >/dev/null 2>&1
fi
ENVS=(--env CFFIXED_USER_HOME="$HOMEDIR" --env EXCALIBUR_SHOWCASE=1 --env EXCALIBUR_SHOWCASE_SCREEN=left)
for kv in "$@"; do ENVS+=(--env "$kv"); done

until mkdir /tmp/witchmymac-capture.lock 2>/dev/null; do sleep 2; done
trap 'rmdir /tmp/witchmymac-capture.lock 2>/dev/null' EXIT
pkill -f "ExcaliburForms Showcase.app/Contents/MacOS" 2>/dev/null; sleep 0.5
defaults delete $DOM >/dev/null 2>&1
defaults write $DOM appearance -string "$THEME"
defaults write $DOM lastBoardID -string "${BOARD:-demo-redesign}"
defaults write $DOM panelVisible -bool "${PANEL_VISIBLE:-true}"
open -g -n "${ENVS[@]}" "$COPY" --args -AppleLanguages "(pt-BR)"
sleep "${WAIT:-7}"
PID=$(pgrep -f "ExcaliburForms Showcase.app/Contents/MacOS/ExcaliburForms" | head -1)
WID=$("$TOOLS/winid" "$PID" "${MINW:-600}" "${MAXW:-99999}") || { echo "sem janela"; pkill -f "ExcaliburForms Showcase.app/Contents/MacOS"; exit 1; }
if [ -n "${SETTINGS_SHOT:-}" ]; then
  SWID=$("$TOOLS/winid" "$PID" 300 600) && screencapture -x -o -l "$SWID" "$SETTINGS_SHOT"
fi
read -r X Y W H < <("$TOOLS/bounds" "$WID")
"$TOOLS/backdrop" "$TOOLS/wallpaper.jpg" "$X" "$Y" "$W" "$H" "$WID" & BD=$!
sleep 1.2
screencapture -x -o -l "$WID" "$OUT"
kill $BD 2>/dev/null
pkill -f "ExcaliburForms Showcase.app/Contents/MacOS"
echo "$OUT $(sips -g pixelWidth -g pixelHeight "$OUT" | awk '/pixel/{printf $2" "}')"
