extends Node
class_name TurnController

const DeckServiceScript = preload("res://scripts/deck_service.gd")
const FactionProgressionServiceScript = preload("res://scripts/faction_progression_service.gd")
const PhaseHandlerScript = preload("res://scripts/phase_handler.gd")
const SpySystemScript = preload("res://scripts/spy_system.gd")
const ContractServiceScript = preload("res://scripts/contract_service.gd")
const TurnCommandHandlerScript = preload("res://scripts/turn_command_handler.gd")
const RuleContractScript = preload("res://scripts/domain/rule_contract.gd")
const GameStateAccessScript = preload("res://scripts/domain/game_state_access.gd")
const ConflictResolutionRulesScript = preload("res://scripts/domain/conflict_resolution_rules.gd")
const ConflictRewardsServiceScript = preload("res://scripts/domain/services/conflict_rewards_service.gd")
const PendingConflictServiceScript = preload("res://scripts/domain/services/pending_conflict_service.gd")
const EndgameResolutionServiceScript = preload("res://scripts/domain/services/endgame_resolution_service.gd")
const ObjectiveResolutionServiceScript = preload("res://scripts/domain/services/objective_resolution_service.gd")
const PendingConflictTailServiceScript = preload("res://scripts/application/services/pending_conflict_tail_service.gd")
const ROUND_HAND_SIZE := 5
var deck_service := DeckServiceScript.new()
var faction_progression_service := FactionProgressionServiceScript.new()
var phase_handler := PhaseHandlerScript.new()
var conflict_rules := ConflictResolutionRulesScript.new()
var conflict_rewards := ConflictRewardsServiceScript.new()
var pending_conflict_service := PendingConflictServiceScript.new()
var endgame_resolution_service := EndgameResolutionServiceScript.new()
var objective_resolution_service := ObjectiveResolutionServiceScript.new()
var pending_conflict_tail_service := PendingConflictTailServiceScript.new()
var command_handler

func _init() -> void:
	command_handler = TurnCommandHandlerScript.new(self, deck_service)

func take_turn_send_agent(game_state, board_map, space_id, played_card, agent_id = null, context = {}):
	return command_handler.handle_send_agent(game_state, board_map, space_id, played_card, agent_id, context)

func take_turn_reveal(game_state, board_map = null):
	return command_handler.handle_reveal(game_state, board_map)

func advance_after_reveal(game_state):
	if GameStateAccessScript.get_phase(game_state) != "player_turns":
		return {"ok": false, "reason": "wrong_phase"}

	var player = _get_current_player(game_state)
	if player == null:
		return {"ok": false, "reason": "no_current_player"}
	if not bool(player.get("passedReveal", false)):
		return {"ok": false, "reason": "player_not_revealed"}

	var discarded_cards: Array = deck_service.discard_all_hand_and_in_play(player)
	_apply_discard_triggers_for_cards(game_state, player, discarded_cards)

	if is_player_turns_phase_finished(game_state):
		_bump_state_version(game_state)
		return {"ok": true, "phaseFinished": true}

	_advance_to_next_active_player(game_state)
	_bump_state_version(game_state)
	return {"ok": true, "phaseFinished": false}

func buy_market_card(game_state, card_id: String, board_map = null):
	return command_handler.handle_buy_market_card(game_state, card_id, board_map)

func _apply_discard_triggers_for_cards(game_state: Dictionary, player_state: Dictionary, discarded_cards: Array) -> void:
	if typeof(player_state) != TYPE_DICTIONARY or discarded_cards.is_empty():
		return
	var cards_by_id_raw: Variant = game_state.get("cardsById", {})
	var cards_by_id: Dictionary = cards_by_id_raw if typeof(cards_by_id_raw) == TYPE_DICTIONARY else {}
	for card_id_raw in discarded_cards:
		var card_id := str(card_id_raw)
		if card_id == "":
			continue
		var card_def_raw: Variant = cards_by_id.get(card_id, {})
		if typeof(card_def_raw) != TYPE_DICTIONARY:
			continue
		var on_discard_effects_raw: Variant = (card_def_raw as Dictionary).get("onDiscardEffects", [])
		if typeof(on_discard_effects_raw) != TYPE_ARRAY:
			continue
		var on_discard_effects: Array = on_discard_effects_raw
		if on_discard_effects.is_empty():
			continue
		for effect_raw in on_discard_effects:
			if typeof(effect_raw) != TYPE_DICTIONARY:
				continue
			_apply_reward(effect_raw, player_state, game_state, 1)
		_append_log(game_state, {
			"type": "card_discard_trigger_applied",
			"playerId": str(player_state.get("id", "")),
			"cardId": card_id
		})

func has_pending_player_interaction(game_state) -> bool:
	if GameStateAccessScript.get_phase(game_state) == "conflict":
		var cir_early: Variant = game_state.get("combatIntrigueRound", {})
		var cir_early_dict: Dictionary = cir_early if typeof(cir_early) == TYPE_DICTIONARY else {}
		if str(cir_early_dict.get("status", "")) == "open":
			return true
	var pic_raw: Variant = game_state.get("pendingImmediateConflictWinIntrigue", {})
	if typeof(pic_raw) == TYPE_DICTIONARY and not (pic_raw as Dictionary).is_empty():
		var offered_pid := str((pic_raw as Dictionary).get("playerId", ""))
		var cur0: Variant = _get_current_player(game_state)
		if typeof(cur0) == TYPE_DICTIONARY and str(cur0.get("id", "")) == offered_pid:
			return true
	if GameStateAccessScript.get_status(game_state) == "finished":
		var eir_raw: Variant = game_state.get("endgameIntrigueRound", {})
		var eir0: Dictionary = eir_raw if typeof(eir_raw) == TYPE_DICTIONARY else {}
		if str(eir0.get("status", "")) == "open":
			return true
	var player = _get_current_player(game_state)
	if player == null:
		return false
	_sync_pending_interactions(player)
	var pending_card_choice: Variant = player.get("pendingCardChoice", {})
	var has_pending_card_choice := typeof(pending_card_choice) == TYPE_DICTIONARY and not (pending_card_choice as Dictionary).is_empty()
	var pending_contract_choice: Variant = player.get("pendingContractChoice", {})
	var has_pending_contract_choice := typeof(pending_contract_choice) == TYPE_DICTIONARY and not (pending_contract_choice as Dictionary).is_empty()
	return int(player.get("pendingTrash", 0)) > 0 or int(player.get("pendingConflictDeployMax", 0)) > 0 or int(player.get("pendingPlaceSpy", 0)) > 0 or int(player.get("pendingSpyRecallDrawCards", 0)) > 0 or has_pending_card_choice or has_pending_contract_choice

func get_pending_state_for_current_player(game_state) -> Dictionary:
	var player = _get_current_player(game_state)
	if player == null:
		return {}
	_sync_pending_interactions(player)
	return {
		"pendingTrash": int(player.get("pendingTrash", 0)),
		"pendingConflictDeployMax": int(player.get("pendingConflictDeployMax", 0)),
		"pendingConflictDeployFromEffect": int(player.get("pendingConflictDeployFromEffect", 0)),
		"pendingConflictDeployFromGarrison": int(player.get("pendingConflictDeployFromGarrison", 0)),
		"pendingPlaceSpy": int(player.get("pendingPlaceSpy", 0)),
		"pendingSpyRecallDrawCards": int(player.get("pendingSpyRecallDrawCards", 0)),
		"pendingCardChoice": player.get("pendingCardChoice", {}),
		"pendingContractChoice": player.get("pendingContractChoice", {})
	}

func get_pending_card_choice_context(game_state) -> Dictionary:
	var player = _get_current_player(game_state)
	if player == null:
		return {}
	var pending_raw: Variant = player.get("pendingCardChoice", {})
	if typeof(pending_raw) != TYPE_DICTIONARY:
		return {}
	var pending: Dictionary = pending_raw
	if pending.is_empty():
		return {}
	var ui_raw: Variant = pending.get("ui", {})
	if typeof(ui_raw) != TYPE_DICTIONARY:
		return {}
	return ui_raw

func resolve_pending_card_choice(game_state, board_map, slot: int, option_index: int) -> Dictionary:
	return command_handler.handle_pending_card_choice(game_state, board_map, slot, option_index)

func get_pending_contract_choice_context(game_state) -> Dictionary:
	var player = _get_current_player(game_state)
	if player == null:
		return {}
	var pending_raw: Variant = player.get("pendingContractChoice", {})
	if typeof(pending_raw) != TYPE_DICTIONARY:
		return {}
	var pending: Dictionary = pending_raw
	if pending.is_empty():
		return {}
	if int(pending.get("picksRemaining", 0)) <= 0:
		player["pendingContractChoice"] = {}
		return {}
	var face_up_raw: Variant = game_state.get("choamFaceUpContracts", [])
	if typeof(face_up_raw) != TYPE_ARRAY:
		return {}
	var face_up: Array = face_up_raw
	if face_up.is_empty():
		player["pendingContractChoice"] = {}
		return {}
	var contracts_by_id_raw: Variant = game_state.get("choamContractsById", {})
	var contracts_by_id: Dictionary = contracts_by_id_raw if typeof(contracts_by_id_raw) == TYPE_DICTIONARY else {}
	var option_contract_ids: Array = []
	var option_texts: Array = []
	var option_entries: Array = []
	for contract_id_raw in face_up:
		var contract_id := str(contract_id_raw)
		var contract_def_raw: Variant = contracts_by_id.get(contract_id, {})
		var contract_def: Dictionary = contract_def_raw if typeof(contract_def_raw) == TYPE_DICTIONARY else {}
		var contract_name := str(contract_def.get("name", contract_id))
		var trigger_raw: Variant = contract_def.get("trigger", {})
		var trigger: Dictionary = trigger_raw if typeof(trigger_raw) == TYPE_DICTIONARY else {}
		var trigger_space_id := str(trigger.get("spaceId", "")).strip_edges()
		var trigger_text := "agent on %s" % (trigger_space_id if trigger_space_id != "" else "unknown")
		var reward_tokens := _contract_reward_effects_to_tokens(contract_def.get("rewardEffects", []))
		option_contract_ids.append(contract_id)
		option_texts.append(contract_name)
		option_entries.append({
			"name": contract_name,
			"triggerText": trigger_text,
			"triggerSpaceId": trigger_space_id,
			"rewardTokens": reward_tokens
		})
	if option_contract_ids.is_empty():
		player["pendingContractChoice"] = {}
		return {}
	return {
		"title": "choose face-up contract",
		"optionContractIds": option_contract_ids,
		"optionEffectsTexts": option_texts,
		"optionEntries": option_entries
	}

