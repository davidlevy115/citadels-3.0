#!/bin/bash
# Build the browser-playable version into build/web/.
set -e
cd "$(dirname "$0")"
mkdir -p build/web
godot --headless --import >/dev/null 2>&1 || true
godot --headless --export-release "Web" build/web/index.html
echo "Done → build/web/  (run ./serve.sh to play in the browser)"
