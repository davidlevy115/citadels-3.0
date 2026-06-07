#!/bin/bash
# Serve the web build locally. The export uses thread_support=false, so a plain
# static file server is enough (no COOP/COEP headers required).
cd "$(dirname "$0")/build/web" || { echo "Run the web export first: ./export_web.sh"; exit 1; }
PORT="${1:-8060}"
echo "Citadels 3.0 → http://localhost:$PORT"
exec python3 -m http.server "$PORT"
