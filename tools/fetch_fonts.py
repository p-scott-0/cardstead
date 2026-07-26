#!/usr/bin/env python3
"""Download the Twemoji Mozilla color emoji font (COLR/CPAL — renders in
Godot on every platform) into assets/fonts/. Run once from the repo root;
the ttf is committed so CI never needs the network.

  python tools/fetch_fonts.py
"""
import hashlib
import json
import urllib.request
from pathlib import Path

API = "https://api.github.com/repos/mozilla/twemoji-colr/releases/latest"
OUT = Path(__file__).resolve().parent.parent / "assets" / "fonts" / "TwemojiMozilla.ttf"
UA = {"User-Agent": "cardstead-font-fetch"}


def main():
    rel = json.load(urllib.request.urlopen(urllib.request.Request(API, headers=UA), timeout=60))
    asset = next(a for a in rel["assets"] if a["name"].lower().endswith(".ttf"))
    print(f"release: {rel['tag_name']}  asset: {asset['name']}  {asset['size']} bytes")
    data = urllib.request.urlopen(
        urllib.request.Request(asset["browser_download_url"], headers=UA), timeout=300).read()
    if len(data) != asset["size"]:
        raise SystemExit(f"size mismatch: got {len(data)}, expected {asset['size']}")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(data)
    print(f"wrote {OUT}")
    print(f"sha256: {hashlib.sha256(data).hexdigest()}")


if __name__ == "__main__":
    main()