func _contract_reward_effects_to_tokens(reward_effects: Variant) -> String:
	if typeof(reward_effects) != TYPE_ARRAY:
		return "-"
	var parts: Array[String] = []
	for effect_raw in reward_effects:
		if typeof(effect_raw) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = effect_raw
		var effect_type := str(effect.get("type", ""))
		var amount := int(effect.get("amount", 0))
		match effect_type:
			"gain_resource":
				var resource := str(effect.get("resource", ""))
				if resource == "solari":
					parts.append("[solari_badge:%d]" % amount)
				elif resource == "spice":
					parts.append("[spice_badge:%d]" % amount)
				elif resource == "water":
					parts.append("[water_badge:%d]" % amount)
				else:
					parts.append("+%d %s" % [amount, resource])
			"draw_cards":
				for _i in range(maxi(amount, 1)):
					parts.append("[draw_card_icon]")
			"draw_intrigue":
				for _i in range(maxi(amount, 1)):
					parts.append("[intrigue_icon]")
			"recruit_troops":
				parts.append("[troops_badge:%d]" % amount)
			"gain_influence":
				parts.append("[faction_icon:%s]" % str(effect.get("faction", "")))
			_:
				parts.append(effect_type)
	if parts.is_empty():
		return "-"
	return " ".join(parts)

func resolve_pending_contract_choice(game_state, board_map, contract_id: String) -> Dictionary:
	return command_handler.handle_pending_contract_choice(game_state, board_map, contract_id)

func resolve_pending_conflict_deploy(game_state, board_map, amount: int) -> Dictionary:
	return command_handler.handle_pending_conflict_deploy(game_state, board_map, amount)

func resolve_pending_trash(game_state, zone_key: String, card_id: String) -> Dictionary:
	var result: Dictionary = command_handler.handle_pending_trash(game_state, zone_key, card_id)
	if bool(result.get("ok", false)):
		try_promote_pending_conflict_sandworm_second_cost(game_state)
	return result

func get_pending_spy_recall_draw_context(game_state) -> Dictionary:
	var player = _get_current_player(game_state)
	if player == null:
		return {}
	var pending_draw_cards := int(player.get("pendingSpyRecallDrawCards", 0))
	if pending_draw_cards <= 0:
		return {}
	var post_ids: Array = []
	var raw_post_ids: Variant = player.get("pendingSpyRecallDrawPostIds", [])
	if typeof(raw_post_ids) == TYPE_ARRAY:
		post_ids = raw_post_ids
	return {
		"pendingSpyRecallDrawCards": pending_draw_cards,
		"spaceId": str(player.get("pendingSpyRecallDrawSpaceId", "")),
		"postIds": post_ids
	}

func resolve_pending_spy_recall_draw(game_state, board_map, post_id: String) -> Dictionary:
	return command_handler.handle_pending_spy_recall_draw(game_state, board_map, post_id)

func skip_pending_spy_recall_draw(game_state, board_map) -> Dictionary:
	return command_handler.handle_skip_pending_spy_recall_draw(game_state, board_map)

func get_pending_spy_context(game_state) -> Dictionary:
	var player = _get_current_player(game_state)
	if player == null:
		return {}
	var player_id := str(player.get("id", ""))
	var pending_place_spy := int(player.get("pendingPlaceSpy", 0))
	SpySystemScript.ensure_spy_state(game_state)
	var owned_post_ids: Array = SpySystemScript.get_player_spy_post_ids(game_state, player_id)
	var available_post_ids: Array = SpySystemScript.get_unoccupied_spy_post_ids(game_state)
	var player_spy_count := owned_post_ids.size()
	return {
		"playerId": player_id,
		"pendingPlaceSpy": pending_place_spy,
		"playerSpyCount": player_spy_count,
		"maxSpies": SpySystemScript.MAX_SPIES_PER_PLAYER,
		"isAtCap": player_spy_count >= SpySystemScript.MAX_SPIES_PER_PLAYER,
		"ownedSpyPostIds": owned_post_ids,
		"availableSpyPostIds": available_post_ids
	}

func get_pending_conflict_cost_choice_context(game_state) -> Dictionary:
	return pending_conflict_service.get_pending_conflict_cost_choice_context(
		game_state,
		{"cost_reward_to_effect_tokens_text": Callable(self, "_cost_reward_to_effect_tokens_text")}
	)

func get_pending_conflict_influence_choice_context(game_state) -> Dictionary:
	return pending_conflict_service.get_pending_conflict_influence_choice_context(game_state)

func resolve_pending_conflict_cost_choice(game_state, board_map, accept: bool) -> Dictionary:
	var result: Dictionary = pending_conflict_service.resolve_pending_conflict_cost_choice_state(
		game_state,
		accept,
		_pending_conflict_callbacks()
	)
	if not bool(result.get("ok", false)):
		return result
	try_promote_pending_conflict_sandworm_second_cost(game_state)
	return _continue_after_conflict_pending_resolution(game_state, board_map)

func resolve_pending_conflict_influence_choice(game_state, board_map, faction: String) -> Dictionary:
	var result: Dictionary = pending_conflict_service.resolve_pending_conflict_influence_choice_state(
		game_state,
		faction,
		_pending_conflict_callbacks()
	)
	if not bool(result.get("ok", false)):
		return result
	if bool(result.get("awaitingInteraction", false)):
		return result
	return _continue_after_conflict_pending_resolution(game_state, board_map)

func resolve_pending_spy_recall(game_state, post_id: String) -> Dictionary:
	if str(game_state.get("phase", "")) != "player_turns":
		return {"ok": false, "reason": "wrong_phase"}
	var player = _get_current_player(game_state)
	if player == null:
		return {"ok": false, "reason": "no_current_player"}
	var player_id := str(player.get("id", ""))
	var result: Dictionary = SpySystemScript.recall_spy(game_state, player_id, post_id)
	if not bool(result.get("ok", false)):
		return result
	_append_log(game_state, {
		"type": "spy_recalled",
		"playerId": player_id,
		"postId": post_id
	})
	_bump_state_version(game_state)
	return {"ok": true}

func resolve_pending_place_spy(game_state, board_map, post_id: String) -> Dictionary:
	var phase := str(game_state.get("phase", ""))
	if phase != "player_turns" and phase != "conflict":
		return {"ok": false, "reason": "wrong_phase"}
	var player = _get_current_player(game_state)
	if player == null:
		return {"ok": false, "reason": "no_current_player"}
	var pending_place_spy := int(player.get("pendingPlaceSpy", 0))
	if pending_place_spy <= 0:
		return {"ok": false, "reason": "no_pending_place_spy"}
	var player_id := str(player.get("id", ""))
	var place_result: Dictionary = SpySystemScript.place_spy(game_state, player_id, post_id)
	if not bool(place_result.get("ok", false)):
		return place_result
	player["pendingPlaceSpy"] = pending_place_spy - 1
	_append_log(game_state, {
		"type": "pending_place_spy_resolved",
		"playerId": player_id,
		"postId": post_id,
		"remaining": int(player.get("pendingPlaceSpy", 0))
	})
	_sync_pending_interactions(player)
	_bump_state_version(game_state)
	try_promote_pending_conflict_sandworm_second_cost(game_state)
	var remaining_after := int(player.get("pendingPlaceSpy", 0))
	if phase == "conflict":
		if remaining_after > 0:
			return {"ok": true, "remaining": remaining_after}
		var next_pid := _find_first_player_id_with_pending_place_spy(game_state)
		if next_pid != "":
			game_state["currentPlayerId"] = next_pid
			var next_p: Variant = _find_player_by_id(game_state, next_pid)
			if typeof(next_p) == TYPE_DICTIONARY:
				_sync_pending_interactions(next_p)
			_bump_state_version(game_state)
			return {"ok": true, "remaining": 0, "switchedToPlayerId": next_pid}
		if board_map != null:
			return _continue_after_conflict_pending_resolution(game_state, board_map)
		return {"ok": true, "remaining": 0}
	return {"ok": true, "remaining": remaining_after}

func _resolve_pending_effects(game_state, player, _board_map, reason: String) -> void:
	if player == null:
		return

	var pending_draw_cards := int(player.get("pendingDrawCards", 0))
	if pending_draw_cards > 0:
		deck_service.draw_cards(player, pending_draw_cards)
		player["pendingDrawCards"] = 0
		_append_log(game_state, {
			"type": "pending_draw_cards_resolved",
			"playerId": str(player.get("id", "")),
			"amount": pending_draw_cards,
			"reason": reason
		})

	var pending_draw_intrigue := int(player.get("pendingDrawIntrigue", 0))
	if pending_draw_intrigue > 0:
		var drawn_intrigue: Array = deck_service.draw_intrigue(game_state, player, pending_draw_intrigue)
		player["pendingDrawIntrigue"] = 0
		_append_log(game_state, {
			"type": "pending_draw_intrigue_resolved",
			"playerId": str(player.get("id", "")),
			"amount": pending_draw_intrigue,
			"drawnCardIds": drawn_intrigue,
			"reason": reason
		})
		_queue_immediate_conflict_win_intrigue_if_needed(game_state, player, drawn_intrigue, reason)

	var pending_trash := int(player.get("pendingTrash", 0))
	if pending_trash > 0:
		_append_log(game_state, {
			"type": "pending_trash_waiting_for_player",
			"playerId": str(player.get("id", "")),
			"amount": pending_trash,
			"reason": reason
		})

	var pending_conflict_deploy := int(player.get("pendingConflictDeployMax", 0))
	if pending_conflict_deploy > 0:
		_append_log(game_state, {
			"type": "pending_conflict_deploy_waiting_for_player",
			"playerId": str(player.get("id", "")),
			"max": pending_conflict_deploy,
			"reason": reason
		})
	var pending_place_spy := int(player.get("pendingPlaceSpy", 0))
	if pending_place_spy > 0:
		_append_log(game_state, {
			"type": "pending_place_spy_waiting_for_player",
			"playerId": str(player.get("id", "")),
			"amount": pending_place_spy,
			"reason": reason
		})
	var pending_spy_recall_draw := int(player.get("pendingSpyRecallDrawCards", 0))
	if pending_spy_recall_draw > 0:
		_append_log(game_state, {
			"type": "pending_spy_recall_draw_waiting_for_player",
			"playerId": str(player.get("id", "")),
			"amount": pending_spy_recall_draw,
			"reason": reason
		})
	_sync_pending_interactions(player)

