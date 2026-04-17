# Card UI Breakage Inventory (Phase 1)

This inventory is generated from `data/cards_uprising.json` by ranking cards with nested `if`/`choice` effect trees (depth, branching, and leaf count).

## Ranking method

- +3 for each `if` node.
- +3 for each `choice` node.
- +2 for max nesting depth.
- +1 for each effect leaf above baseline complexity.

The list focuses on cards that are most likely to render poorly in compact icon-first strips.

## First migration batch (highest priority)

1. `imperium_delivery_agreement`
2. `imperium_priority_contracts`
3. `imperium_corrinth_city`
4. `imperium_desert_power`
5. `imperium_junction_headquarters`
6. `imperium_tread_in_darkness`
7. `imperium_space_time_folding`
8. `imperium_guild_spy`
9. `imperium_captured_mentat`
10. `imperium_branching_path`
11. `imperium_smuggler_s_haven`
12. `imperium_shishakli`

## Secondary batch

- `imperium_ecological_testing_station`
- `imperium_southern_elders`
- `imperium_maker_keeper`
- `imperium_spacing_guild_s_favor`
- `imperium_rebel_supplier`
- `imperium_hidden_missive`
- `imperium_strike_fleet`
- `imperium_public_spectacle`
- `imperium_northern_watermaster`
- `imperium_imperial_spymaster`

## Notes

- Inventory is deterministic and data-driven.
- Runtime behavior is not changed by this file; it is used to prioritize UI rendering refactor work.
