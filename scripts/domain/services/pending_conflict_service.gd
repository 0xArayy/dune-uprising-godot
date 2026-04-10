extends RefCounted
class_name PendingConflictService

func get_pending_conflict_cost_choice_context(game_state: Dictionary, callbacks: Dictionary) -> Dictionary:
	var pending: Variant = game_state.get("pendingConflictCostChoice", {})
	if typeof(pending) != TYPE_DICTIONARY:
		return {}
	var player_id := str((pending as Dictionary).get("playerId", ""))
	var reward: Variant = (pending as Dictionary).get("reward", {})
	if player_id == "" or typeof(reward) != TYPE_DICTIONARY:
		return {}
	var to_tokens: Callable = callbacks.get("cost_reward_to_effect_tokens_text", Callable())
	var context: Dictionary = (pending as Dictionary).duplicate(true)
	context["optionEffectsTexts"] = [
		to_tokens.call(reward as Dictionary),
		"-"
	]
	return context

func get_pending_conflict_influence_choice_context(game_state: Dictionary) -> Dictionary:
	var pending: Variant = game_state.get("pendingConflictInfluenceChoice", {})
	if typeof(pending) != TYPE_DICTIONARY:
		return {}
	var pending_dict: Dictionary = pending
	var player_id := str(pending_dict.get("playerId", ""))
	var factions: Variant = pending_dict.get("factions", [])
	var picks_remaining := int(pending_dict.get("picksRemaining", 0))
	if player_id == "" or typeof(factions) != TYPE_ARRAY or picks_remaining <= 0:
		return {}
	var option_texts: Array = []
	var option_factions: Array = []
	for faction in factions:
		var faction_id := str(faction)
		option_factions.append(faction_id)
		option_texts.append("[faction_influence_choice:%s]" % faction_id)
	var total_rounds := int(pending_dict.get("totalInfluenceRounds", 1))
	var rounds_left := int(pending_dict.get("influenceRoundsLeft", 1))
	var title := "choose two influence (%d picks left)" % picks_remaining
	if total_rounds > 1:
		var cur_round := total_rounds - rounds_left + 1
		title = "choose two influence (round %d/%d, %d picks left)" % [cur_round, total_rounds, picks_remaining]
	return {
		"playerId": player_id,
		"picksRemaining": picks_remaining,
		"optionFactions": option_factions,
		"optionEffectsTexts": option_texts,
		"title": title
	}

func resolve_pending_conflict_cost_choice_state(game_state: Dictionary, accept: bool, callbacks: Dictionary) -> Dictionary:
	var pending: Variant = game_state.get("pendingConflictCostChoice", {})
	if typeof(pending) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "no_pending_conflict_cost_choice"}
	var pending_dict: Dictionary = pending
	var player_id := str(pending_dict.get("playerId", ""))
	var reward: Variant = pending_dict.get("reward", {})
	if player_id == "" or typeof(reward) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "invalid_pending_conflict_cost_choice"}
	var find_player_by_id: Callable = callbacks.get("find_player_by_id", Callable())
	var player: Variant = find_player_by_id.call(game_state, player_id)
	if typeof(player) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "player_not_found"}
	var remaining_offers := int(pending_dict.get("remainingCostOffers", 1))
	if remaining_offers < 1:
		remaining_offers = 1
	var reward_dup: Dictionary = (reward as Dictionary).duplicate(true)
	var saved_current_id := str(game_state.get("currentPlayerId", ""))
	game_state["currentPlayerId"] = player_id
	if accept:
		var apply_cost_reward: Callable = callbacks.get("apply_cost_reward", Callable())
		apply_cost_reward.call(reward_dup, player as Dictionary, game_state, false, false)
	var append_log: Callable = callbacks.get("append_log", Callable())
	append_log.call(game_state, {
		"type": "conflict_cost_choice_resolved",
		"playerId": player_id,
		"accepted": accept
	})
	remaining_offers -= 1
	game_state["pendingConflictCostChoice"] = {}
	if remaining_offers > 0:
		var has_pending_player_interaction: Callable = callbacks.get("has_pending_player_interaction", Callable())
		var needs_defer := int((player as Dictionary).get("pendingSpyRecallDrawCards", 0)) > 0 or bool(has_pending_player_interaction.call(game_state))
		if needs_defer:
			game_state["pendingConflictSandwormSecondCost"] = {
				"playerId": player_id,
				"reward": reward_dup.duplicate(true),
				"remainingCostOffers": remaining_offers
			}
		else:
			game_state["pendingConflictCostChoice"] = {
				"playerId": player_id,
				"reward": reward_dup.duplicate(true),
				"remainingCostOffers": remaining_offers
			}
	game_state["currentPlayerId"] = saved_current_id
	return {"ok": true, "shouldContinue": true}