func _queue_immediate_conflict_win_intrigue_if_needed(
	game_state: Dictionary,
	player: Dictionary,
	drawn_ids: Array,
	reason: String
) -> void:
	if reason != "conflict_reward":
		return
	if drawn_ids.is_empty():
		return
	var intrigues_by_id: Variant = game_state.get("intriguesById", {})
	if typeof(intrigues_by_id) != TYPE_DICTIONARY:
		return
	game_state["pendingImmediateConflictWinIntrigue"] = {}
	for id_raw in drawn_ids:
		var iid := str(id_raw)
		var def_raw: Variant = (intrigues_by_id as Dictionary).get(iid, {})
		if typeof(def_raw) != TYPE_DICTIONARY:
			continue
		if bool(def_raw.get("immediateOnConflictWinReward", false)):
			game_state["pendingImmediateConflictWinIntrigue"] = {
				"playerId": str(player.get("id", "")),
				"intrigueCardId": iid
			}
			_append_log(game_state, {
				"type": "immediate_conflict_win_intrigue_offered",
				"playerId": str(player.get("id", "")),
				"intrigueCardId": iid
			})
			break

func _resolve_player_reveal_effects(game_state, player, board_map):
	var player_id = str(player.get("id", ""))
	var hand = player.get("hand", [])
	if typeof(hand) != TYPE_ARRAY:
		hand = []

	var cards_by_id = game_state.get("cardsById", {})
	if typeof(cards_by_id) != TYPE_DICTIONARY:
		cards_by_id = {}

	var sword_before = int(player.get("revealedSwordPower", 0))
	for card_id_raw in hand:
		var card_id = str(card_id_raw)
		if not cards_by_id.has(card_id):
			continue
		var card_def = cards_by_id[card_id]
		if typeof(card_def) != TYPE_DICTIONARY:
			continue

		var reveal_effect = card_def.get("revealEffect", [])
		if typeof(reveal_effect) != TYPE_ARRAY or reveal_effect.is_empty():
			continue

		if board_map != null and board_map.has_method("resolve_space_effects"):
			board_map.resolve_space_effects(reveal_effect, player, game_state, {
				"context": "reveal",
				"card_id": card_id
			})
		else:
			_apply_reveal_effects_fallback(player, reveal_effect)

	var zone = game_state.get("conflictZone", {})
	if typeof(zone) == TYPE_DICTIONARY and zone.has(player_id) and typeof(zone[player_id]) == TYPE_DICTIONARY:
		zone[player_id]["revealedSwordPower"] = int(player.get("revealedSwordPower", 0))
		game_state["conflictZone"] = zone

	_append_log(game_state, {
		"type": "reveal_effects_resolved",
		"playerId": player_id,
		"swordsGained": int(player.get("revealedSwordPower", 0)) - sword_before
	})

func _apply_reveal_effects_fallback(player, reveal_effects):
	for effect in reveal_effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		var effect_type = str(effect.get("type", ""))
		var amount = int(effect.get("amount", 0))
		if effect_type == "gain_sword":
			player["revealedSwordPower"] = int(player.get("revealedSwordPower", 0)) + amount
		elif effect_type == "gain_persuasion":
			player["persuasion"] = int(player.get("persuasion", 0)) + amount
		elif effect_type == "gain_resource":
			var resource = str(effect.get("resource", ""))
			var resources = player.get("resources", {})
			resources[resource] = int(resources.get(resource, 0)) + amount
			player["resources"] = resources
		elif effect_type == "vp":
			player["vp"] = int(player.get("vp", 0)) + amount

func _find_market_location(game_state, card_id: String) -> Dictionary:
	var market = game_state.get("imperiumMarket", [])
	if typeof(market) == TYPE_ARRAY and market.has(card_id):
		return {"ok": true, "source": "market"}

	var reserve = game_state.get("reserveCards", {})
	if typeof(reserve) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "invalid_reserve_state"}
	for pile_id in reserve.keys():
		var pile = reserve[pile_id]
		if typeof(pile) != TYPE_ARRAY:
			continue
		if pile.has(card_id):
			return {"ok": true, "source": "reserve", "pileId": str(pile_id)}

	return {"ok": false, "reason": "card_not_in_market_or_reserve"}

func _gain_card_to_discard(player_state, card_id: String) -> void:
	var discard = player_state.get("discard", [])
	if typeof(discard) != TYPE_ARRAY:
		discard = []
	discard.append(card_id)
	player_state["discard"] = discard

func _remove_market_card(game_state, card_id: String) -> int:
	var market = game_state.get("imperiumMarket", [])
	if typeof(market) != TYPE_ARRAY:
		market = []
	var idx: int = market.find(card_id)
	if idx >= 0:
		market.remove_at(idx)
	game_state["imperiumMarket"] = market
	return idx

func _remove_reserve_card(game_state, pile_id: String, card_id: String) -> bool:
	var reserve = game_state.get("reserveCards", {})
	if typeof(reserve) != TYPE_DICTIONARY:
		return false
	if not reserve.has(pile_id):
		return false
	var pile = reserve[pile_id]
	if typeof(pile) != TYPE_ARRAY:
		return false
	var idx := (pile as Array).find(card_id)
	if idx < 0:
		return false
	(pile as Array).remove_at(idx)
	reserve[pile_id] = pile
	game_state["reserveCards"] = reserve
	return true

func _refill_imperium_market(game_state, preferred_index: int = -1) -> void:
	var market = game_state.get("imperiumMarket", [])
	var deck = game_state.get("imperiumDeck", [])
	if typeof(market) != TYPE_ARRAY:
		market = []
	if typeof(deck) != TYPE_ARRAY:
		deck = []

	if market.size() < 5 and not deck.is_empty() and preferred_index >= 0 and preferred_index <= market.size():
		market.insert(preferred_index, str(deck.pop_back()))

	while market.size() < 5 and not deck.is_empty():
		market.append(str(deck.pop_back()))

	game_state["imperiumMarket"] = market
	game_state["imperiumDeck"] = deck

func is_player_turns_phase_finished(game_state):
	var players = game_state.get("players", [])
	if players.is_empty():
		return true
	for player in players:
		if not bool(player.get("passedReveal", false)):
			return false
	return true

func end_player_turns_phase(game_state, _board_map):
	if game_state.get("phase", "") != "player_turns":
		return {"ok": false, "reason": "wrong_phase"}
	if not is_player_turns_phase_finished(game_state):
		return {"ok": false, "reason": "phase_not_finished"}

	phase_handler.to_conflict(game_state)
	_append_log(game_state, {
		"type": "phase_changed",
		"phase": "conflict"
	})
	_bump_state_version(game_state)
	return {"ok": true, "newPhase": "conflict"}

func _eligible_combat_intrigue_player_ids(conflict_zone: Dictionary, players: Array) -> Array[String]:
	var eligible: Array[String] = []
	for p in players:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var pid := str(p.get("id", ""))
		if pid == "":
			continue
		var zone: Dictionary = {}
		if conflict_zone.has(pid) and typeof(conflict_zone[pid]) == TYPE_DICTIONARY:
			zone = conflict_zone[pid]
		var troops := int(zone.get("troops", 0))
		var sw := int(zone.get("sandworms", 0))
		if troops > 0 or sw > 0:
			eligible.append(pid)
	return eligible

func _order_player_ids_from_first_player(game_state: Dictionary, subset_ids: Array) -> Array[String]:
	var out: Array[String] = []
	if subset_ids.is_empty():
		return out
	var players: Array = game_state.get("players", [])
	if typeof(players) != TYPE_ARRAY or players.is_empty():
		for s in subset_ids:
			out.append(str(s))
		return out
	var first_idx := -1
	var fp := str(game_state.get("firstPlayerId", ""))
	for i in range(players.size()):
		if str(players[i].get("id", "")) == fp:
			first_idx = i
			break
	if first_idx < 0:
		for s in subset_ids:
			out.append(str(s))
		return out
	var n := players.size()
	for k in range(n):
		var pid := str(players[(first_idx + k) % n].get("id", ""))
		for s in subset_ids:
			if str(s) == pid:
				out.append(pid)
				break
	return out

func _init_combat_intrigue_round(game_state: Dictionary, conflict_zone: Dictionary) -> void:
	var players: Array = game_state.get("players", [])
	if typeof(players) != TYPE_ARRAY:
		players = []
	var eligible: Array[String] = _eligible_combat_intrigue_player_ids(conflict_zone, players)
	if eligible.is_empty():
		game_state["combatIntrigueRound"] = {
			"status": "resolved",
			"eligiblePlayerIds": [],
			"currentIndex": 0,
			"consecutivePasses": 0,
			"currentPlayerId": ""
		}
		return
	var ordered := _order_player_ids_from_first_player(game_state, eligible)
	if ordered.is_empty():
		game_state["combatIntrigueRound"] = {
			"status": "resolved",
			"eligiblePlayerIds": [],
			"currentIndex": 0,
			"consecutivePasses": 0,
			"currentPlayerId": ""
		}
		return
	var first_pid := str(ordered[0])
	var ids_variant: Array = []
	for x in ordered:
		ids_variant.append(str(x))
	game_state["combatIntrigueRound"] = {
		"status": "open",
		"eligiblePlayerIds": ids_variant,
		"currentIndex": 0,
		"consecutivePasses": 0,
		"currentPlayerId": first_pid
	}
	game_state["currentPlayerId"] = first_pid
	_append_log(game_state, {
		"type": "combat_intrigue_round_started",
		"eligiblePlayerIds": ids_variant,
		"currentPlayerId": first_pid
	})
	_auto_pass_forced_combat_intrigue_players(game_state)

