extends RefCounted
class_name TurnCommandHandler

const SpySystemScript = preload("res://scripts/spy_system.gd")
const ContractServiceScript = preload("res://scripts/contract_service.gd")

var owner: TurnController
var deck_service: DeckService

func _init(owner_ref: TurnController, deck_service_ref: DeckService) -> void:
	owner = owner_ref
	deck_service = deck_service_ref

func handle_send_agent(game_state, board_map, space_id, played_card, agent_id = null, context = {}) -> Dictionary:
	if game_state.get("phase", "") != "player_turns":
		return {"ok": false, "reason": "wrong_phase"}

	var player = owner._get_current_player(game_state)
	if player == null:
		return {"ok": false, "reason": "no_current_player"}
	if bool(player.get("passedReveal", false)):
		return {"ok": false, "reason": "player_already_revealed"}
	if int(player.get("agentsAvailable", 0)) <= 0:
		return {"ok": false, "reason": "no_agents_available"}

	var played_card_id = owner._resolve_played_card_id(played_card)
	if played_card_id == "":
		return {"ok": false, "reason": "invalid_played_card"}
	if not owner._hand_contains_card(player, played_card_id):
		return {"ok": false, "reason": "played_card_not_in_hand"}

	var played_card_def = owner._build_played_card_for_board(game_state, played_card_id)
	if played_card_def.is_empty():
		return {"ok": false, "reason": "unknown_played_card"}

	var turn_context = context.duplicate(true)
	turn_context["played_card"] = played_card_def
	if agent_id != null:
		turn_context["agent_id"] = agent_id
	if context.has("choice_indexes"):
		turn_context["choice_indexes"] = context["choice_indexes"]
	player["turnFlags"] = {
		"sent_agent_to_maker_space_this_turn": false,
		"sent_agent_to_faction_space_this_turn": false,
		"recalled_spy_this_turn": false
	}

	var result = board_map.take_agent_turn(space_id, player, game_state, turn_context)
	if not result.get("ok", false):
		return result

	var agent_effects = played_card_def.get("agentEffect", [])
	var resolved_effect_context: Dictionary = {}
	if typeof(agent_effects) == TYPE_ARRAY and not agent_effects.is_empty():
		var sent_agent_to_maker_space_this_turn := false
		var sent_agent_to_faction_space_this_turn := false
		if board_map != null and board_map.has_method("get_board_space"):
			var placed_space_def: Variant = board_map.get_board_space(space_id)
			if typeof(placed_space_def) == TYPE_DICTIONARY:
				sent_agent_to_maker_space_this_turn = bool(placed_space_def.get("makerSpace", false))
				var area_id := str(placed_space_def.get("area", ""))
				sent_agent_to_faction_space_this_turn = area_id in ["guild", "fremen", "emperor", "beneGesserit"]
		var turn_flags_raw = player.get("turnFlags", {})
		var turn_flags: Dictionary = turn_flags_raw if typeof(turn_flags_raw) == TYPE_DICTIONARY else {}
		turn_flags["sent_agent_to_maker_space_this_turn"] = sent_agent_to_maker_space_this_turn
		turn_flags["sent_agent_to_faction_space_this_turn"] = sent_agent_to_faction_space_this_turn
		turn_flags["recalled_spy_this_turn"] = bool(result.get("spyRecalledForOccupied", false))
		player["turnFlags"] = turn_flags
		if board_map != null and board_map.has_method("resolve_space_effects"):
			var effect_context := {
				"context": "agent",
				"card_id": played_card_id,
				"space_id": str(space_id),
				"sent_agent_to_maker_space_this_turn": sent_agent_to_maker_space_this_turn,
				"sent_agent_to_faction_space_this_turn": sent_agent_to_faction_space_this_turn,
				"recalled_spy_this_turn": bool(result.get("spyRecalledForOccupied", false))
			}
			resolved_effect_context = effect_context
			var resolve_result := _resolve_card_effect_with_player_choice(
				game_state,
				board_map,
				player,
				"agent",
				played_card_id,
				agent_effects,
				effect_context,
				{
					"spaceId": str(space_id),
					"spyRecalledForOccupied": bool(result.get("spyRecalledForOccupied", false))
				}
			)
			if bool(resolve_result.get("awaitingInteraction", false)):
				deck_service.move_card_hand_to_in_play(player, played_card_id)
				_maybe_return_agent_card_to_hand(player, played_card_id, effect_context)
				owner._resolve_pending_effects(game_state, player, board_map, "send_agent")
				owner._bump_state_version(game_state)
				return {"ok": true, "awaitingInteraction": true}
		else:
			owner._apply_reveal_effects_fallback(player, agent_effects)

	deck_service.move_card_hand_to_in_play(player, played_card_id)
	_maybe_return_agent_card_to_hand(player, played_card_id, resolved_effect_context)
	owner._resolve_pending_effects(game_state, player, board_map, "send_agent")
	if board_map != null and board_map.has_method("resolve_contract_completions_for_space"):
		var completion_result: Dictionary = board_map.resolve_contract_completions_for_space(player, game_state, str(space_id))
		if int(completion_result.get("completedCount", 0)) > 0:
			owner._resolve_pending_effects(game_state, player, board_map, "contract_completion")
	if not bool(result.get("spyRecalledForOccupied", false)):
		_prepare_optional_spy_recall_draw(game_state, player, space_id)
	if owner.has_pending_player_interaction(game_state):
		owner._bump_state_version(game_state)
		return {"ok": true, "awaitingInteraction": true}
	owner._advance_to_next_active_player(game_state)
	owner._bump_state_version(game_state)
	return result

