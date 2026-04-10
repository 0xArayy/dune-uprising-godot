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
