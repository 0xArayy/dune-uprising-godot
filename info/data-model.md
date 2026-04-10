# Dune: Imperium Uprising - Data Model (Step 2)

This document defines the current data model contract for the refactored game core.

## Modeling assumptions

- 4-player hotseat target (`p1..p4`) with deterministic local state progression
- no online state synchronization
- no AI player state
- spies, sandworms, Shield Wall, CHOAM contracts and intrigue windows are part of the active ruleset

## Entity: `GameState`

Represents the full current game snapshot.

| Field | Type | Description |
|---|---|---|
| `id` | string | Unique game id |
| `version` | number | Incremented on each state mutation |
| `status` | enum(`setup`,`in_progress`,`finished`) | Global lifecycle status |
| `round` | number | Current round number (starts at 1) |
| `phase` | enum(`round_start`,`player_turns`,`conflict`,`makers`,`recall`) | Active phase |
| `currentPlayerId` | string | Player whose turn is active |
| `firstPlayerId` | string | Player holding first-player marker |
| `players` | `PlayerState[]` | 3-4 players in turn order (standard target: 4) |
| `imperiumDeck` | string[] | Stack of `CardDef.id` (top at end or start, chosen consistently) |
| `imperiumMarket` | string[] | Visible market cards (target size 5) |
| `reserveCards` | object | Reserve piles, e.g. `preparations`, `spiceMustFlow` |
| `conflictDeck` | string[] | Stack of `ConflictCardDef.id` |
| `conflictDeckTotal` | number | Total initial size for UI/debug tracking |
| `activeConflictCardId` | string \| null | Current revealed conflict card |
| `activeConflictCardDef` | object \| null | Current revealed conflict definition snapshot |
| `boardOccupancy` | object | Map `boardSpaceId -> occupyingPlayerId/agentId/null` |
| `conflictZone` | object | Per-player units currently committed to conflict |
| `intriguesById` | object | Intrigue definitions |
| `intrigueDeck` | string[] | Intrigue draw pile |
| `intrigueDiscard` | string[] | Intrigue discard pile |
| `choamContractsById` | object | CHOAM contract definitions |
| `choamContractDeck` | string[] | CHOAM contract deck |
| `choamFaceUpContracts` | string[] | Current face-up contracts |
| `makerSpice` | object | Spice currently on maker spaces |
| `controlBySpace` | object | Control owner by board space id |
| `factionAlliances` | object | Alliance owner by faction id |
| `shieldWallIntact` | boolean | Shield Wall lifecycle flag |
| `bank` | object | Shared resource pool (optional, if finite bank is modeled) |
| `winnerPlayerId` | string \| null | Winner when game finishes |
| `log` | `GameEvent[]` | Optional event history for debugging/replay |

### Suggested `conflictZone` shape

```ts
type ConflictZone = {
  [playerId: string]: {
    troops: number;
    revealedSwordPower: number;
    totalPower: number;
  };
};
```

## Entity: `PlayerState`

Represents one player's private and public state.

| Field | Type | Description |
|---|---|---|
| `id` | string | Player id |
| `name` | string | Display name for hotseat UI |
| `seatIndex` | number | 0 or 1 (turn order index) |
| `vp` | number | Victory points |
| `resources` | object | `{solari, spice, water}` |
| `deck` | string[] | Draw pile of `CardDef.id` |
| `hand` | string[] | Current hand cards |
| `discard` | string[] | Discard pile |
| `inPlay` | string[] | Cards played this round (agent/reveal context) |
| `agentsTotal` | number | Usually 2 in MVP (3rd agent system optional) |
| `agentsAvailable` | number | Agents not yet committed this round |
| `agentsOnBoard` | string[] | Occupied `boardSpaceId` by this player's agents |
| `garrisonTroops` | number | Troops in garrison |
| `troopsInConflict` | number | Troops currently in conflict zone |
| `influence` | object | `{emperor, guild, beneGesserit, fremen}` |
| `alliances` | object | Boolean ownership by faction (optional in MVP core) |
| `persuasion` | number | Round-local buying currency, reset by flow |
| `revealedSwordPower` | number | Round-local combat from reveal effects |
| `passedReveal` | boolean | True once player revealed cards in current round |

## Entity: `CardDef`

Static definition of a playable deck card.

| Field | Type | Description |
|---|---|---|
| `id` | string | Unique card id |
| `name` | string | Localized display name |
| `source` | enum(`starter`,`imperium`,`reserve`) | Card origin |
| `cost` | number | Persuasion cost for purchase |
| `agentIcons` | string[] | Allowed placement symbols for agent action |
| `agentEffect` | `Effect[]` | Effects resolved when used for sending agent |
| `revealEffect` | `Effect[]` | Effects resolved when revealed |
| `faction` | enum \| null | Optional faction tag |
| `purchaseBonus` | `Effect[]` | One-time bonus when purchased |
| `isUnique` | boolean | Optional uniqueness marker |
| `tags` | string[] | Search/filter tags for UI and logic |