func _maybe_return_agent_card_to_hand(player: Dictionary, card_id: String, effect_context: Dictionary) -> void:
	if card_id == "":
		return
	if typeof(effect_context) != TYPE_DICTIONARY:
		return
	if not bool(effect_context.get("return_this_card_to_hand", false)):
		return
	deck_service.move_card_in_play_to_hand(player, card_id)

func handle_reveal(game_state, board_map = null) -> Dictionary:
	if game_state.get("phase", "") != "player_turns":
		return {"ok": false, "reason": "wrong_phase"}

	var player = owner._get_current_player(game_state)
	if player == null:
		return {"ok": false, "reason": "no_current_player"}
	if bool(player.get("passedReveal", false)):
		return {"ok": false, "reason": "player_already_revealed"}

	var reveal_result := _resolve_reveal_effects_with_choices(game_state, board_map, player)
	if bool(reveal_result.get("awaitingInteraction", false)):
		owner._resolve_pending_effects(game_state, player, board_map, "reveal")
		owner._bump_state_version(game_state)
		return {"ok": true, "phaseFinished": false, "awaitingInteraction": true}
	owner._resolve_pending_effects(game_state, player, board_map, "reveal")
	deck_service.move_all_hand_to_in_play(player)
	player["passedReveal"] = true
	var reveal_counter := int(game_state.get("revealOrderCounter", 0)) + 1
	game_state["revealOrderCounter"] = reveal_counter
	player["lastRevealOrder"] = reveal_counter
	owner._append_log(game_state, {
		"type": "player_revealed",
		"playerId": str(player.get("id", ""))
	})
	owner._bump_state_version(game_state)
	return {"ok": true, "phaseFinished": false}

