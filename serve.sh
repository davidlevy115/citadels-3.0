#!/bin/bash
# Serve the web build locally. The export uses thread_support=false, so a plain
# static file server is enough (no COOP/COEP headers required).
# Sends Cache-Control: no-store so the browser never replays a stale build.
cd "$(dirname "$0")/build/web" || { echo "Run the web export first: ./export_web.sh"; exit 1; }
PORT="${1:-8060}"
echo "Citadels 3.0 → http://localhost:$PORT"
exec python3 - "$PORT" <<'PY'
import http.server, sys

class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, must-revalidate")
        self.send_header("Expires", "0")
        super().end_headers()

http.server.ThreadingHTTPServer(("", int(sys.argv[1])), NoCacheHandler).serve_forever()
PY
