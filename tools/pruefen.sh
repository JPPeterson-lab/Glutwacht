#!/usr/bin/env bash
# Prüft alle Skripte auf Fehler (startet Godot ohne Fenster und beendet es sofort).
cd "$(dirname "$0")/.."
godot --headless --quit-after 3 2>&1 | grep -E "SCRIPT ERROR|Parse Error|ERROR: (Failed|res)|at: .*\.gd" | grep -v "PagedAllocator" | head -${1:-30}
echo "Prüfung beendet."