func handle_buy_market_card(game_state, card_id: String, board_map = null) -> Dictionary:
	if game_state.get("phase", "") != "player_turns":
		return {"ok": false, "reason": "wrong_phase"}
	if card_id == "":
		return {"ok": false, "reason": "empty_card_id"}

	var player = owner._get_current_player(game_state)
	if player == null:
		return {"ok": false, "reason": "no_current_player"}
	if not bool(player.get("passedReveal", false)):
		return {"ok": false, "reason": "must_reveal_before_buy"}

	var cards_by_id = game_state.get("cardsById", {})
	if typeof(cards_by_id) != TYPE_DICTIONARY or not cards_by_id.has(card_id):
		return {"ok": false, "reason": "unknown_card"}

	var card_def = cards_by_id[card_id]
	if typeof(card_def) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "invalid_card_def"}

	var location = owner._find_market_location(game_state, card_id)
	if not bool(location.get("ok", false)):
		return location

	var cost := int(card_def.get("cost", 0))
	var persuasion := int(player.get("persuasion", 0))
	if persuasion < cost:
		return {
			"ok": false,
			"reason": "insufficient_persuasion",
			"required": cost,
			"current": persuasion
		}

	player["persuasion"] = persuasion - cost
	owner._gain_card_to_discard(player, card_id)

	if str(location.get("source", "")) == "market":
		var purchased_slot_index := owner._remove_market_card(game_state, card_id)
		owner._refill_imperium_market(game_state, purchased_slot_index)
	elif str(location.get("source", "")) == "reserve":
		var pile_id := str(location.get("pileId", ""))
		if not owner._remove_reserve_card(game_state, pile_id, card_id):
			return {"ok": false, "reason": "failed_to_remove_reserve_card"}

	var purchase_bonus = card_def.get("purchaseBonus", [])
	if typeof(purchase_bonus) == TYPE_ARRAY and not purchase_bonus.is_empty():
		if board_map != null and board_map.has_method("resolve_space_effects"):
			var resolve_result := _resolve_card_effect_with_player_choice(game_state, board_map, player, "purchase", card_id, purchase_bonus, {
				"context": "purchase",
				"card_id": card_id
			}, {})
			if bool(resolve_result.get("awaitingInteraction", false)):
				owner._append_log(game_state, {
					"type": "market_card_bought",
					"playerId": str(player.get("id", "")),
					"cardId": card_id,
					"cost": cost,
					"source": str(location.get("source", ""))
				})
				owner._bump_state_version(game_state)
				return {"ok": true, "awaitingInteraction": true}
		else:
			owner._apply_reveal_effects_fallback(player, purchase_bonus)
		owner._resolve_pending_effects(game_state, player, board_map, "purchase")

	owner._append_log(game_state, {
		"type": "market_card_bought",
		"playerId": str(player.get("id", "")),
		"cardId": card_id,
		"cost": cost,
		"source": str(location.get("source", ""))
	})
	owner._bump_state_version(game_state)

	return {
		"ok": true,
		"cardId": card_id,
		"cost": cost,
		"source": str(location.get("source", ""))
	}

func handle_pending_card_choice(game_state, board_map, slot: int, option_index: int) -> Dictionary:
	var player = owner._get_current_player(game_state)
	if player == null:
		return {"ok": false, "reason": "no_current_player"}
	var pending_raw: Variant = player.get("pendingCardChoice", {})
	if typeof(pending_raw) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "no_pending_card_choice"}
	var pending: Dictionary = pending_raw
	if pending.is_empty():
		return {"ok": false, "reason": "no_pending_card_choice"}
	var choice_indexes_raw: Variant = pending.get("choiceIndexes", {})
	var choice_indexes: Dictionary = choice_indexes_raw if typeof(choice_indexes_raw) == TYPE_DICTIONARY else {}
	choice_indexes[str(slot)] = option_index
	pending["choiceIndexes"] = choice_indexes
	player["pendingCardChoice"] = pending
	return _resume_pending_card_choice(game_state, board_map, player)

func handle_pending_contract_choice(game_state, _board_map, contract_id: String) -> Dictionary:
	var phase := str(game_state.get("phase", ""))
	if phase != "player_turns" and phase != "conflict":
		return {"ok": false, "reason": "wrong_phase"}
	var player = owner._get_current_player(game_state)
	if player == null:
		return {"ok": false, "reason": "no_current_player"}
	if contract_id == "":
		return {"ok": false, "reason": "empty_contract_id"}
	var result := ContractServiceScript.resolve_pending_contract_choice(
		game_state,
		player,
		contract_id,
		func(entry: Dictionary) -> void:
			owner._append_log(game_state, entry)
	)
	if not bool(result.get("ok", false)):
		return result
	owner._sync_pending_interactions(player)
	if owner.has_pending_player_interaction(game_state):
		owner._bump_state_version(game_state)
		return {"ok": true, "awaitingInteraction": true}
	if phase == "conflict":
		return owner._continue_after_conflict_pending_resolution(game_state, _board_map)
	owner._advance_to_next_active_player(game_state)
	owner._bump_state_version(game_state)
	return {"ok": true, "awaitingInteraction": false}