### Suggested minimal `Effect` format

```ts
type Effect =
  | { type: "gain_resource"; resource: "solari" | "spice" | "water"; amount: number }
  | { type: "spend_resource"; resource: "solari" | "spice" | "water"; amount: number }
  | { type: "gain_persuasion"; amount: number }
  | { type: "gain_sword"; amount: number }
  | { type: "draw_cards"; amount: number }
  | { type: "draw_intrigue"; amount: number }
  | { type: "recruit_troops"; amount: number }
  | { type: "gain_influence"; faction: "emperor" | "guild" | "beneGesserit" | "fremen"; amount: number }
  | { type: "trash_card"; from: "hand" | "discard" | "in_play"; amount: number }
  | { type: "place_spy"; amount: number; constraint?: { connectedToAgentIcon?: string } }
  | { type: "get_contract"; amount: number; fallbackEffects?: Effect[] }
  | { type: "recall_agent"; amount: number; excludeJustPlaced?: boolean }
  | { type: "gain_agent"; which: "swordmaster"; amount: 1 }
  | { type: "gain_maker_hooks"; amount: 1; ifAlreadyHas?: "skip" | "still_apply_other_effects" }
  | { type: "collect_maker_spice"; boardSpaceId: string }
  | { type: "summon_sandworm"; amount: number }
  | { type: "remove_shield_wall"; amount: 1 }
  | { type: "set_flag"; key: string; value: boolean }
  | { type: "if"; requirement: Requirement; then: Effect[]; else?: Effect[] }
  | { type: "choice"; options: { label?: string; effects: Effect[] }[] };
```

## Entity: `BoardSpaceDef`

Static definition of one board space.

| Field | Type | Description |
|---|---|---|
| `id` | string | Unique space id |
| `name` | string | Localized UI name |
| `area` | enum(`emperor`,`guild`,`beneGesserit`,`fremen`,`landsraad`,`city`,`spice`) | Board area/category |
| `requiredAgentIcons` | string[] | Which icons allow access |
| `cost` | `Cost[]` | Mandatory cost before resolving effects |
| `requirements` | `Requirement[]` | Additional conditions (e.g. min influence) |
| `effects` | `Effect[]` | Immediate space effects |
| `isConflictSpace` | boolean | Allows conflict troop commitment |
| `makerSpace` | boolean | Accumulates spice in maker phase |
| `maxOccupancy` | number | Usually 1 in MVP |

### Suggested support types

```ts
type Cost =
  | { type: "resource"; resource: "solari" | "spice" | "water"; amount: number };

type Requirement =
  | { type: "min_influence"; faction: "emperor" | "guild" | "beneGesserit" | "fremen"; value: number }
  | { type: "has_maker_hooks"; value: boolean }
  | { type: "flag"; key: string; value: boolean };
```

## Entity: `ConflictCardDef`

Static definition of one conflict card.

| Field | Type | Description |
|---|---|---|
| `id` | string | Unique conflict card id |
| `name` | string | Card display name |
| `level` | enum(`I`,`II`,`III`) | Deck tier |
| `firstReward` | `Reward[]` | Reward for highest power |
| `secondReward` | `Reward[]` | Reward for second place |
| `thirdReward` | `Reward[]` | Kept for compatibility (unused in 2-player) |
| `controlSpaceId` | string \| null | If card grants location control |
| `battleSymbol` | enum(`crysknife`,`desertMouse`,`ornithopter`,null) | Optional symbol |

### Suggested reward format

```ts
type Reward =
  | { type: "vp"; amount: number }
  | { type: "resource"; resource: "solari" | "spice" | "water"; amount: number }
  | { type: "recruit_troops"; amount: number }
  | { type: "gain_influence"; faction: "emperor" | "guild" | "beneGesserit" | "fremen"; amount: number }
  | { type: "gain_control"; boardSpaceId: string };
```

## Optional helper entities (recommended)

- `GameEvent`: append-only action/event log for debugging and replay.
- `RulesConfig`: flags for enabling/disabling optional systems.
- `SetupConfig`: seed, selected starting decks, and deterministic setup options.

## MVP validation checklist

- `GameState` fully reconstructs game without hidden external variables.
- `PlayerState` is enough to run legal turn generation and conflict scoring.
- `CardDef` and `BoardSpaceDef` are purely declarative (no hardcoded card logic).
- `ConflictCardDef` supports 2-player reward resolution without special branching.
- Out-of-scope mechanics are not required by schema to execute the core loop.