func _player_has_playable_combat_intrigue(game_state: Dictionary, player_id: String) -> bool:
	var player_raw: Variant = _find_player_by_id(game_state, player_id)
	if typeof(player_raw) != TYPE_DICTIONARY:
		return false
	var player: Dictionary = player_raw
	var intrigue_hand_raw: Variant = player.get("intrigue", [])
	var intrigue_hand: Array = intrigue_hand_raw if typeof(intrigue_hand_raw) == TYPE_ARRAY else []
	if intrigue_hand.is_empty():
		return false
	var intrigues_by_id_raw: Variant = game_state.get("intriguesById", {})
	var intrigues_by_id: Dictionary = intrigues_by_id_raw if typeof(intrigues_by_id_raw) == TYPE_DICTIONARY else {}
	for intrigue_id_raw in intrigue_hand:
		var intrigue_id := str(intrigue_id_raw).strip_edges()
		if intrigue_id == "":
			continue
		var def_raw: Variant = intrigues_by_id.get(intrigue_id, {})
		if typeof(def_raw) != TYPE_DICTIONARY:
			continue
		if str((def_raw as Dictionary).get("intrigueType", "")).strip_edges().to_lower() == "combat":
			return true
	return false

func _auto_pass_forced_combat_intrigue_players(game_state: Dictionary) -> void:
	var cir_raw: Variant = game_state.get("combatIntrigueRound", {})
	if typeof(cir_raw) != TYPE_DICTIONARY:
		return
	var cir: Dictionary = cir_raw
	if str(cir.get("status", "")) != "open":
		return
	var eligible_raw: Variant = cir.get("eligiblePlayerIds", [])
	var eligible: Array = eligible_raw if typeof(eligible_raw) == TYPE_ARRAY else []
	var n := eligible.size()
	if n <= 0:
		return
	var guard := 0
	while guard < n:
		guard += 1
		var idx := int(cir.get("currentIndex", 0))
		if idx < 0 or idx >= n:
			idx = 0
		var player_id := str(eligible[idx])
		if _player_has_playable_combat_intrigue(game_state, player_id):
			cir["currentIndex"] = idx
			cir["currentPlayerId"] = player_id
			game_state["currentPlayerId"] = player_id
			game_state["combatIntrigueRound"] = cir
			return
		var passes := int(cir.get("consecutivePasses", 0)) + 1
		_append_log(game_state, {
			"type": "combat_intrigue_auto_passed",
			"playerId": player_id,
			"reason": "no_combat_intrigue_options"
		})
		if passes >= n:
			cir["status"] = "done"
			cir["consecutivePasses"] = passes
			game_state["combatIntrigueRound"] = cir
			_append_log(game_state, {
				"type": "combat_intrigue_round_completed",
				"reason": "all_passed_or_no_options"
			})
			return
		var next_idx := (idx + 1) % n
		cir["currentIndex"] = next_idx
		cir["consecutivePasses"] = passes
		cir["currentPlayerId"] = str(eligible[next_idx])
		game_state["currentPlayerId"] = str(eligible[next_idx])
		game_state["combatIntrigueRound"] = cir

func play_plot_intrigue(game_state, board_map, intrigue_card_id: String) -> Dictionary:
	var cur: Variant = _get_current_player(game_state)
	if typeof(cur) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "no_current_player"}
	var iid := str(intrigue_card_id).strip_edges()
	var hand_raw: Variant = cur.get("intrigue", [])
	var hand: Array = hand_raw if typeof(hand_raw) == TYPE_ARRAY else []
	if hand.find(iid) < 0:
		return {"ok": false, "reason": "intrigue_not_in_hand"}
	var ib_raw: Variant = game_state.get("intriguesById", {})
	var ib: Dictionary = ib_raw if typeof(ib_raw) == TYPE_DICTIONARY else {}
	var def_raw: Variant = ib.get(iid, {})
	if typeof(def_raw) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "unknown_intrigue"}
	var intrigue_type := str(def_raw.get("intrigueType", "")).strip_edges().to_lower()
	var allow_anytime_draw := false
	var fx_raw: Variant = (def_raw as Dictionary).get("playEffect", [])
	if typeof(fx_raw) == TYPE_ARRAY:
		for fx in (fx_raw as Array):
			if typeof(fx) == TYPE_DICTIONARY and str((fx as Dictionary).get("type", "")).strip_edges().to_lower() == "draw_cards":
				allow_anytime_draw = true
				break
	if intrigue_type != "plot" and not allow_anytime_draw:
		return {"ok": false, "reason": "not_plot_or_anytime_intrigue"}
	var hi := hand.find(iid)
	hand.remove_at(hi)
	cur["intrigue"] = hand
	cur["intrigueCount"] = hand.size()
	deck_service.append_intrigue_discard(game_state, iid)
	var play_fx: Variant = def_raw.get("playEffect", [])
	if board_map != null and board_map.has_method("resolve_space_effects") and typeof(play_fx) == TYPE_ARRAY and not play_fx.is_empty():
		board_map.resolve_space_effects(play_fx, cur, game_state, {"context": "plot_intrigue", "intrigue_card_id": iid})
	_resolve_pending_effects(game_state, cur, board_map, "plot_intrigue_play")
	_append_log(game_state, {
		"type": "plot_intrigue_played",
		"playerId": str(cur.get("id", "")),
		"intrigueCardId": iid
	})
	_bump_state_version(game_state)
	return {"ok": true}

func decline_immediate_conflict_win_intrigue(game_state) -> Dictionary:
	var pic_raw: Variant = game_state.get("pendingImmediateConflictWinIntrigue", {})
	if typeof(pic_raw) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "no_pending_immediate_intrigue"}
	game_state["pendingImmediateConflictWinIntrigue"] = {}
	_append_log(game_state, {"type": "immediate_conflict_win_intrigue_declined"})
	_bump_state_version(game_state)
	return {"ok": true}

func play_immediate_conflict_win_intrigue(game_state, board_map) -> Dictionary:
	var pic_raw: Variant = game_state.get("pendingImmediateConflictWinIntrigue", {})
	if typeof(pic_raw) != TYPE_DICTIONARY or pic_raw.is_empty():
		return {"ok": false, "reason": "no_pending_immediate_intrigue"}
	var pid := str(pic_raw.get("playerId", ""))
	var iid := str(pic_raw.get("intrigueCardId", ""))
	var cur: Variant = _find_player_by_id(game_state, pid)
	if typeof(cur) != TYPE_DICTIONARY or iid == "":
		game_state["pendingImmediateConflictWinIntrigue"] = {}
		return {"ok": false, "reason": "invalid_pending_immediate_intrigue"}
	var hand_raw: Variant = cur.get("intrigue", [])
	var hand: Array = hand_raw if typeof(hand_raw) == TYPE_ARRAY else []
	if hand.find(iid) < 0:
		game_state["pendingImmediateConflictWinIntrigue"] = {}
		return {"ok": false, "reason": "intrigue_not_in_hand"}
	var ib2_raw: Variant = game_state.get("intriguesById", {})
	var ib2: Dictionary = ib2_raw if typeof(ib2_raw) == TYPE_DICTIONARY else {}
	var def_im: Variant = ib2.get(iid, {})
	if typeof(def_im) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "unknown_intrigue"}
	var hi := hand.find(iid)
	hand.remove_at(hi)
	cur["intrigue"] = hand
	cur["intrigueCount"] = hand.size()
	deck_service.append_intrigue_discard(game_state, iid)
	var play_fx: Variant = (def_im as Dictionary).get("playEffect", [])
	if board_map != null and board_map.has_method("resolve_space_effects") and typeof(play_fx) == TYPE_ARRAY and not play_fx.is_empty():
		board_map.resolve_space_effects(play_fx, cur, game_state, {"context": "immediate_conflict_win_intrigue", "intrigue_card_id": iid})
	_resolve_pending_effects(game_state, cur, board_map, "immediate_conflict_win_intrigue")
	game_state["pendingImmediateConflictWinIntrigue"] = {}
	_append_log(game_state, {
		"type": "immediate_conflict_win_intrigue_played",
		"playerId": pid,
		"intrigueCardId": iid
	})
	_bump_state_version(game_state)
	return {"ok": true}

func pass_endgame_intrigue(game_state) -> Dictionary:
	if str(game_state.get("status", "")) != "finished":
		return {"ok": false, "reason": "game_not_finished"}
	var eir_raw: Variant = game_state.get("endgameIntrigueRound", {})
	var eir: Dictionary = eir_raw if typeof(eir_raw) == TYPE_DICTIONARY else {}
	if str(eir.get("status", "")) != "open":
		return {"ok": false, "reason": "no_endgame_intrigue_round"}
	var eligible: Array = eir.get("eligiblePlayerIds", []) if typeof(eir.get("eligiblePlayerIds", [])) == TYPE_ARRAY else []
	var idx := int(eir.get("currentIndex", 0))
	var passes := int(eir.get("consecutivePasses", 0)) + 1
	var n := eligible.size()
	if n <= 0 or passes >= n:
		eir["status"] = "done"
		game_state["endgameIntrigueRound"] = eir
		_append_log(game_state, {"type": "endgame_intrigue_round_completed"})
		_bump_state_version(game_state)
		return {"ok": true}
	var next_idx := (idx + 1) % n
	eir["currentIndex"] = next_idx
	eir["consecutivePasses"] = passes
	eir["currentPlayerId"] = str(eligible[next_idx])
	game_state["endgameIntrigueRound"] = eir
	game_state["currentPlayerId"] = str(eir["currentPlayerId"])
	_append_log(game_state, {"type": "endgame_intrigue_passed", "playerId": str(eligible[idx])})
	_bump_state_version(game_state)
	return {"ok": true, "awaitingInteraction": true}