func _resolve_reveal_effects_with_choices(game_state, board_map, player) -> Dictionary:
	if board_map == null or not board_map.has_method("resolve_space_effects"):
		owner._resolve_player_reveal_effects(game_state, player, board_map)
		return {"ok": true}
	var hand_raw: Variant = player.get("hand", [])
	var hand: Array = hand_raw if typeof(hand_raw) == TYPE_ARRAY else []
	var revealed_card_ids: Array = hand.duplicate()
	var cards_by_id_raw: Variant = game_state.get("cardsById", {})
	var cards_by_id: Dictionary = cards_by_id_raw if typeof(cards_by_id_raw) == TYPE_DICTIONARY else {}
	for card_id_raw in hand:
		var card_id := str(card_id_raw)
		var card_def_raw: Variant = cards_by_id.get(card_id, {})
		if typeof(card_def_raw) != TYPE_DICTIONARY:
			continue
		var card_def: Dictionary = card_def_raw
		var reveal_effect: Variant = card_def.get("revealEffect", [])
		if typeof(reveal_effect) != TYPE_ARRAY or (reveal_effect as Array).is_empty():
			continue
		var reveal_result := _resolve_card_effect_with_player_choice(
			game_state,
			board_map,
			player,
			"reveal",
			card_id,
			reveal_effect,
			{
				"context": "reveal",
				"card_id": card_id,
				"revealed_card_ids": revealed_card_ids
			},
			{}
		)
		if bool(reveal_result.get("awaitingInteraction", false)):
			return {"ok": true, "awaitingInteraction": true}
	return {"ok": true}

func _resolve_card_effect_with_player_choice(
	game_state: Dictionary,
	board_map,
	player: Dictionary,
	source: String,
	card_id: String,
	effects: Variant,
	effect_context: Dictionary,
	payload: Dictionary
) -> Dictionary:
	if typeof(effects) != TYPE_ARRAY:
		return {"ok": true}
	var choice_context: Dictionary = {}
	if board_map != null and board_map.has_method("get_pending_effect_choice_context"):
		choice_context = board_map.get_pending_effect_choice_context(effects, player, game_state, {
			"choice_indexes": {},
			"choice_title": _build_card_choice_title(game_state, card_id, source),
			"space_id": str(effect_context.get("space_id", "")),
			"context": str(effect_context.get("context", ""))
		})
	if not choice_context.is_empty():
		player["pendingCardChoice"] = {
			"source": source,
			"cardId": card_id,
			"effects": effects,
			"effectContext": effect_context,
			"choiceIndexes": {},
			"payload": payload,
			"ui": choice_context
		}
		owner._sync_pending_interactions(player)
		return {"ok": true, "awaitingInteraction": true}
	board_map.resolve_space_effects(effects, player, game_state, effect_context)
	owner._sync_pending_interactions(player)
	return {"ok": true, "awaitingInteraction": owner.has_pending_player_interaction(game_state)}

