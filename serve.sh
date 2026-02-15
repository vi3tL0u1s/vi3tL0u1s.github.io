#!/usr/bin/env bash
cd "$(dirname "$0")"
echo "Serving at http://127.0.0.1:8000 — same as GitHub Pages. Stop with Ctrl+C."
echo "Remote? On your laptop: ssh -L 8000:127.0.0.1:8000 $(whoami)@$(hostname -f 2>/dev/null || hostname)"
python3 -m http.server 8000
