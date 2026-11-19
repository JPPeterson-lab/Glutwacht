#!/usr/bin/env bash
# Erzeugt die Linux- und die Windows-Fassung in export/ (Godot-Exportvorlagen müssen installiert sein).
cd "$(dirname "$0")/.."
mkdir -p export/linux export/windows
godot --headless --export-release "Linux" export/linux/Glutwacht.x86_64
godot --headless --export-release "Windows" export/windows/Glutwacht.exe
ls -la export/linux export/windows