func _resume_pending_card_choice(game_state: Dictionary, board_map, player: Dictionary) -> Dictionary:
	var pending_raw: Variant = player.get("pendingCardChoice", {})
	if typeof(pending_raw) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "no_pending_card_choice"}
	var pending: Dictionary = pending_raw
	var effects: Variant = pending.get("effects", [])
	if typeof(effects) != TYPE_ARRAY:
		player["pendingCardChoice"] = {}
		owner._sync_pending_interactions(player)
		return {"ok": false, "reason": "invalid_pending_card_choice_effects"}
	var effect_context_raw: Variant = pending.get("effectContext", {})
	var effect_context: Dictionary = effect_context_raw if typeof(effect_context_raw) == TYPE_DICTIONARY else {}
	var choice_indexes_raw: Variant = pending.get("choiceIndexes", {})
	var choice_indexes: Dictionary = choice_indexes_raw if typeof(choice_indexes_raw) == TYPE_DICTIONARY else {}
	var source := str(pending.get("source", ""))
	var card_id := str(pending.get("cardId", ""))

	if board_map != null and board_map.has_method("get_pending_effect_choice_context"):
		var next_choice_ctx: Dictionary = board_map.get_pending_effect_choice_context(effects, player, game_state, {
			"choice_indexes": choice_indexes,
			"choice_title": _build_card_choice_title(game_state, card_id, source),
			"space_id": str(effect_context.get("space_id", "")),
			"context": str(effect_context.get("context", ""))
		})
		if not next_choice_ctx.is_empty():
			pending["ui"] = next_choice_ctx
			player["pendingCardChoice"] = pending
			owner._sync_pending_interactions(player)
			owner._bump_state_version(game_state)
			return {"ok": true, "awaitingInteraction": true}

	var run_context: Dictionary = effect_context.duplicate(true)
	run_context["choice_indexes"] = choice_indexes
	board_map.resolve_space_effects(effects, player, game_state, run_context)
	player["pendingCardChoice"] = {}
	owner._sync_pending_interactions(player)
	owner._resolve_pending_effects(game_state, player, board_map, "card_choice")

	if source == "agent":
		var payload_raw: Variant = pending.get("payload", {})
		var payload: Dictionary = payload_raw if typeof(payload_raw) == TYPE_DICTIONARY else {}
		if not bool(payload.get("spyRecalledForOccupied", false)):
			_prepare_optional_spy_recall_draw(game_state, player, str(payload.get("spaceId", "")))
		if owner.has_pending_player_interaction(game_state):
			owner._bump_state_version(game_state)
			return {"ok": true, "awaitingInteraction": true}
		owner._advance_to_next_active_player(game_state)
		owner._bump_state_version(game_state)
		return {"ok": true, "awaitingInteraction": false}

	if source == "purchase":
		owner._bump_state_version(game_state)
		return {"ok": true, "awaitingInteraction": owner.has_pending_player_interaction(game_state)}

	if source == "reveal":
		var reveal_continue := _resolve_reveal_effects_with_choices(game_state, board_map, player)
		if bool(reveal_continue.get("awaitingInteraction", false)):
			owner._bump_state_version(game_state)
			return {"ok": true, "awaitingInteraction": true}
		deck_service.move_all_hand_to_in_play(player)
		player["passedReveal"] = true
		var reveal_counter := int(game_state.get("revealOrderCounter", 0)) + 1
		game_state["revealOrderCounter"] = reveal_counter
		player["lastRevealOrder"] = reveal_counter
		owner._append_log(game_state, {
			"type": "player_revealed",
			"playerId": str(player.get("id", ""))
		})
		owner._bump_state_version(game_state)
		return {"ok": true, "awaitingInteraction": owner.has_pending_player_interaction(game_state)}

	owner._bump_state_version(game_state)
	return {"ok": true}

func _build_card_choice_title(game_state: Dictionary, card_id: String, source: String) -> String:
	var cards_by_id_raw: Variant = game_state.get("cardsById", {})
	if typeof(cards_by_id_raw) == TYPE_DICTIONARY:
		var cards_by_id: Dictionary = cards_by_id_raw
		var card_def_raw: Variant = cards_by_id.get(card_id, {})
		if typeof(card_def_raw) == TYPE_DICTIONARY:
			var card_name := str((card_def_raw as Dictionary).get("name", card_id))
			if card_name != "":
				return "%s (%s)" % [card_name, source]
	return "Card effect (%s)" % source

func handle_pending_conflict_deploy(game_state, board_map, amount: int) -> Dictionary:
	if game_state.get("phase", "") != "player_turns":
		return {"ok": false, "reason": "wrong_phase"}
	var player = owner._get_current_player(game_state)
	if player == null:
		return {"ok": false, "reason": "no_current_player"}

	var max_commit := int(player.get("pendingConflictDeployMax", 0))
	var max_from_effect := int(player.get("pendingConflictDeployFromEffect", 0))
	var max_from_garrison := int(player.get("pendingConflictDeployFromGarrison", 0))
	if max_commit <= 0:
		return {"ok": false, "reason": "no_pending_conflict_deploy"}
	if amount < 0 or amount > max_commit:
		return {"ok": false, "reason": "invalid_conflict_deploy_amount", "max": max_commit}

	if board_map != null and board_map.has_method("commit_conflict_deploy_choice"):
		board_map.commit_conflict_deploy_choice(player, game_state, amount, max_from_effect, max_from_garrison)
	player["pendingConflictDeployMax"] = 0
	player["pendingConflictDeployFromEffect"] = 0
	player["pendingConflictDeployFromGarrison"] = 0

	owner._append_log(game_state, {
		"type": "pending_conflict_deploy_resolved",
		"playerId": str(player.get("id", "")),
		"amount": amount
	})

	if owner.has_pending_player_interaction(game_state):
		owner._bump_state_version(game_state)
		return {"ok": true, "awaitingInteraction": true}

	owner._advance_to_next_active_player(game_state)
	owner._bump_state_version(game_state)
	return {"ok": true, "awaitingInteraction": false}

