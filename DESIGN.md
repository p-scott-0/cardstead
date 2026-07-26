# Cardstead — Design Document

Working spec for the game. The JSON files in `data/` are the source of truth
for content; this document explains the rules around them.

## Core loop (v1)

Stack cards → work timers transform them → feed villagers at day end → sell
surplus for coins → buy packs → discover more recipes → grow the village.
Sandbox survival; no win condition yet (see Roadmap).

## The board

- Fixed 3000×2000 world ("the felt"). Camera pans (drag empty space) and
  pinch-zooms (0.5×–1.5×), clamped to the board with a small margin.
- Cards are 140×196. Stacks render with a 38 px vertical fan (10 px for
  coins). Dragging a card picks up that card **and everything above it**.
- Overlapping stacks that aren't stacked together softly push apart each
  physics tick (AABB minimum-translation, capped step — the signature
  "cards ooze aside" feel).
- Two fixed mats: 💰 **Sell** (bottom-left) and 🎴 **Buy** (bottom-right).
  Drop logic: a dropped stack whose bottom card center is inside a mat zone
  triggers the mat instead of stacking.

## Cards (`data/cards.json`)

| Field | Meaning |
|---|---|
| `id` | unique snake_case key referenced everywhere |
| `type` | `unit` / `nature` / `resource` / `food` / `building` / `special` — sets header color |
| `icon` | emoji shown on the card (system emoji font) |
| `sell`, `sellable` | coin value on the sell mat |
| `food_value` | food provided when eaten at day end |
| `charges` | >0 for depletable nature nodes (tree, rock, bush) |
| `eats` | food required per day (villager 2, baby 1) |

Stacking rules: anything stacks on anything, except coins only stack on
coins and card packs never stack (tap a pack to open it).

## Recipes (`data/recipes.json`)

A stack starts work when its contents (order ignored) **exactly** match a
recipe's `inputs` multiset. Exact matching keeps behavior predictable and
lets recipe lookup be one dictionary hit on a canonical signature
(`"tree:1|villager:1"`). Duplicate signatures are a data error (CI fails).

On completion, every input card is consumed **except**:

- `keep`: survives untouched (villager, house, campfire…)
- `decrement`: loses one charge; removed at zero charges (tree, rock, bush)

Outputs spawn beside the stack at the nearest free spot. If the surviving
stack still matches (villager + tree with charges left), work restarts —
villagers keep chopping unattended. Changing a working stack's contents
resets its timer and re-matches.

Passive recipes (no villager input): `grow_baby`, `plant_berry_bush`,
`grow_wheat`.

## Day cycle

- A day lasts 120 s (HUD bar). At day end the game pauses and feeding runs:
  total need = Σ`eats`; food cards are consumed smallest `food_value` first
  (whole cards, overshoot wasted). Remaining need starves units — babies
  die first, then villagers. All dead → game over, save cleared.
- Summary popup shows fed/eaten/starved, then "Start Day N+1" resumes and
  autosaves.

## Economy

- **Sell mat:** each sellable card in the dropped stack converts to `sell`
  coins (spawned as coin cards; coins auto-merge into a nearby coin stack).
  Non-sellable cards bounce off beside the mat.
- **Buy mat:** parks dropped coins (`n/3` shown); at 3 it dispenses a card
  pack. Packs (`data/packs.json`) roll `count` weighted draws.

## Save (`user://save.json`, schema 1)

Temp-file write then rename, so a mid-write kill can't corrupt the previous
save. Autosave every 20 s + at day end + on iOS backgrounding
(`NOTIFICATION_APPLICATION_PAUSED` / `FOCUS_OUT`).

```json
{ "schema": 1, "version": "0.1.0", "saved_at": 1784200000,
  "day": 4, "day_time": 63.2, "sound": true,
  "discovered": { "cards": ["…"], "recipes": ["…"] },
  "board": { "stacks": [ { "x": 812.5, "y": 400.0,
      "cards": [ { "id": "tree", "charges": 2 }, { "id": "villager" } ],
      "work": { "recipe": "chop_wood", "t": 2.5 } } ],
    "buy_coins": 1 },
  "camera": { "x": 1500, "y": 1000, "zoom": 0.75 } }
```

Unknown card ids in a save are skipped with a warning (forward
compatibility); saved work timers are revalidated against the current
recipe match before resuming.

## Architecture

```
Main (scenes/main.tscn + scripts/main.gd — builds everything in code)
├── Board (scripts/board.gd)        input routing, stacks, recipes, mats, feed, serialize
│   └── CardLayer                    flat CardNode children; array order = draw order
├── CameraRig (camera_rig.gd)       pan / pinch / wheel zoom, clamped
└── UI CanvasLayer
    ├── Hud (ui/hud.gd)             day bar, coins, buttons (mouse-transparent)
    ├── DaySummaryPopup             pause-mode popup
    ├── RecipeBook                  discovered-recipe list
    └── MainMenu                    boot / pause / game-over overlay

Autoloads: Db (data load+validate) · GameState (day FSM, discovery)
           SaveMgr (autosave, lifecycle) · Sfx (WAV pool)
Plain classes: StackData, CardNode, MatNode, RecipeEngine (static matching)
```

Stacks are a **logical list + flat nodes** (not nested parent/child): drag =
array slice, save = direct dump, push-apart = one AABB per stack.

## Tests

- `tools/smoke_test.gd` — data cross-validation, every script compiles,
  main scene loads. (`--script`, no game boot.)
- `tools/sim_runner.gd` — boots the real game headless (`-- --sim-test`) and
  drives it: chop loop with charge depletion, recipe switching, sell/merge,
  buy/open pack, feeding + starvation, save/load roundtrip byte-equality,
  day state machine. CI runs both on every push.

## Tuning constants

`Board`: TAP 350 ms / 14 px · separation rate 6/s (step cap 40) ·
coin-merge radius 260. `StackData`: fan 38 px / coins 10 px.
`GameState.DAY_LENGTH`: 120 s. `CameraRig`: zoom 0.5–1.5.

## Roadmap

- **v2 — combat:** enemy cards, weapons, HP; likely a `combat` recipe class.
- Quests/goals checklist; more packs and card tiers; equipment.
- iCloud-free save export/import (copy JSON).
- ~~If system emoji ever fails on a device, bundle a fallback emoji font~~
  Done in v0.2.0: `assets/fonts/TwemojiMozilla.ttf` (COLR) is the icon font
  everywhere — system emoji proved unrenderable on iOS and incomplete on
  Windows 10. The sim test asserts glyph coverage for every icon (T12).
- Day-end: animate the eaten cards on the board itself (they currently
  disappear behind the summary popup, which lists them instead).
