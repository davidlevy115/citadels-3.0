# Citadels 3.0 — Rise of the City

A fan-made digital adaptation of Bruno Faidutti's **Citadels**, rebuilt as a real
game-engine experience (think *Magic: The Gathering Arena*) on top of the exact
game logic from the original `citadels` web project.

- **Engine:** [Godot 4.6](https://godotengine.org) (free & open source, MIT)
- **Graphics:** every one of the 8 characters and 28 districts is a **living
  2.5D painting** — the Arena technique. Each full-res painted still is
  re-projected through an AI-generated depth map: the camera drifts on a slow
  orbit, the art tilts toward your mouse on hover, a light sweep glides over
  the relief and rim light catches the silhouettes — all at 60 fps in a
  shader. Per-subject effect layers play on top (a shimmer crowns the King,
  water ripples at the Docks, sparks fly at the Smithy). Fallback chain:
  depth parallax → AnimateDiff motion clip → cinemagraph shader → procedural
  3D diorama. No paid assets anywhere.
- **Art pipeline** (`tools/`): `generate_art_local.py` (sd-turbo stills),
  `generate_depth.py` (Depth-Anything-V2 depth maps) and `generate_motion.py`
  (AnimateDiff-Lightning clips), all running free and offline on Apple
  Silicon via the `~/.venvs/citadels-art` venv.
- **Logic:** a 1:1 GDScript port of `packages/game-logic` (engine, characters,
  scoring, bot AI). Same state machine, same rules, same bot heuristics.
- **Playable in the browser** via the Godot Web (WASM) export — no plugins.

## Play

```bash
# One-time: pull the card media (art/motion/depth, ~30MB) from the GitHub
# release — it is kept out of git so the repository stays tiny.
./tools/fetch_media.sh

# Desktop (needs godot 4.6 in PATH — `brew install --cask godot`)
godot --path .

# Browser
./export_web.sh    # one-time build → build/web/
./serve.sh         # → http://localhost:8060
```

Single player vs 1–6 bot rivals. Online multiplayer is a planned second phase.

## Development

```
logic/      # 1:1 port of the TS game logic (engine.gd, bot.gd, scoring.gd, …)
art/        # procedural 3D model factory + per-card viewport renderer
ui/         # Magic-Arena style table, cards, overlays, menu
scenes/     # Main.tscn (root)
tests/      # headless test runner (63 checks) + probes
```

```bash
# Run the full logic test suite (port of the original vitest suite)
godot --headless --path . --script tests/run_tests.gd

# Boot the real UI headless and auto-play a full game through it
godot --headless --path . -- --smoke

# Capture verification screenshots to /tmp/citadels_*.png
godot --path . -- --shot
```

## Licenses

- Code: same spirit as the parent project; Citadels game design © Bruno Faidutti
  (this is a non-commercial fan project).
- Godot Engine: MIT.
- Fonts (all SIL Open Font License): Cinzel, Cinzel Decorative, EB Garamond,
  Noto Sans Symbols, Noto Sans Symbols 2.