func handle_pending_trash(game_state, zone_key: String, card_id: String) -> Dictionary:
	if game_state.get("phase", "") != "player_turns":
		return {"ok": false, "reason": "wrong_phase"}
	if card_id == "":
		return {"ok": false, "reason": "empty_card_id"}
	if zone_key != "hand" and zone_key != "discard" and zone_key != "inPlay":
		return {"ok": false, "reason": "invalid_zone"}

	var player = owner._get_current_player(game_state)
	if player == null:
		return {"ok": false, "reason": "no_current_player"}

	var pending_trash := int(player.get("pendingTrash", 0))
	if pending_trash <= 0:
		return {"ok": false, "reason": "no_pending_trash"}
	var pending_queue_raw: Variant = player.get("pendingTrashQueue", [])
	var pending_queue: Array = pending_queue_raw if typeof(pending_queue_raw) == TYPE_ARRAY else []
	var allowed_zones: Array = ["hand", "discard"]
	if not pending_queue.is_empty() and typeof(pending_queue[0]) == TYPE_DICTIONARY:
		var queue_entry: Dictionary = pending_queue[0]
		var zones_raw: Variant = queue_entry.get("allowedZones", [])
		if typeof(zones_raw) == TYPE_ARRAY:
			allowed_zones = zones_raw
	if not allowed_zones.has(zone_key):
		return {"ok": false, "reason": "zone_not_allowed_for_pending_trash", "allowedZones": allowed_zones}

	var zone = player.get(zone_key, [])
	if typeof(zone) != TYPE_ARRAY:
		zone = []
	var idx: int = zone.find(card_id)
	if idx < 0:
		return {"ok": false, "reason": "card_not_found_in_zone"}

	zone.remove_at(idx)
	player[zone_key] = zone
	player["pendingTrash"] = pending_trash - 1
	if not pending_queue.is_empty() and typeof(pending_queue[0]) == TYPE_DICTIONARY:
		var queue_head: Dictionary = pending_queue[0]
		var remaining := maxi(int(queue_head.get("remaining", 1)) - 1, 0)
		if remaining <= 0:
			pending_queue.remove_at(0)
		else:
			queue_head["remaining"] = remaining
			pending_queue[0] = queue_head
	player["pendingTrashQueue"] = pending_queue
	if card_id == "imperium_sardaukar_soldier":
		player["pendingDrawIntrigue"] = int(player.get("pendingDrawIntrigue", 0)) + 1
		owner._resolve_pending_effects(game_state, player, null, "sardaukar_trash")

	owner._append_log(game_state, {
		"type": "pending_trash_resolved",
		"playerId": str(player.get("id", "")),
		"zone": zone_key,
		"cardId": card_id,
		"remaining": int(player.get("pendingTrash", 0))
	})
	owner._bump_state_version(game_state)

	return {
		"ok": true,
		"zone": zone_key,
		"cardId": card_id,
		"remaining": int(player.get("pendingTrash", 0))
	}