func play_endgame_intrigue(game_state, board_map, intrigue_card_id: String) -> Dictionary:
	if str(game_state.get("status", "")) != "finished":
		return {"ok": false, "reason": "game_not_finished"}
	var eir_raw: Variant = game_state.get("endgameIntrigueRound", {})
	var eir: Dictionary = eir_raw if typeof(eir_raw) == TYPE_DICTIONARY else {}
	if str(eir.get("status", "")) != "open":
		return {"ok": false, "reason": "no_endgame_intrigue_round"}
	var expected := str(eir.get("currentPlayerId", ""))
	var cur: Variant = _find_player_by_id(game_state, expected)
	if typeof(cur) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "player_not_found"}
	var iid := str(intrigue_card_id).strip_edges()
	var hand_raw: Variant = cur.get("intrigue", [])
	var hand: Array = hand_raw if typeof(hand_raw) == TYPE_ARRAY else []
	if hand.find(iid) < 0:
		return {"ok": false, "reason": "intrigue_not_in_hand"}
	var ib3_raw: Variant = game_state.get("intriguesById", {})
	var ib3: Dictionary = ib3_raw if typeof(ib3_raw) == TYPE_DICTIONARY else {}
	var def_eg: Variant = ib3.get(iid, {})
	if typeof(def_eg) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "unknown_intrigue"}
	if str((def_eg as Dictionary).get("intrigueType", "")).strip_edges().to_lower() != "endgame":
		return {"ok": false, "reason": "not_endgame_intrigue"}
	var hi := hand.find(iid)
	hand.remove_at(hi)
	cur["intrigue"] = hand
	cur["intrigueCount"] = hand.size()
	deck_service.append_intrigue_discard(game_state, iid)
	var play_fx: Variant = (def_eg as Dictionary).get("playEffect", [])
	if board_map != null and board_map.has_method("resolve_space_effects") and typeof(play_fx) == TYPE_ARRAY and not play_fx.is_empty():
		board_map.resolve_space_effects(play_fx, cur, game_state, {"context": "endgame_intrigue", "intrigue_card_id": iid})
	_resolve_pending_effects(game_state, cur, board_map, "endgame_intrigue_play")
	var eligible: Array = eir.get("eligiblePlayerIds", []) if typeof(eir.get("eligiblePlayerIds", [])) == TYPE_ARRAY else []
	var idx_turn := int(eir.get("currentIndex", 0))
	var ne := eligible.size()
	if ne > 0:
		var next_idx := (idx_turn + 1) % ne
		eir["currentIndex"] = next_idx
		eir["consecutivePasses"] = 0
		eir["currentPlayerId"] = str(eligible[next_idx])
		game_state["currentPlayerId"] = str(eir["currentPlayerId"])
	game_state["endgameIntrigueRound"] = eir
	_append_log(game_state, {"type": "endgame_intrigue_played", "playerId": expected, "intrigueCardId": iid})
	_bump_state_version(game_state)
	return {"ok": true, "awaitingInteraction": true}

func pass_combat_intrigue(game_state, _board_map) -> Dictionary:
	if str(game_state.get("phase", "")) != "conflict":
		return {"ok": false, "reason": "wrong_phase"}
	var cir_raw: Variant = game_state.get("combatIntrigueRound", {})
	var cir: Dictionary = cir_raw if typeof(cir_raw) == TYPE_DICTIONARY else {}
	if str(cir.get("status", "")) != "open":
		return {"ok": false, "reason": "no_combat_intrigue_round"}
	var expected := str(cir.get("currentPlayerId", ""))
	var cur: Variant = _find_player_by_id(game_state, expected)
	if typeof(cur) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "player_not_found"}
	var eligible_raw: Variant = cir.get("eligiblePlayerIds", [])
	var eligible: Array = eligible_raw if typeof(eligible_raw) == TYPE_ARRAY else []
	if eligible.is_empty():
		return {"ok": false, "reason": "invalid_combat_intrigue_state"}
	var idx := int(cir.get("currentIndex", 0))
	var passes := int(cir.get("consecutivePasses", 0)) + 1
	var n := eligible.size()
	if passes >= n:
		cir["status"] = "done"
		cir["consecutivePasses"] = passes
		game_state["combatIntrigueRound"] = cir
		_append_log(game_state, {
			"type": "combat_intrigue_round_completed",
			"reason": "all_passed"
		})
		return resolve_conflict_stub(game_state)
	var next_idx := (idx + 1) % n
	cir["currentIndex"] = next_idx
	cir["consecutivePasses"] = passes
	var next_pid := str(eligible[next_idx])
	cir["currentPlayerId"] = next_pid
	game_state["combatIntrigueRound"] = cir
	game_state["currentPlayerId"] = next_pid
	_auto_pass_forced_combat_intrigue_players(game_state)
	cir = game_state.get("combatIntrigueRound", {})
	if str(cir.get("status", "")) == "done":
		return resolve_conflict_stub(game_state)
	_append_log(game_state, {
		"type": "combat_intrigue_passed",
		"playerId": expected
	})
	_bump_state_version(game_state)
	return {"ok": true, "awaitingInteraction": true}

func play_combat_intrigue(game_state, board_map, intrigue_card_id: String) -> Dictionary:
	if str(game_state.get("phase", "")) != "conflict":
		return {"ok": false, "reason": "wrong_phase"}
	var cir_raw: Variant = game_state.get("combatIntrigueRound", {})
	var cir: Dictionary = cir_raw if typeof(cir_raw) == TYPE_DICTIONARY else {}
	if str(cir.get("status", "")) != "open":
		return {"ok": false, "reason": "no_combat_intrigue_round"}
	var expected := str(cir.get("currentPlayerId", ""))
	var cur: Variant = _find_player_by_id(game_state, expected)
	if typeof(cur) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "player_not_found"}
	var iid := str(intrigue_card_id).strip_edges()
	var hand_raw: Variant = cur.get("intrigue", [])
	var hand: Array = hand_raw if typeof(hand_raw) == TYPE_ARRAY else []
	if hand.find(iid) < 0:
		return {"ok": false, "reason": "intrigue_not_in_hand"}
	var intrigues_by_id_raw: Variant = game_state.get("intriguesById", {})
	var intrigues_by_id: Dictionary = intrigues_by_id_raw if typeof(intrigues_by_id_raw) == TYPE_DICTIONARY else {}
	var def_raw: Variant = intrigues_by_id.get(iid, {})
	if typeof(def_raw) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "unknown_intrigue"}
	if str(def_raw.get("intrigueType", "")).strip_edges().to_lower() != "combat":
		return {"ok": false, "reason": "not_combat_intrigue"}
	var hi := hand.find(iid)
	hand.remove_at(hi)
	cur["intrigue"] = hand
	cur["intrigueCount"] = hand.size()
	deck_service.append_intrigue_discard(game_state, iid)
	var play_fx: Variant = def_raw.get("playEffect", [])
	if board_map != null and board_map.has_method("resolve_space_effects") and typeof(play_fx) == TYPE_ARRAY and not play_fx.is_empty():
		board_map.resolve_space_effects(play_fx, cur, game_state, {
			"context": "combat_intrigue",
			"intrigue_card_id": iid
		})
	_resolve_pending_effects(game_state, cur, board_map, "combat_intrigue_play")
	var eligible_raw: Variant = cir.get("eligiblePlayerIds", [])
	var eligible: Array = eligible_raw if typeof(eligible_raw) == TYPE_ARRAY else []
	var idx_turn := int(cir.get("currentIndex", 0))
	var ne := eligible.size()
	if ne > 0:
		var next_idx := (idx_turn + 1) % ne
		cir["currentIndex"] = next_idx
		cir["consecutivePasses"] = 0
		var next_pid := str(eligible[next_idx])
		cir["currentPlayerId"] = next_pid
		game_state["currentPlayerId"] = next_pid
	game_state["combatIntrigueRound"] = cir
	_auto_pass_forced_combat_intrigue_players(game_state)
	cir = game_state.get("combatIntrigueRound", {})
	if str(cir.get("status", "")) == "done":
		return resolve_conflict_stub(game_state)
	_append_log(game_state, {
		"type": "combat_intrigue_played",
		"playerId": expected,
		"intrigueCardId": iid
	})
	_bump_state_version(game_state)
	return {"ok": true, "awaitingInteraction": true}

