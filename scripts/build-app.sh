#!/bin/bash
# Arma dist/Vaiven.app (Apple Silicon, firma ad hoc) y dist/Vaiven.zip. No instala nada.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swift build -c release --arch arm64
BIN="$(swift build -c release --arch arm64 --show-bin-path)/Vaiven"
APP="dist/Vaiven.app"

rm -rf dist
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/Vaiven"
cp Resources/Info.plist "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" >/dev/null
codesign --force --sign - --identifier local.vaiven "$APP"
codesign --verify --strict "$APP"
# El zip sirve para pasarla sin GitHub; quien la abra tendrá que darle «Abrir igualmente» en
# Ajustes del Sistema → Privacidad y seguridad (no está firmada con una cuenta de desarrollador de Apple).
ditto -c -k --keepParent "$APP" dist/Vaiven.zip
echo "Listo: $ROOT/$APP"
