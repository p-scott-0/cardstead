#!/usr/bin/env python3
"""Serve the web export over the LAN for quick touch-feel testing on the
phone's browser (no caching, so every reload picks up a fresh export).

  1. Export:  godot --headless --export-debug "Web" build/web/index.html
  2. Serve:   python tools/serve_web.py
  3. iPhone Safari -> http://<this PC's LAN IP>:8000
"""
import http.server
import socket
from pathlib import Path

PORT = 8000
WEB_DIR = Path(__file__).resolve().parent.parent / "build" / "web"


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(WEB_DIR), **kwargs)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store, must-revalidate")
        super().end_headers()


def lan_ips():
    ips = set()
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ips.add(s.getsockname()[0])
        s.close()
    except OSError:
        pass
    return sorted(ips) or ["<your-LAN-IP>"]


if __name__ == "__main__":
    if not WEB_DIR.exists():
        raise SystemExit("build/web not found — export the Web preset first.")
    for ip in lan_ips():
        print(f"  Phone URL: http://{ip}:{PORT}")
    http.server.ThreadingHTTPServer(("0.0.0.0", PORT), NoCacheHandler).serve_forever()