func resolve_conflict(game_state):
	if game_state.get("phase", "") != "conflict":
		return {"ok": false, "reason": "wrong_phase"}

	var conflict_zone_pre: Variant = game_state.get("conflictZone", {})
	var conflict_zone: Dictionary = conflict_zone_pre if typeof(conflict_zone_pre) == TYPE_DICTIONARY else {}

	var cir_raw_pre: Variant = game_state.get("combatIntrigueRound", {})
	var cir_pre: Dictionary = cir_raw_pre if typeof(cir_raw_pre) == TYPE_DICTIONARY else {}
	var cstatus_pre := str(cir_pre.get("status", "idle"))
	if cstatus_pre == "idle":
		_init_combat_intrigue_round(game_state, conflict_zone)
		cir_pre = game_state.get("combatIntrigueRound", {})
		cstatus_pre = str(cir_pre.get("status", "resolved"))

	if cstatus_pre == "open":
		_auto_pass_forced_combat_intrigue_players(game_state)
		cir_pre = game_state.get("combatIntrigueRound", {})
		cstatus_pre = str(cir_pre.get("status", "resolved"))
		if cstatus_pre == "done":
			return resolve_conflict_stub(game_state)
		var cp_open := str(cir_pre.get("currentPlayerId", ""))
		if cp_open != "":
			game_state["currentPlayerId"] = cp_open
		_bump_state_version(game_state)
		return {"ok": true, "newPhase": "conflict", "awaitingInteraction": true, "step": "combat_intrigue"}

	# MVP conflict resolution:
	# - power = troops_in_conflict * 2 + revealed_sword_power
	# - for 2 players, distribute only first/second rewards
	# - resolve ties by shifting the place down by one
	var players = game_state.get("players", [])
	var card_def = game_state.get("activeConflictCardDef", null)
	if card_def == null:
		var defs = game_state.get("conflictCardsById", {})
		var card_id = str(game_state.get("activeConflictCardId", ""))
		if typeof(defs) == TYPE_DICTIONARY and defs.has(card_id):
			card_def = defs[card_id]

	var first_reward = []
	var second_reward = []
	var third_reward = []
	if typeof(card_def) == TYPE_DICTIONARY:
		first_reward = card_def.get("firstReward", [])
		second_reward = card_def.get("secondReward", [])
		third_reward = card_def.get("thirdReward", [])

	# Power computation:
	# power = troops_in_conflict * 2 + revealed_sword_power
	# Participation is explicit: only troops committed into conflictZone are counted.
	var snapshots: Dictionary = conflict_rules.build_power_snapshots(players, conflict_zone)
	var power_by_player: Dictionary = snapshots.get("powerByPlayer", {})
	var participant_power_by_player: Dictionary = snapshots.get("participantPowerByPlayer", {})
	var ranking = conflict_rules.compute_ranking_groups(participant_power_by_player)
	var top_group = []
	var second_group = []
	var third_group = []
	if ranking.size() > 0:
		top_group = ranking[0]
	if ranking.size() > 1:
		second_group = ranking[1]
	if ranking.size() > 2:
		third_group = ranking[2]

	var n_participants := participant_power_by_player.size()
	var unique_winner_id := ""
	if n_participants > 0 and top_group.size() == 1:
		unique_winner_id = str(top_group[0])
	if n_participants == 0:
		# Nobody committed troops -> nobody receives conflict rewards.
		pass
	elif n_participants == 1:
		_apply_rewards_to_group(first_reward, top_group, game_state, conflict_zone)
	# For MVP: only 1st/2nd rewards are used when there are 2 participants.
	elif n_participants == 2:
		if top_group.size() == 2:
			# tie for first -> both take place 2
			_apply_rewards_to_group(second_reward, top_group, game_state, conflict_zone)
		else:
			_apply_rewards_to_group(first_reward, top_group, game_state, conflict_zone)
			if second_group.size() > 0:
				_apply_rewards_to_group(second_reward, second_group, game_state, conflict_zone)
	else:
		# Generic 3-reward distribution with tie shift by one place.
		if top_group.size() > 1:
			_apply_rewards_to_group(second_reward, top_group, game_state, conflict_zone)
			if second_group.size() > 0:
				_apply_rewards_to_group(third_reward, second_group, game_state, conflict_zone)
		else:
			_apply_rewards_to_group(first_reward, top_group, game_state, conflict_zone)
			if second_group.size() > 1:
				_apply_rewards_to_group(third_reward, second_group, game_state, conflict_zone)
			elif second_group.size() == 1:
				_apply_rewards_to_group(second_reward, second_group, game_state, conflict_zone)
				if third_group.size() > 0:
					_apply_rewards_to_group(third_reward, third_group, game_state, conflict_zone)

	for p_flush in players:
		if typeof(p_flush) == TYPE_DICTIONARY:
			_resolve_pending_effects(game_state, p_flush, null, "conflict_reward")
	if unique_winner_id != "":
		_apply_objective_battle_icon_logic(game_state, unique_winner_id)

	# Clear per-round conflict totals and revealed strength.
	game_state["conflictZone"] = {}
	for player in players:
		player["troopsInConflict"] = 0
		player["sandwormsInConflict"] = 0
		player["pendingSummonSandworm"] = 0
		_sync_pending_interactions(player)
		player["revealedSwordPower"] = 0

	if _has_pending_conflict_reward_choice(game_state):
		_set_current_player_from_pending_conflict_choice(game_state)
		_append_log(game_state, {
			"type": "conflict_reward_choice_waiting_for_player",
			"playerId": str(game_state.get("currentPlayerId", ""))
		})
		_bump_state_version(game_state)
		return {"ok": true, "newPhase": "conflict", "awaitingInteraction": true}
	var pending_contract_player_id := _find_player_id_with_pending_contract_choice(game_state)
	if pending_contract_player_id != "":
		game_state["currentPlayerId"] = pending_contract_player_id
		_bump_state_version(game_state)
		return {"ok": true, "newPhase": "conflict", "awaitingInteraction": true}
	var pending_place_spy_id := _find_first_player_id_with_pending_place_spy(game_state)
	if pending_place_spy_id != "":
		game_state["currentPlayerId"] = pending_place_spy_id
		var psp: Variant = _find_player_by_id(game_state, pending_place_spy_id)
		if typeof(psp) == TYPE_DICTIONARY:
			_sync_pending_interactions(psp)
		_append_log(game_state, {
			"type": "conflict_place_spy_waiting_for_player",
			"playerId": pending_place_spy_id
		})
		_bump_state_version(game_state)
		return {"ok": true, "newPhase": "conflict", "awaitingInteraction": true}
	phase_handler.to_makers(game_state)
	game_state["combatIntrigueRound"] = {"status": "idle"}
	_append_log(game_state, {
		"type": "conflict_resolved",
		"activeConflictCardId": game_state.get("activeConflictCardId", null),
		"powerByPlayer": power_by_player,
		"participantPowerByPlayer": participant_power_by_player
	})
	_append_log(game_state, {
		"type": "phase_changed",
		"phase": "makers"
	})
	_bump_state_version(game_state)
	return {"ok": true, "newPhase": "makers"}

func _apply_objective_battle_icon_logic(game_state: Dictionary, winner_player_id: String) -> void:
	var winner_raw: Variant = _find_player_by_id(game_state, winner_player_id)
	if typeof(winner_raw) != TYPE_DICTIONARY:
		return
	var winner: Dictionary = winner_raw
	var conflict_card_id := str(game_state.get("activeConflictCardId", "")).strip_edges()
	if conflict_card_id == "":
		return
	var active_conflict_raw: Variant = game_state.get("activeConflictCardDef", {})
	var active_conflict: Dictionary = active_conflict_raw if typeof(active_conflict_raw) == TYPE_DICTIONARY else {}
	var battle_icons_raw: Variant = active_conflict.get("battleIcons", [])
	var battle_icons: Array = battle_icons_raw if typeof(battle_icons_raw) == TYPE_ARRAY else []
	if battle_icons.is_empty():
		return
	var battle_icon := str(battle_icons[0]).strip_edges()
	if battle_icon == "":
		return
	objective_resolution_service.register_won_conflict_card(winner, conflict_card_id, battle_icon)
	var match_result: Dictionary = objective_resolution_service.try_resolve_battle_icon_match(winner, game_state, conflict_card_id)
	_append_log(game_state, {
		"type": "conflict_card_claimed",
		"playerId": winner_player_id,
		"conflictCardId": conflict_card_id,
		"battleIcon": battle_icon,
		"objectiveMatched": bool(match_result.get("matched", false))
	})

func resolve_conflict_stub(game_state):
	# Backward-compatible alias kept during incremental migration.
	return resolve_conflict(game_state)

func run_maker_phase(game_state, board_map) -> Dictionary:
	if game_state.get("phase", "") != "makers":
		return {"ok": false, "reason": "wrong_phase"}
	if board_map == null or not board_map.has_method("apply_maker_phase"):
		return {"ok": false, "reason": "board_map_missing_maker_phase"}
	board_map.apply_maker_phase(game_state)
	phase_handler.to_recall(game_state)
	_append_log(game_state, {
		"type": "phase_changed",
		"phase": "recall"
	})
	_bump_state_version(game_state)
	return {"ok": true, "newPhase": "recall"}

func _compute_ranking_groups(power_by_player):
	return conflict_rules.compute_ranking_groups(power_by_player)

func _apply_rewards_to_group(reward_list, group_player_ids, game_state, conflict_zone = {}):
	conflict_rewards.apply_rewards_to_group(
		reward_list,
		group_player_ids,
		game_state,
		conflict_zone,
		_reward_callbacks()
	)

func _find_player_by_id(game_state, player_id):
	return GameStateAccessScript.find_player_by_id(game_state, str(player_id))

func _apply_reward(reward, player_state, game_state, multiplier: int = 1):
	conflict_rewards.apply_reward(
		reward,
		player_state if typeof(player_state) == TYPE_DICTIONARY else {},
		game_state if typeof(game_state) == TYPE_DICTIONARY else {},
		multiplier,
		_reward_callbacks()
	)

func _normalize_conflict_reward(reward: Dictionary, game_state: Dictionary) -> Dictionary:
	return conflict_rewards.normalize_conflict_reward(reward, game_state)

func _resolve_influence_faction_for_reward(reward: Dictionary, player_state: Dictionary) -> String:
	return conflict_rewards.resolve_influence_faction_for_reward(reward, player_state)

func _pick_best_influence_faction(player_state: Dictionary, candidates: Array) -> String:
	return conflict_rewards.pick_best_influence_faction(player_state, candidates)

func _apply_cost_reward(
	reward: Dictionary,
	player_state: Dictionary,
	game_state: Dictionary,
	allow_defer: bool = true,
	sandworm_second_cost_eligible: bool = false
) -> void:
	conflict_rewards.apply_cost_reward(
		reward,
		player_state,
		game_state,
		allow_defer,
		sandworm_second_cost_eligible,
		_reward_callbacks()
	)

func _grant_control(board_space_id: String, player_state: Dictionary, game_state: Dictionary) -> void:
	conflict_rewards.grant_control(board_space_id, player_state, game_state, _reward_callbacks())

func _cost_reward_to_effect_tokens_text(reward: Dictionary) -> String:
	return conflict_rewards.cost_reward_to_effect_tokens_text(reward)

