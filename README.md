# Cardstead 🃏

A tiny card-stacking village game for iOS (and desktop), built with Godot 4.
Drag cards onto each other to harvest resources, cook food, raise villagers,
and keep everyone fed at the end of each day. Sell spare cards for coins and
buy card packs to grow the village.

Original mechanics-inspired homage to the card-stacking village genre — all
code, art, and audio in this repo are original.

- **Engine:** Godot 4.7.1 (GDScript), 2D mobile renderer, landscape
- **iOS install:** sideloaded with [AltStore](https://altstore.io) — no Mac,
  no paid developer account
- **Builds:** GitHub Actions (macOS runner) produces an unsigned IPA on every
  push to `main`; AltStore re-signs it on your phone

---

## Install on iPhone

One-time setup (Windows PC + iPhone):

1. Install **iTunes** and **iCloud** from Apple's website (NOT the Microsoft
   Store versions — AltServer needs the Apple installers).
2. Install **AltServer** from [altstore.io](https://altstore.io) and run it
   (it lives in the system tray).
3. Connect the iPhone by USB, then AltServer tray icon → *Install AltStore* →
   pick your device, sign in with your Apple ID. While it's plugged in, turn on
   **"Sync with this iPhone over Wi-Fi"** in iTunes so AltServer can reach the
   phone later without the cable, and allow AltServer through Windows Firewall
   on the *private* network profile.
4. On the phone: Settings → General → VPN & Device Management → trust your
   Apple ID profile. On iOS 16+: Settings → Privacy & Security → enable
   **Developer Mode** if prompted.

Install Cardstead:

5. In AltStore on the phone: **Sources → + →** add
   `https://raw.githubusercontent.com/p-scott-0/cardstead/main/altstore.json`
6. Install **Cardstead** from that source.

Updating: new builds appear in AltStore's **Updates** tab after each push to
`main` — tap update, done. Save data survives updates (same bundle id).

Notes on free-Apple-ID sideloading:

- Apps expire after **7 days**; AltStore auto-refreshes in the background
  while your phone and a PC running AltServer are on the same local network.
  A PC wired by ethernet to the same router that serves the Wi-Fi counts —
  AltServer is discovered over Bonjour/mDNS, which crosses the wired and
  wireless halves of one network fine. What breaks it is the phone being on a
  *different* network: a guest SSID, a separate VLAN/subnet, or a router with
  AP/client isolation enabled. If it ever lapses, open AltStore and tap
  Refresh — your save is untouched.
- A free Apple ID can have **3 sideloaded apps** installed at once (AltStore
  itself counts as one) and creates at most 10 new app IDs per week.
- Deleting the app deletes its save.

## How to play

- **Drag** a card onto another to stack. Matching stacks start work
  (progress bar): Villager + Tree chops Wood, Soil + Wheat Seed grows Wheat,
  two Villagers + House makes a Baby, and so on. Open the 📖 Recipe Book to
  see what you've discovered.
- **Day timer:** when the bar fills, everyone eats (villagers 2 food, babies
  1). Hungry villagers die. Keep food on the board.
- **Sell mat:** drop cards on 💰 to turn them into coins.
- **Buy mat:** drop 3 coins on 🎴 to get a card pack; tap a pack to open it.
- **Pan** by dragging empty felt, **pinch** to zoom.

On a PC the game plays the same with a mouse: **left-drag** a card to move or
stack it, **left-drag empty felt** to pan, **mouse wheel** to zoom, **click** a
card pack to open it. (Godot converts mouse input into the same touch events
the phone sends, so desktop and phone run identical code — the test suite
drives both paths.)

## Development (Windows, no Mac needed)

- Install [Godot 4.7.1](https://godotengine.org/download/archive/) and open
  the repo folder. F5 runs the game (mouse emulates touch).
- Data-driven content: edit `data/cards.json`, `data/recipes.json`,
  `data/packs.json`. `DESIGN.md` documents the rules and schemas.
- Regenerate assets if needed: `python tools/make_icons.py`,
  `python tools/make_sfx.py`.
- Headless tests (also run in CI on every push):

  ```
  godot --headless --path . --script res://tools/smoke_test.gd
  godot --headless --path . -- --sim-test
  ```

- Quick touch-feel testing on the phone without waiting for CI: export the
  Web preset, run `python tools/serve_web.py`, open the printed URL in iPhone
  Safari (same Wi-Fi). Input feel only — saves and performance are not
  representative.

## Release pipeline

- Push to `main` → `.github/workflows/ios.yml` (macOS runner) exports the
  Godot iOS Xcode project (`export_project_only`), builds it **unsigned**
  (`CODE_SIGNING_ALLOWED=NO`), zips `Payload/` into `Cardstead.ipa`,
  refreshes the rolling `latest` release (fixed download URL), and rewrites
  `altstore.json` with the new version/size — which is what makes the update
  appear in AltStore.
- Tag `vX.Y.Z` → additionally creates a permanent versioned release.
- Bump the version by editing `config/version` in `project.godot`.
- The repo must stay **public**: AltStore downloads release assets without
  auth, and public repos get free macOS Actions minutes.

## License

MIT — see [LICENSE](LICENSE).

Card icons render with the bundled [Twemoji Mozilla](https://github.com/mozilla/twemoji-colr)
color font — Twemoji artwork © Twitter, Inc and contributors (CC-BY 4.0),
font packaging by Mozilla (Apache 2.0). See
[assets/fonts/LICENSE-Twemoji.txt](assets/fonts/LICENSE-Twemoji.txt).