func resolve_pending_conflict_influence_choice_state(game_state: Dictionary, faction: String, callbacks: Dictionary) -> Dictionary:
	var pending: Variant = game_state.get("pendingConflictInfluenceChoice", {})
	if typeof(pending) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "no_pending_conflict_influence_choice"}
	var pending_dict: Dictionary = pending
	var player_id := str(pending_dict.get("playerId", ""))
	var picks_remaining := int(pending_dict.get("picksRemaining", 0))
	var amount := int(pending_dict.get("amount", 1))
	var factions_raw: Variant = pending_dict.get("factions", [])
	if player_id == "" or picks_remaining <= 0 or typeof(factions_raw) != TYPE_ARRAY:
		return {"ok": false, "reason": "invalid_pending_conflict_influence_choice"}
	var factions: Array = factions_raw
	if not factions.has(faction):
		return {"ok": false, "reason": "invalid_pending_conflict_influence_choice"}
	var find_player_by_id: Callable = callbacks.get("find_player_by_id", Callable())
	var player: Variant = find_player_by_id.call(game_state, player_id)
	if typeof(player) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "player_not_found"}
	var apply_influence_delta: Callable = callbacks.get("apply_influence_delta", Callable())
	apply_influence_delta.call(game_state, player as Dictionary, faction, amount)
	picks_remaining -= 1
	factions.erase(faction)
	var append_log: Callable = callbacks.get("append_log", Callable())
	append_log.call(game_state, {
		"type": "conflict_influence_choice_resolved",
		"playerId": player_id,
		"faction": faction,
		"remaining": picks_remaining
	})
	if picks_remaining > 0:
		pending_dict["factions"] = factions
		pending_dict["picksRemaining"] = picks_remaining
		game_state["pendingConflictInfluenceChoice"] = pending_dict
		var bump_state_version: Callable = callbacks.get("bump_state_version", Callable())
		bump_state_version.call(game_state)
		return {"ok": true, "awaitingInteraction": true}
	var influence_rounds_left := int(pending_dict.get("influenceRoundsLeft", 1)) - 1
	if influence_rounds_left > 0:
		var template_raw: Variant = pending_dict.get("factionsTemplate", [])
		var new_factions: Array = []
		if typeof(template_raw) == TYPE_ARRAY:
			for fe in template_raw:
				new_factions.append(str(fe))
		if new_factions.is_empty():
			new_factions = ["guild", "fremen", "beneGesserit", "emperor"]
		pending_dict["factions"] = new_factions.duplicate()
		pending_dict["picksRemaining"] = 2
		pending_dict["influenceRoundsLeft"] = influence_rounds_left
		game_state["pendingConflictInfluenceChoice"] = pending_dict
		var bump_state_version_round: Callable = callbacks.get("bump_state_version", Callable())
		bump_state_version_round.call(game_state)
		return {"ok": true, "awaitingInteraction": true}
	game_state["pendingConflictInfluenceChoice"] = {}
	return {"ok": true, "shouldContinue": true}