func _reward_callbacks() -> Dictionary:
	return {
		"find_player_by_id": Callable(self, "_find_player_by_id"),
		"append_log": Callable(self, "_append_log"),
		"sync_pending_interactions": Callable(self, "_sync_pending_interactions"),
		"apply_influence_delta": Callable(faction_progression_service, "apply_influence_delta"),
		"queue_contract_choice": Callable(ContractServiceScript, "queue_contract_choice_for_player"),
		"recall_spy": Callable(SpySystemScript, "recall_spy"),
		"get_player_spy_post_ids": Callable(SpySystemScript, "get_player_spy_post_ids"),
		"normalize_trash_allowed_zones": Callable(self, "_normalize_trash_allowed_zones"),
		"reward_multiplier_for_player": Callable(self, "_reward_multiplier_for_player")
	}

func _has_pending_conflict_reward_choice(game_state: Dictionary) -> bool:
	return pending_conflict_service.has_pending_conflict_reward_choice(game_state)

func _set_current_player_from_pending_conflict_choice(game_state: Dictionary) -> void:
	pending_conflict_service.set_current_player_from_pending_conflict_choice(game_state)

func _continue_after_conflict_pending_resolution(game_state: Dictionary, board_map) -> Dictionary:
	return pending_conflict_tail_service.continue_after_conflict_pending_resolution(
		game_state,
		board_map,
		_pending_conflict_tail_callbacks()
	)

func _find_player_id_with_pending_spy_recall_draw(game_state: Dictionary) -> String:
	return pending_conflict_tail_service.find_player_id_with_pending_spy_recall_draw(game_state)

func _find_player_id_with_pending_contract_choice(game_state: Dictionary) -> String:
	return pending_conflict_tail_service.find_player_id_with_pending_contract_choice(game_state)

## If the first sandworm-eligible cost payment was deferred (recall chain or other pending interactions),
## promote to a second optional `pendingConflictCostChoice` once the player can act again.
func try_promote_pending_conflict_sandworm_second_cost(game_state) -> void:
	pending_conflict_service.try_promote_pending_conflict_sandworm_second_cost(game_state, _pending_conflict_callbacks())

func _pending_conflict_callbacks() -> Dictionary:
	return {
		"find_player_by_id": Callable(self, "_find_player_by_id"),
		"apply_cost_reward": Callable(self, "_apply_cost_reward"),
		"append_log": Callable(self, "_append_log"),
		"has_pending_player_interaction": Callable(self, "has_pending_player_interaction"),
		"sync_pending_interactions": Callable(self, "_sync_pending_interactions"),
		"apply_influence_delta": Callable(faction_progression_service, "apply_influence_delta"),
		"bump_state_version": Callable(self, "_bump_state_version")
	}

func _find_first_player_id_with_pending_place_spy(game_state: Dictionary) -> String:
	return pending_conflict_tail_service.find_first_player_id_with_pending_place_spy(game_state)

func _pending_conflict_tail_callbacks() -> Dictionary:
	return {
		"has_pending_conflict_reward_choice": Callable(self, "_has_pending_conflict_reward_choice"),
		"set_current_player_from_pending_conflict_choice": Callable(self, "_set_current_player_from_pending_conflict_choice"),
		"bump_state_version": Callable(self, "_bump_state_version"),
		"find_player_by_id": Callable(self, "_find_player_by_id"),
		"sync_pending_interactions": Callable(self, "_sync_pending_interactions"),
		"phase_to_makers": Callable(phase_handler, "to_makers"),
		"append_log": Callable(self, "_append_log"),
		"run_maker_phase": Callable(self, "run_maker_phase"),
		"run_recall_phase": Callable(self, "run_recall_phase"),
		"start_round": Callable(self, "start_round")
	}

func _reward_multiplier_for_player(player_id: String, conflict_zone: Variant, game_state: Variant = null) -> int:
	if typeof(conflict_zone) == TYPE_DICTIONARY and conflict_zone.has(player_id):
		var zone_entry: Variant = conflict_zone[player_id]
		if typeof(zone_entry) == TYPE_DICTIONARY:
			if int(zone_entry.get("sandworms", 0)) > 0:
				return 2
	if typeof(game_state) == TYPE_DICTIONARY:
		var pl: Variant = _find_player_by_id(game_state, player_id)
		if typeof(pl) == TYPE_DICTIONARY and int((pl as Dictionary).get("sandwormsInConflict", 0)) > 0:
			return 2
	return 1

func run_recall_phase(game_state):
	if game_state.get("phase", "") != "recall":
		return {"ok": false, "reason": "wrong_phase"}

	# Return Agents from board to leaders for all players.
	game_state["boardOccupancy"] = {}
	var players = game_state.get("players", [])
	for player in players:
		player["agentsOnBoard"] = []
		var total = int(player.get("agentsTotal", 2))
		player["agentsAvailable"] = total

	_rotate_first_player(game_state)
	game_state["currentPlayerId"] = str(game_state.get("firstPlayerId", ""))

	_append_log(game_state, {
		"type": "recall_phase_resolved"
	})
	_bump_state_version(game_state)
	return {"ok": true}

func finish_round_pipeline(game_state, board_map):
	# player_turns -> conflict -> makers -> recall -> start_round
	var end_turns = end_player_turns_phase(game_state, board_map)
	if not end_turns.get("ok", false):
		return {"ok": false, "step": "end_player_turns_phase", "detail": end_turns}

	var conflict = resolve_conflict_stub(game_state)
	if not conflict.get("ok", false):
		return {"ok": false, "step": "resolve_conflict_stub", "detail": conflict}
	if bool(conflict.get("awaitingInteraction", false)):
		return {"ok": true, "awaitingInteraction": true, "step": "resolve_conflict_stub"}

	var makers = run_maker_phase(game_state, board_map)
	if not makers.get("ok", false):
		return {"ok": false, "step": "run_maker_phase", "detail": makers}

	var recall = run_recall_phase(game_state)
	if not recall.get("ok", false):
		return {"ok": false, "step": "run_recall_phase", "detail": recall}

	var end_by_vp = _finalize_game_if_vp_threshold_reached(game_state)
	if bool(end_by_vp.get("ended", false)):
		return {
			"ok": true,
			"steps": {
				"end_player_turns_phase": end_turns,
				"resolve_conflict_stub": conflict,
				"run_maker_phase": makers,
				"run_recall_phase": recall,
				"finish_game": end_by_vp
			}
		}

	var next_round = start_round(game_state)
	if not next_round.get("ok", false):
		return {"ok": false, "step": "start_round", "detail": next_round}

	return {
		"ok": true,
		"steps": {
			"end_player_turns_phase": end_turns,
			"resolve_conflict_stub": conflict,
			"run_maker_phase": makers,
			"run_recall_phase": recall,
			"start_round": next_round
		}
	}

## When conflict resolution completes inside pass_combat_intrigue / play_combat_intrigue (phase becomes makers),
## call this to run makers → recall → optional finish / next round — same tail as finish_round_pipeline.
func continue_round_pipeline_from_current_phase(game_state, board_map) -> Dictionary:
	if str(game_state.get("phase", "")) == "makers":
		var makers = run_maker_phase(game_state, board_map)
		if not bool(makers.get("ok", false)):
			return {"ok": false, "step": "run_maker_phase", "detail": makers}
	if str(game_state.get("phase", "")) == "recall":
		var recall = run_recall_phase(game_state)
		if not bool(recall.get("ok", false)):
			return {"ok": false, "step": "run_recall_phase", "detail": recall}
		var end_by_vp = _finalize_game_if_vp_threshold_reached(game_state)
		if bool(end_by_vp.get("ended", false)):
			return {"ok": true, "ended": true, "finish_game": end_by_vp}
		var next_round = start_round(game_state)
		if not bool(next_round.get("ok", false)):
			return {"ok": false, "step": "start_round", "detail": next_round}
		return {
			"ok": true,
			"steps": {
				"run_recall_phase": recall,
				"start_round": next_round
			}
		}
	return {"ok": true, "phase": str(game_state.get("phase", "")), "reason": "no_pipeline_tail"}

func _init_endgame_intrigue_round_if_any_cards(game_state: Dictionary) -> void:
	endgame_resolution_service.init_endgame_intrigue_round_if_any_cards(game_state, _endgame_callbacks())

func _finalize_game_if_vp_threshold_reached(game_state) -> Dictionary:
	return endgame_resolution_service.finalize_game_if_vp_threshold_reached(game_state, _endgame_callbacks())

func _endgame_callbacks() -> Dictionary:
	return {
		"append_log": Callable(self, "_append_log"),
		"order_player_ids_from_first_player": Callable(self, "_order_player_ids_from_first_player"),
		"compare_players_for_endgame": Callable(RuleContractScript, "compare_players_for_endgame")
	}