func handle_pending_spy_recall_draw(game_state, board_map, post_id: String) -> Dictionary:
	var phase := str(game_state.get("phase", ""))
	if phase != "player_turns" and phase != "conflict":
		return {"ok": false, "reason": "wrong_phase"}
	var player = owner._get_current_player(game_state)
	if player == null:
		return {"ok": false, "reason": "no_current_player"}
	var pending_recalls := int(player.get("pendingSpyRecallDrawCards", 0))
	if pending_recalls <= 0:
		return {"ok": false, "reason": "no_pending_spy_recall_draw"}
	var post_ids = player.get("pendingSpyRecallDrawPostIds", [])
	if typeof(post_ids) != TYPE_ARRAY or not post_ids.has(post_id):
		return {"ok": false, "reason": "invalid_spy_post_choice"}
	var player_id := str(player.get("id", ""))
	var recall_result: Dictionary = SpySystemScript.recall_spy(game_state, player_id, post_id)
	if not bool(recall_result.get("ok", false)):
		return recall_result
	var turn_flags_raw = player.get("turnFlags", {})
	var turn_flags: Dictionary = turn_flags_raw if typeof(turn_flags_raw) == TYPE_DICTIONARY else {}
	turn_flags["recalled_spy_this_turn"] = true
	player["turnFlags"] = turn_flags

	var remaining_recalls: int = maxi(pending_recalls - 1, 0)
	var remaining_posts: Array = []
	if typeof(post_ids) == TYPE_ARRAY:
		for candidate in post_ids:
			var candidate_id := str(candidate)
			if candidate_id == post_id:
				continue
			remaining_posts.append(candidate_id)
	player["pendingSpyRecallDrawCards"] = remaining_recalls
	player["pendingSpyRecallDrawPostIds"] = remaining_posts
	owner._sync_pending_interactions(player)

	if remaining_recalls == 0:
		var reward_effects: Variant = player.get("pendingSpyRecallRewardEffects", [])
		var grant_cards := int(player.get("pendingSpyRecallDrawGrantCards", 0))
		if typeof(reward_effects) == TYPE_ARRAY and not reward_effects.is_empty():
			for reward in reward_effects:
				if typeof(reward) != TYPE_DICTIONARY:
					continue
				owner._apply_reward(reward, player, game_state, 1)
		elif grant_cards > 0:
			player["pendingDrawCards"] = int(player.get("pendingDrawCards", 0)) + grant_cards
			owner._resolve_pending_effects(game_state, player, board_map, "spy_recall_draw")
		_clear_pending_spy_recall_draw_state(player)
		owner.try_promote_pending_conflict_sandworm_second_cost(game_state)
	owner._append_log(game_state, {
		"type": "spy_recall_draw_resolved",
		"playerId": player_id,
		"postId": post_id,
		"remainingRecalls": remaining_recalls
	})

	if owner.has_pending_player_interaction(game_state):
		owner._bump_state_version(game_state)
		return {"ok": true, "awaitingInteraction": true}
	if phase == "conflict":
		return owner._continue_after_conflict_pending_resolution(game_state, board_map)

	owner._advance_to_next_active_player(game_state)
	owner._bump_state_version(game_state)
	return {"ok": true, "awaitingInteraction": false}

func handle_skip_pending_spy_recall_draw(game_state, _board_map) -> Dictionary:
	if game_state.get("phase", "") != "player_turns":
		return {"ok": false, "reason": "wrong_phase"}
	var player = owner._get_current_player(game_state)
	if player == null:
		return {"ok": false, "reason": "no_current_player"}
	var pending_recalls := int(player.get("pendingSpyRecallDrawCards", 0))
	if pending_recalls <= 0:
		return {"ok": false, "reason": "no_pending_spy_recall_draw"}
	var player_id := str(player.get("id", ""))

	_clear_pending_spy_recall_draw_state(player)
	owner._append_log(game_state, {
		"type": "spy_recall_draw_skipped",
		"playerId": player_id
	})

	if owner.has_pending_player_interaction(game_state):
		owner._bump_state_version(game_state)
		return {"ok": true, "awaitingInteraction": true}

	owner._advance_to_next_active_player(game_state)
	owner._bump_state_version(game_state)
	return {"ok": true, "awaitingInteraction": false}

func _prepare_optional_spy_recall_draw(game_state, player, space_id: String) -> void:
	if player == null:
		return
	if int(player.get("pendingSpyRecallDrawCards", 0)) > 0:
		return
	var player_id := str(player.get("id", ""))
	if player_id == "":
		return
	var eligible_posts: Array = SpySystemScript.get_player_spy_post_ids_connected_to_space(game_state, player_id, space_id)
	if eligible_posts.is_empty():
		return
	player["pendingSpyRecallDrawCards"] = 1
	player["pendingSpyRecallDrawGrantCards"] = 1
	player["pendingSpyRecallRewardEffects"] = []
	player["pendingSpyRecallDrawPostIds"] = eligible_posts
	player["pendingSpyRecallDrawSpaceId"] = str(space_id)
	owner._append_log(game_state, {
		"type": "pending_spy_recall_draw_waiting_for_player",
		"playerId": player_id,
		"spaceId": str(space_id),
		"postIds": eligible_posts
	})
	owner._sync_pending_interactions(player)

func _clear_pending_spy_recall_draw_state(player: Dictionary) -> void:
	player["pendingSpyRecallDrawCards"] = 0
	player["pendingSpyRecallDrawGrantCards"] = 0
	player["pendingSpyRecallRewardEffects"] = []
	player["pendingSpyRecallDrawPostIds"] = []
	player["pendingSpyRecallDrawSpaceId"] = ""
	owner._sync_pending_interactions(player)
