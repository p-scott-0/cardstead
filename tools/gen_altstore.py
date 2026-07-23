#!/usr/bin/env python3
"""Regenerate altstore.json (the AltStore custom source) for the current
build. Called by CI after each rolling release. Keeps exactly one entry in
versions[] because the rolling release URL always points at the newest IPA.

Example:
  python3 tools/gen_altstore.py --version 0.1.0 --size 12345678 \
      --date 2026-07-23 \
      --url https://github.com/OWNER/REPO/releases/download/latest/Cardstead.ipa \
      --repo https://github.com/OWNER/REPO --out altstore.json
"""
import argparse
import json
from pathlib import Path

BUNDLE_ID = "com.pscott.cardstead"
MIN_IOS = "14.0"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", required=True)
    ap.add_argument("--size", required=True, type=int)
    ap.add_argument("--date", required=True)
    ap.add_argument("--url", required=True)
    ap.add_argument("--repo", required=True, help="https://github.com/OWNER/REPO")
    ap.add_argument("--out", default="altstore.json")
    args = ap.parse_args()

    raw_base = args.repo.replace("github.com", "raw.githubusercontent.com") + "/main"
    icon_url = f"{raw_base}/icon_ios_1024.png"

    source = {
        "name": "Cardstead Source",
        "identifier": f"{BUNDLE_ID}.source",
        "subtitle": "A tiny card-stacking village game",
        "website": args.repo,
        "apps": [
            {
                "name": "Cardstead",
                "bundleIdentifier": BUNDLE_ID,
                "developerName": "p-scott-0",
                "subtitle": "Stack cards, feed villagers, survive the days.",
                "localizedDescription": (
                    "Cardstead is a cozy card-stacking village game. Drag cards "
                    "onto each other to harvest resources, cook food, raise "
                    "villagers, and keep everyone fed at the end of each day.\n\n"
                    "Sell spare cards for coins and buy card packs to grow your "
                    "village. Original mechanics-inspired homage, built with "
                    "Godot."
                ),
                "iconURL": icon_url,
                "tintColor": "3f78c8",
                "category": "games",
                "screenshots": [],
                "versions": [
                    {
                        "version": args.version,
                        "date": args.date,
                        "localizedDescription": f"Rolling build v{args.version}.",
                        "downloadURL": args.url,
                        "size": args.size,
                        "minOSVersion": MIN_IOS,
                    }
                ],
                "appPermissions": {"entitlements": [], "privacy": {}},
            }
        ],
        "news": [],
    }

    out = Path(args.out)
    out.write_text(json.dumps(source, indent=2) + "\n", encoding="utf-8")
    # validity gate: re-read what we just wrote
    json.loads(out.read_text(encoding="utf-8"))
    print(f"wrote {out}: v{args.version}, {args.size} bytes, {args.date}")


if __name__ == "__main__":
    main()