func start_round(game_state):
	var current_round = int(game_state.get("round", 0))
	game_state["round"] = current_round + 1
	phase_handler.to_player_turns(game_state)

	# Game end check (simplified MVP):
	# if conflict deck is empty at round start, end the game and don't enter player turns.
	var deck = game_state.get("conflictDeck", [])
	if typeof(deck) != TYPE_ARRAY or deck.is_empty():
		game_state["status"] = "finished"
		_append_log(game_state, {
			"type": "game_finished",
			"reason": "conflict_deck_empty"
		})
		return {"ok": false, "reason": "conflict_deck_empty"}

	var players = game_state.get("players", [])
	game_state["revealOrderCounter"] = 0
	game_state["conflictZone"] = {}
	game_state["combatIntrigueRound"] = {"status": "idle"}
	game_state["endgameIntrigueRound"] = {}
	game_state["pendingImmediateConflictWinIntrigue"] = {}
	for player in players:
		if typeof(player) == TYPE_DICTIONARY:
			_resolve_pending_effects(game_state, player, null, "round_start_carryover")
	for player in players:
		player["passedReveal"] = false
		player["agentsOnBoard"] = []
		var total = int(player.get("agentsTotal", 2))
		player["agentsAvailable"] = total
		player["persuasion"] = 0
		player["pendingDrawCards"] = 0
		player["pendingDrawIntrigue"] = 0
		player["pendingTrash"] = 0
		player["pendingTrashQueue"] = []
		player["pendingSpyRecallDrawCards"] = 0
		player["pendingSpyRecallDrawPostIds"] = []
		player["pendingSpyRecallDrawSpaceId"] = ""
		player["pendingContractChoice"] = {}
		player["pendingConflictDeployMax"] = 0
		player["pendingConflictDeployFromEffect"] = 0
		player["pendingConflictDeployFromGarrison"] = 0
		player["pendingSummonSandworm"] = 0
		player["turnFlags"] = {
			"sent_agent_to_maker_space_this_turn": false,
			"sent_agent_to_faction_space_this_turn": false,
			"recalled_spy_this_turn": false
		}
		_sync_pending_interactions(player)
		player["revealedSwordPower"] = 0
		player["troopsInConflict"] = 0
		player["sandwormsInConflict"] = 0
		player["lastRevealOrder"] = -1
		deck_service.prepare_new_round_hand(player, ROUND_HAND_SIZE)
		_append_log(game_state, {
			"type": "hand_drawn",
			"playerId": str(player.get("id", "")),
			"deckSize": int(player.get("deck", []).size()) if typeof(player.get("deck", [])) == TYPE_ARRAY else 0,
			"handSize": int(player.get("hand", []).size()) if typeof(player.get("hand", [])) == TYPE_ARRAY else 0,
			"discardSize": int(player.get("discard", []).size()) if typeof(player.get("discard", [])) == TYPE_ARRAY else 0
		})

		var pid = str(player.get("id", ""))
		if pid != "":
			game_state["conflictZone"][pid] = {
				"troops": 0,
				"sandworms": 0,
				"revealedSwordPower": 0,
				"totalPower": 0
			}

	var first_id = str(game_state.get("firstPlayerId", ""))
	if first_id == "":
		first_id = _first_player_id(game_state)
	game_state["currentPlayerId"] = first_id

	# Rule: reveal the top conflict card at round start.
	var revealed_conflict = _reveal_conflict_card(game_state)
	if revealed_conflict == null:
		game_state["status"] = "finished"
		_append_log(game_state, {
			"type": "game_finished",
			"reason": "no_conflict_card_revealed"
		})
		return {"ok": false, "reason": "no_conflict_card_revealed"}

	# Attach conflict card definition for reward resolution.
	var defs = game_state.get("conflictCardsById", {})
	if typeof(defs) == TYPE_DICTIONARY and defs.has(str(revealed_conflict)):
		game_state["activeConflictCardDef"] = defs[str(revealed_conflict)]
	else:
		game_state["activeConflictCardDef"] = null
	_append_log(game_state, {
		"type": "round_started",
		"round": game_state["round"],
		"firstPlayerId": first_id,
		"activeConflictCardId": revealed_conflict
	})
	_bump_state_version(game_state)
	return {
		"ok": true,
		"round": game_state["round"],
		"currentPlayerId": first_id,
		"activeConflictCardId": revealed_conflict
	}

func _bump_state_version(game_state) -> void:
	var current_version := int(game_state.get("version", 0))
	game_state["version"] = current_version + 1

func _sync_pending_interactions(player: Dictionary) -> void:
	var pending: Array = []
	var pending_trash := int(player.get("pendingTrash", 0))
	if pending_trash > 0:
		var allowed_zones: Array = ["hand", "discard"]
		var pending_trash_queue_raw: Variant = player.get("pendingTrashQueue", [])
		if typeof(pending_trash_queue_raw) == TYPE_ARRAY:
			var pending_trash_queue: Array = pending_trash_queue_raw
			if not pending_trash_queue.is_empty() and typeof(pending_trash_queue[0]) == TYPE_DICTIONARY:
				var queue_entry: Dictionary = pending_trash_queue[0]
				var zones_raw: Variant = queue_entry.get("allowedZones", [])
				if typeof(zones_raw) == TYPE_ARRAY:
					allowed_zones = zones_raw
		pending.append({
			"type": "trash_card",
			"amount": pending_trash,
			"allowedZones": allowed_zones
		})
	var pending_deploy := int(player.get("pendingConflictDeployMax", 0))
	if pending_deploy > 0:
		pending.append({
			"type": "conflict_deploy",
			"max": pending_deploy,
			"fromEffect": int(player.get("pendingConflictDeployFromEffect", 0)),
			"fromGarrison": int(player.get("pendingConflictDeployFromGarrison", 0))
		})
	var pending_spy := int(player.get("pendingPlaceSpy", 0))
	if pending_spy > 0:
		pending.append({
			"type": "place_spy",
			"amount": pending_spy
		})
	var pending_spy_recall_draw := int(player.get("pendingSpyRecallDrawCards", 0))
	if pending_spy_recall_draw > 0:
		var post_ids = player.get("pendingSpyRecallDrawPostIds", [])
		if typeof(post_ids) != TYPE_ARRAY:
			post_ids = []
		pending.append({
			"type": "spy_recall_draw",
			"amount": pending_spy_recall_draw,
			"spaceId": str(player.get("pendingSpyRecallDrawSpaceId", "")),
			"postIds": post_ids
		})
	var pending_card_choice_raw: Variant = player.get("pendingCardChoice", {})
	if typeof(pending_card_choice_raw) == TYPE_DICTIONARY:
		var pending_card_choice: Dictionary = pending_card_choice_raw
		if not pending_card_choice.is_empty():
			var ui_raw: Variant = pending_card_choice.get("ui", {})
			var ui: Dictionary = ui_raw if typeof(ui_raw) == TYPE_DICTIONARY else {}
			pending.append({
				"type": "card_choice",
				"slot": int(ui.get("slot", 0)),
				"title": str(ui.get("title", "Card effect choice"))
			})
	var pending_contract_choice_raw: Variant = player.get("pendingContractChoice", {})
	if typeof(pending_contract_choice_raw) == TYPE_DICTIONARY and not (pending_contract_choice_raw as Dictionary).is_empty():
		pending.append({
			"type": "contract_choice",
			"title": "choose face-up contract"
		})
	player["pendingInteractions"] = pending

func _normalize_trash_allowed_zones(from_value: Variant) -> Array[String]:
	var allowed: Array[String] = []
	if typeof(from_value) == TYPE_STRING:
		var normalized := _normalize_trash_zone(str(from_value))
		if normalized != "":
			allowed.append(normalized)
	elif typeof(from_value) == TYPE_ARRAY:
		for zone_raw in from_value:
			var normalized := _normalize_trash_zone(str(zone_raw))
			if normalized == "" or allowed.has(normalized):
				continue
			allowed.append(normalized)
	if allowed.is_empty():
		allowed = ["hand", "discard"]
	return allowed

func _normalize_trash_zone(zone_id: String) -> String:
	match zone_id:
		"hand":
			return "hand"
		"discard":
			return "discard"
		"inPlay", "in_play":
			return "inPlay"
		_:
			return ""

func _resolve_played_card_id(played_card):
	if typeof(played_card) == TYPE_STRING:
		return str(played_card)
	if typeof(played_card) == TYPE_DICTIONARY:
		return str(played_card.get("id", ""))
	return ""

func _build_played_card_for_board(game_state, card_id):
	var cards_by_id = game_state.get("cardsById", {})
	if typeof(cards_by_id) != TYPE_DICTIONARY or not cards_by_id.has(card_id):
		return {}

	var raw_def = cards_by_id[card_id]
	if typeof(raw_def) != TYPE_DICTIONARY:
		return {}

	var card_def = raw_def.duplicate(true)
	card_def["id"] = card_id
	return card_def

func _hand_contains_card(player_state, card_id):
	var hand = player_state.get("hand", [])
	if typeof(hand) != TYPE_ARRAY:
		hand = []
		player_state["hand"] = hand
	return hand.find(card_id) >= 0

func _advance_to_next_active_player(game_state):
	var players = game_state.get("players", [])
	if players.is_empty():
		game_state["currentPlayerId"] = ""
		return

	var current_id = str(game_state.get("currentPlayerId", ""))
	var start_index = _player_index_by_id(players, current_id)
	if start_index < 0:
		start_index = 0

	for step in range(1, players.size() + 1):
		var idx = (start_index + step) % players.size()
		if not bool(players[idx].get("passedReveal", false)):
			game_state["currentPlayerId"] = str(players[idx].get("id", ""))
			return

	game_state["currentPlayerId"] = ""

func _get_current_player(game_state):
	return GameStateAccessScript.get_current_player(game_state)

func _first_player_id(game_state):
	var players = GameStateAccessScript.get_players(game_state)
	if players.is_empty():
		return ""
	return str(players[0].get("id", ""))

func _player_index_by_id(players, player_id):
	for i in range(players.size()):
		if str(players[i].get("id", "")) == player_id:
			return i
	return -1

func _rotate_first_player(game_state) -> void:
	var players = GameStateAccessScript.get_players(game_state)
	if typeof(players) != TYPE_ARRAY or players.is_empty():
		return
	var current_first = GameStateAccessScript.get_first_player_id(game_state)
	var idx = _player_index_by_id(players, current_first)
	if idx < 0:
		GameStateAccessScript.set_first_player_id(game_state, str(players[0].get("id", "")))
		return
	var next_idx = (idx + 1) % players.size()
	GameStateAccessScript.set_first_player_id(game_state, str(players[next_idx].get("id", "")))

func _append_log(game_state, entry):
	if typeof(entry) != TYPE_DICTIONARY:
		return
	GameStateAccessScript.append_log(game_state, entry)

func _reveal_conflict_card(game_state):
	var deck = game_state.get("conflictDeck", [])
	if typeof(deck) != TYPE_ARRAY or deck.is_empty():
		game_state["activeConflictCardId"] = null
		return null

	var top_index = deck.size() - 1
	var card_id = deck[top_index]
	deck.remove_at(top_index)
	game_state["conflictDeck"] = deck
	game_state["activeConflictCardId"] = card_id
	_append_log(game_state, {
		"type": "conflict_card_revealed",
		"round": int(game_state.get("round", 0)),
		"conflictCardId": card_id
	})
	return card_id
