# Rule Contract (Refactor Safety)

This file defines behavior that must stay unchanged during refactoring.

## Phase Order
- `round_start -> player_turns -> conflict -> makers -> recall`

## Endgame Triggers
- Endgame is checked after round completion.
- Endgame trigger: any player reaches `10+ VP`, or the conflict deck is exhausted.

## Tie-Break Chain
- Highest VP.
- If tied: highest spice.
- If tied: highest solari.
- If tied: highest water.
- If tied: highest troops in garrison.
- If tied: most recent reveal turn order.

## Combat Power Formula
- `troops * 2 + sandworms * 3 + revealed_sword_power`.
- If a player has no units in conflict (`troops == 0 && sandworms == 0`), combat power is `0`.

## Sandworm and Shield Wall
- Sandworm summon restrictions remain tied to shield wall and conflict type.
- Sandworm reward doubling must not apply to control rewards.

## Spy Rules
- Spy cap and recall-first behavior at cap are preserved.
- Infiltration and gather-intelligence flow must remain consistent with existing game logic.

## Automated regression (`tests/contracts/`)

Headless entrypoint: `res://tests/runners/headless_regression_runner.gd` (prints `HEADLESS_REGRESSION_OK`). `tests/contracts/rule_contract_regression.gd` aggregates inline checks plus:

- **effect_dsl_regression.gd** — JSON effect aliases (`resource`, `intrigue`, `contract`, `deploy_recruited_to_conflict`), `fremen_bond` → `if`/`choice`, `gain_influence` + `anyone`, nested `choice`/`if` normalization.
- **conflict_ranking_regression.gd** — `ConflictResolutionRules.compute_ranking_groups` (distinct powers, ties, all tied) and `build_power_snapshots` participant filtering (swords-only excluded).
- **conflict_rewards_regression.gd** — `ConflictRewardsService.apply_reward`: VP scales with sandworm-style multiplier; `gain_control` does not double VP and sets control once.
- **spy_system_regression.gd** — `SpySystem.place_spy`: success, cap `MAX_SPIES_PER_PLAYER`, occupied post rejection.
- **deck_intrigue_regression.gd** — `DeckService.reshuffle_intrigue_discard_if_needed` and `draw_intrigue` bounds (no full UI/E2E).
- **game_state_shape_regression.gd** — `RuleContract.validate_game_state_shape` valid/invalid cases.

Shield Wall on-board summon blocking and full hotseat flows are not covered here; use manual QA or future integration scenarios.