func has_pending_conflict_reward_choice(game_state: Dictionary) -> bool:
	var pending_influence: Variant = game_state.get("pendingConflictInfluenceChoice", {})
	if typeof(pending_influence) == TYPE_DICTIONARY and not (pending_influence as Dictionary).is_empty():
		return true
	var pending_cost: Variant = game_state.get("pendingConflictCostChoice", {})
	if typeof(pending_cost) == TYPE_DICTIONARY and not (pending_cost as Dictionary).is_empty():
		return true
	var pending_sandworm_second: Variant = game_state.get("pendingConflictSandwormSecondCost", {})
	return typeof(pending_sandworm_second) == TYPE_DICTIONARY and not (pending_sandworm_second as Dictionary).is_empty()

func set_current_player_from_pending_conflict_choice(game_state: Dictionary) -> void:
	var pending_influence: Variant = game_state.get("pendingConflictInfluenceChoice", {})
	if typeof(pending_influence) == TYPE_DICTIONARY and not (pending_influence as Dictionary).is_empty():
		game_state["currentPlayerId"] = str((pending_influence as Dictionary).get("playerId", game_state.get("currentPlayerId", "")))
		return
	var pending_cost: Variant = game_state.get("pendingConflictCostChoice", {})
	if typeof(pending_cost) == TYPE_DICTIONARY and not (pending_cost as Dictionary).is_empty():
		game_state["currentPlayerId"] = str((pending_cost as Dictionary).get("playerId", game_state.get("currentPlayerId", "")))
		return
	var pending_sandworm_second: Variant = game_state.get("pendingConflictSandwormSecondCost", {})
	if typeof(pending_sandworm_second) == TYPE_DICTIONARY and not (pending_sandworm_second as Dictionary).is_empty():
		game_state["currentPlayerId"] = str((pending_sandworm_second as Dictionary).get("playerId", game_state.get("currentPlayerId", "")))

func try_promote_pending_conflict_sandworm_second_cost(game_state: Dictionary, callbacks: Dictionary) -> void:
	var raw: Variant = game_state.get("pendingConflictSandwormSecondCost", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var pending_second: Dictionary = raw
	if pending_second.is_empty():
		return
	var player_id := str(pending_second.get("playerId", ""))
	var reward: Variant = pending_second.get("reward", {})
	var remaining_offers := maxi(int(pending_second.get("remainingCostOffers", 1)), 1)
	if player_id == "" or typeof(reward) != TYPE_DICTIONARY:
		game_state["pendingConflictSandwormSecondCost"] = {}
		return
	var find_player_by_id: Callable = callbacks.get("find_player_by_id", Callable())
	var player: Variant = find_player_by_id.call(game_state, player_id)
	if typeof(player) != TYPE_DICTIONARY:
		return
	var saved_current := str(game_state.get("currentPlayerId", ""))
	game_state["currentPlayerId"] = player_id
	var sync_pending_interactions: Callable = callbacks.get("sync_pending_interactions", Callable())
	sync_pending_interactions.call(player as Dictionary)
	if int((player as Dictionary).get("pendingSpyRecallDrawCards", 0)) > 0:
		game_state["currentPlayerId"] = saved_current
		return
	var has_pending_player_interaction: Callable = callbacks.get("has_pending_player_interaction", Callable())
	if bool(has_pending_player_interaction.call(game_state)):
		game_state["currentPlayerId"] = saved_current
		return
	game_state["pendingConflictSandwormSecondCost"] = {}
	game_state["pendingConflictCostChoice"] = {
		"playerId": player_id,
		"reward": (reward as Dictionary).duplicate(true),
		"remainingCostOffers": remaining_offers
	}
	game_state["currentPlayerId"] = saved_current
	var bump_state_version: Callable = callbacks.get("bump_state_version", Callable())
	bump_state_version.call(game_state)
