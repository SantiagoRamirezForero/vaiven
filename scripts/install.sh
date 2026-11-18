#!/bin/bash
# Compila Vaivén, la instala en /Applications (o ~/Applications si no se puede escribir ahí), conecta la cuenta de
# Claude si encuentra la sesión de Claude Code y la deja arrancando sola al iniciar sesión (LaunchAgent local.vaiven).
# Sin sudo. Se puede correr otra vez para actualizar.
#   --sin-claude   no conecta la cuenta de Claude (se puede hacer luego con «Agregar cuenta»)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LABEL="local.vaiven"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"
CONNECT_CLAUDE=1
for arg in "$@"; do
  case "$arg" in
    --sin-claude) CONNECT_CLAUDE=0 ;;
    *) echo "uso: $0 [--sin-claude]" >&2; exit 64 ;;
  esac
done

# Requisitos
[ "$(uname -m)" = "arm64" ] || { echo "Vaivén es para Mac con Apple Silicon (arm64)." >&2; exit 1; }
[ "$(sw_vers -productVersion | cut -d. -f1)" -ge 14 ] || { echo "Vaivén necesita macOS 14 o más nuevo." >&2; exit 1; }
xcode-select -p >/dev/null 2>&1 && command -v swift >/dev/null || {
  echo "Faltan las Command Line Tools de Apple: corre «xcode-select --install», acepta la ventana y vuelve a correr este script." >&2
  exit 1
}

"$ROOT/scripts/build-app.sh"

if [ -w /Applications ]; then DEST="/Applications"; else DEST="$HOME/Applications"; mkdir -p "$DEST"; fi
APP="$DEST/Vaiven.app"

# Para la copia que corre (si hay) antes de reemplazarla.
launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
pkill -x Vaiven 2>/dev/null || true
rm -rf "$APP"
ditto "$ROOT/dist/Vaiven.app" "$APP"

if [ "$CONNECT_CLAUDE" = 1 ]; then
  if RESULT="$("$APP/Contents/MacOS/Vaiven" --check-claude)"; then
    defaults write "$LABEL" claudeConnected -bool true
    echo "Cuenta de Claude conectada: $RESULT"
  else
    echo "Cuenta de Claude sin conectar ($RESULT). Inicia sesión en Claude Code y vuelve a correr este script, o toca «Agregar cuenta» en la isla."
  fi
fi

mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
sed -e "s|__APP__|$APP|g" -e "s|__HOME__|$HOME|g" "$ROOT/Resources/local.vaiven.plist" > "$PLIST"
plutil -lint "$PLIST" >/dev/null
launchctl bootstrap "$DOMAIN" "$PLIST"

sleep 2
if launchctl print "$DOMAIN/$LABEL" 2>/dev/null | grep -q "state = running"; then
  echo "Vaivén instalada en $APP y corriendo. Arranca sola cada vez que inicias sesión."
else
  echo "Vaivén quedó instalada en $APP pero no arrancó: revisa ~/Library/Logs/Vaiven.log" >&2
  exit 1
fi
