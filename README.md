# Dune: Imperium Uprising — digital table

A small Godot **4.6** project that tries to keep the board-game loop honest: hands, agents on the map, conflict rounds, CHOAM stuff, intrigue windows — the messy parts included, not a glossy trailer.

## The awkward bit up front (read this)

**Everything here — code, scenes, data plumbing — was built with heavy help from AI tools.** I started with **zero Godot experience**; the editor, GDScript, and the whole “why is this node null again?” journey were new. This repo is **for a tight circle of friends**, not a product pitch. If something looks rough or opinionated, that’s the reason.

If you fork or poke around: you’re welcome to learn from it, but don’t treat it as an official Dune product, a licensed release, or a statement from any rights holder. It’s a hobby fork for people who already own the cardboard and want a screen version on the couch.

## What you’ll find inside

- **Data-driven content**: card and board definitions live under `data/` (JSON), so you can grep your way through a rule without hunting every scene.
- **A real main loop**: main scene is `res://scenes/game_root.tscn` — hotseat flow, UI tied to the same state the rules care about.
- **Sanity checks**: there’s a headless regression runner for rule-contract checks (`tests/runners/headless_regression_runner.gd`). From the repo root (with Godot on your `PATH` or using your local binary):

  ```bash
  godot --headless --path game -s res://tests/runners/headless_regression_runner.gd
  ```

  If things are fine, you should see `HEADLESS_REGRESSION_OK` in the output.

Human-readable rules notes and data contracts live in `info/` (`rules.md`, `rules_en.md`, `data-model.md`, `rule_contract.md`). The old “step 1 MVP” write-up is parked as `info/archive_mvp_step1.md` so nobody mistakes it for today’s scope.

## Running it

1. Install **Godot 4.6** (this project targets the 4.x line with GL Compatibility).
2. Open the `game` folder as the project root.
3. Run the main scene or hit Play — entry point is already set to `game_root.tscn`.

## License / IP

No license file ships here by default. **Dune** and **Dune: Imperium** (and related names) belong to their owners. This project is **non-commercial personal use among friends**; do not use it to compete with or replace the real game. Buy the board game if you want the full experience — the cardboard matters.

---

*Built with AI pair-programming, a lot of coffee, and friends who don’t mind being guinea pigs.*
