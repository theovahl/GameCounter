#!/usr/bin/env bash
# Baut beide Websites für Firebase Hosting:
#   build/web_app   – die komplette App (iPhone: in Safari "Zum Home-Bildschirm")
#   build/web_live  – die Zuschauer-Seite der WG Olympiade
#
# Hochladen danach:
#   npx firebase-tools deploy --only hosting --project game-counter-tv
set -euo pipefail

cd "$(dirname "$0")/.."
command -v flutter >/dev/null || export PATH="$PATH:$HOME/develop/flutter/bin"

echo "==> App (lib/main.dart) -> build/web_app"
flutter build web --release -t lib/main.dart -o "$PWD/build/web_app"

echo "==> Zuschauer-Seite (lib/main_live.dart) -> build/web_live"
flutter build web --release -t lib/main_live.dart -o "$PWD/build/web_live"

# web/ trägt den Namen der App; die Zuschauer-Seite bekommt ihren eigenen Titel
sed -i \
  -e 's|<title>GameCounter</title>|<title>WG Olympiade – Live</title>|' \
  -e 's|content="GameCounter"|content="WG Olympiade"|' \
  -e 's|content="GameCounter – Spielstände zählen und die WG Olympiade austragen."|content="WG Olympiade – Punktestand und Ergebnisse live verfolgen."|' \
  build/web_live/index.html
sed -i \
  -e 's|"name": "GameCounter"|"name": "WG Olympiade – Live"|' \
  -e 's|"short_name": "GameCounter"|"short_name": "WG Olympiade"|' \
  build/web_live/manifest.json

echo "==> Fertig."
