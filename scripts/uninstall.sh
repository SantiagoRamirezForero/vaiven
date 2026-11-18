#!/bin/bash
# Quita Vaivén: el arranque al iniciar sesión, la app y sus ajustes. No toca la sesión de Claude Code.
set -euo pipefail
LABEL="local.vaiven"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
pkill -x Vaiven 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -rf "/Applications/Vaiven.app" "$HOME/Applications/Vaiven.app" "$HOME/Library/Application Support/Vaiven"
rm -f "$HOME/Library/Logs/Vaiven.log"
defaults delete "$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/Preferences/$LABEL.plist" # defaults delete a veces deja el archivo vacío
echo "Vaivén desinstalada."
