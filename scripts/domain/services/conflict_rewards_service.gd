extends RefCounted
class_name ConflictRewardsService

func apply_rewards_to_group(
	reward_list: Variant,
	group_player_ids: Variant,
	game_state: Dictionary,
	conflict_zone: Variant,
	callbacks: Dictionary
) -> void:
	if typeof(reward_list) != TYPE_ARRAY or typeof(group_player_ids) != TYPE_ARRAY:
		return
	var find_player_by_id: Callable = callbacks.get("find_player_by_id", Callable())
	var reward_multiplier_for_player: Callable = callbacks.get("reward_multiplier_for_player", Callable())
	for pid in (group_player_ids as Array):
		var player: Variant = find_player_by_id.call(game_state, str(pid))
		if typeof(player) != TYPE_DICTIONARY:
			continue
		var multiplier := int(reward_multiplier_for_player.call(str(pid), conflict_zone, game_state))
		for reward in (reward_list as Array):
			apply_reward(reward, player, game_state, multiplier, callbacks)

func apply_reward(
	reward: Variant,
	player_state: Dictionary,
	game_state: Dictionary,
	multiplier: int,
	callbacks: Dictionary
) -> void:
	if typeof(reward) != TYPE_DICTIONARY:
		return
	var normalized_reward: Dictionary = normalize_conflict_reward(reward, game_state)
	var r_type := str(normalized_reward.get("type", ""))
	var applied_multiplier := maxi(multiplier, 1)
	if r_type == "gain_control":
		applied_multiplier = 1
	if r_type == "vp":
		player_state["vp"] = int(player_state.get("vp", 0)) + int(normalized_reward.get("amount", 0)) * applied_multiplier
		return
	if r_type == "gain_resource" or r_type == "resource":
		var res := str(normalized_reward.get("resource", ""))
		var resources: Dictionary = player_state.get("resources", {}) if typeof(player_state.get("resources", {})) == TYPE_DICTIONARY else {}
		resources[res] = int(resources.get(res, 0)) + int(normalized_reward.get("amount", 0)) * applied_multiplier
		player_state["resources"] = resources
		return
	if r_type == "recruit_troops":
		player_state["garrisonTroops"] = int(player_state.get("garrisonTroops", 0)) + int(normalized_reward.get("amount", 0)) * applied_multiplier
		return
	if r_type == "gain_influence":
		_apply_gain_influence_reward(normalized_reward, player_state, game_state, applied_multiplier, callbacks)
		return
	if r_type == "draw_intrigue" or r_type == "intrigue":
		player_state["pendingDrawIntrigue"] = int(player_state.get("pendingDrawIntrigue", 0)) + int(normalized_reward.get("amount", 1)) * applied_multiplier
		return
	if r_type == "trash_card":
		var normalized_amount := maxi(int(normalized_reward.get("amount", 1)) * applied_multiplier, 0)
		if normalized_amount <= 0:
			return
		var pending_queue: Array = player_state.get("pendingTrashQueue", []) if typeof(player_state.get("pendingTrashQueue", [])) == TYPE_ARRAY else []
		var normalize_trash_allowed_zones: Callable = callbacks.get("normalize_trash_allowed_zones", Callable())
		pending_queue.append({
			"remaining": normalized_amount,
			"allowedZones": normalize_trash_allowed_zones.call(normalized_reward.get("from", null))
		})
		player_state["pendingTrashQueue"] = pending_queue
		player_state["pendingTrash"] = int(player_state.get("pendingTrash", 0)) + normalized_amount
		var sync_pending_interactions: Callable = callbacks.get("sync_pending_interactions", Callable())
		sync_pending_interactions.call(player_state)
		return
	if r_type == "place_spy":
		player_state["pendingPlaceSpy"] = int(player_state.get("pendingPlaceSpy", 0)) + int(normalized_reward.get("amount", 1)) * applied_multiplier
		var sync_pending_interactions_spy: Callable = callbacks.get("sync_pending_interactions", Callable())
		sync_pending_interactions_spy.call(player_state)
		return
	if r_type == "get_contract" or r_type == "contract":
		var queue_contract_choice: Callable = callbacks.get("queue_contract_choice", Callable())
		var append_log: Callable = callbacks.get("append_log", Callable())
		var amount_contract := maxi(int(normalized_reward.get("amount", 1)) * applied_multiplier, 1)
		queue_contract_choice.call(
			game_state,
			player_state,
			amount_contract,
			normalized_reward.get("fallbackEffects", []),
			func(fallback_to_apply: Array) -> void:
				for fallback_effect in fallback_to_apply:
					if typeof(fallback_effect) != TYPE_DICTIONARY:
						continue
					apply_reward(fallback_effect, player_state, game_state, 1, callbacks),
			func(entry: Dictionary) -> void:
				append_log.call(game_state, entry)
		)
		return
	if r_type == "cost":
		var sandworm_second_cost_eligible: bool = applied_multiplier >= 2
		apply_cost_reward(normalized_reward, player_state, game_state, true, sandworm_second_cost_eligible, callbacks)
		return
	if r_type == "gain_control":
		grant_control(str(normalized_reward.get("boardSpaceId", "")), player_state, game_state, callbacks)
		return

func normalize_conflict_reward(reward: Dictionary, game_state: Dictionary) -> Dictionary:
	var normalized: Dictionary = reward.duplicate(true)
	var reward_type := str(normalized.get("type", "")).strip_edges()
	if reward_type == "control":
		reward_type = "gain_control"
	elif reward_type == "resource":
		reward_type = "gain_resource"
	elif reward_type == "intrigue":
		reward_type = "draw_intrigue"
	elif reward_type == "contract":
		reward_type = "get_contract"
	normalized["type"] = reward_type
	if reward_type == "gain_influence":
		var faction := str(normalized.get("faction", "")).strip_edges()
		if faction == "spacing_guild":
			faction = "guild"
		elif faction == "bene_gesserit":
			faction = "beneGesserit"
		normalized["faction"] = faction
	if reward_type == "gain_control":
		var board_space_id := str(normalized.get("boardSpaceId", "")).strip_edges()
		if board_space_id == "":
			board_space_id = str(normalized.get("controlSpaceId", "")).strip_edges()
		if board_space_id == "":
			board_space_id = str(game_state.get("activeConflictControlSpaceId", "")).strip_edges()
		normalized["boardSpaceId"] = board_space_id
	if reward_type in ["vp", "recruit_troops", "draw_intrigue", "get_contract", "place_spy", "trash_card"]:
		normalized["amount"] = int(normalized.get("amount", 1))
	return normalized

func resolve_influence_faction_for_reward(reward: Dictionary, player_state: Dictionary) -> String:
	var faction := str(reward.get("faction", "")).strip_edges()
	if faction == "anyone":
		return pick_best_influence_faction(player_state, ["emperor", "guild", "beneGesserit", "fremen"])
	if faction == "choose_two":
		var options: Variant = reward.get("factions", [])
		if typeof(options) == TYPE_ARRAY and not (options as Array).is_empty():
			var normalized_options: Array[String] = []
			for option in (options as Array):
				var normalized := str(option).strip_edges()
				if normalized == "spacing_guild":
					normalized = "guild"
				elif normalized == "bene_gesserit":
					normalized = "beneGesserit"
				if not normalized_options.has(normalized):
					normalized_options.append(normalized)
			return pick_best_influence_faction(player_state, normalized_options)
		return pick_best_influence_faction(player_state, ["emperor", "guild", "beneGesserit", "fremen"])
	return faction

func pick_best_influence_faction(player_state: Dictionary, candidates: Array) -> String:
	var influence_map: Dictionary = player_state.get("influence", {}) if typeof(player_state.get("influence", {})) == TYPE_DICTIONARY else {}
	var best_faction := ""
	var best_value := 2147483647
	for candidate in candidates:
		var faction := str(candidate)
		if faction == "":
			continue
		var value := int(influence_map.get(faction, 0))
		if best_faction == "" or value < best_value:
			best_faction = faction
			best_value = value
	return best_faction

func apply_cost_reward(
	reward: Dictionary,
	player_state: Dictionary,
	game_state: Dictionary,
	allow_defer: bool,
	sandworm_second_cost_eligible: bool,
	callbacks: Dictionary
) -> void:
	var resource := str(reward.get("resource", ""))
	var cost_amount := int(reward.get("amount", 0))
	var resources: Dictionary = player_state.get("resources", {}) if typeof(player_state.get("resources", {})) == TYPE_DICTIONARY else {}
	var nested_effect: Variant = reward.get("effect", {})
	if resource == "recall_spy":
		var get_player_spy_post_ids: Callable = callbacks.get("get_player_spy_post_ids", Callable())
		var available_recall: Array = get_player_spy_post_ids.call(game_state, str(player_state.get("id", "")))
		if available_recall.size() < cost_amount:
			return
		if allow_defer and str(game_state.get("phase", "")) == "conflict":
			game_state["pendingConflictCostChoice"] = {
				"playerId": str(player_state.get("id", "")),
				"reward": reward.duplicate(true),
				"remainingCostOffers": 2 if sandworm_second_cost_eligible else 1
			}
			return
		var phase := str(game_state.get("phase", ""))
		if phase == "player_turns" or phase == "conflict":
			player_state["pendingSpyRecallDrawCards"] = cost_amount
			player_state["pendingSpyRecallDrawGrantCards"] = 0
			player_state["pendingSpyRecallDrawPostIds"] = available_recall
			player_state["pendingSpyRecallDrawSpaceId"] = "cost_recall_spy"
			player_state["pendingSpyRecallRewardEffects"] = [nested_effect] if typeof(nested_effect) == TYPE_DICTIONARY else []
			var sync_pending_interactions: Callable = callbacks.get("sync_pending_interactions", Callable())
			sync_pending_interactions.call(player_state)
			return
		var recall_spy: Callable = callbacks.get("recall_spy", Callable())
		var recalls_done := 0
		for post_id in available_recall:
			if recalls_done >= cost_amount:
				break
			var recall_result: Dictionary = recall_spy.call(game_state, str(player_state.get("id", "")), str(post_id))
			if bool(recall_result.get("ok", false)):
				recalls_done += 1
		if recalls_done < cost_amount:
			return
		if typeof(nested_effect) == TYPE_DICTIONARY:
			apply_reward(nested_effect, player_state, game_state, 1, callbacks)
		return
	if allow_defer and str(game_state.get("phase", "")) == "conflict":
		if int(resources.get(resource, 0)) >= cost_amount:
			game_state["pendingConflictCostChoice"] = {
				"playerId": str(player_state.get("id", "")),
				"reward": reward.duplicate(true),
				"remainingCostOffers": 2 if sandworm_second_cost_eligible else 1
			}
		return
	if int(resources.get(resource, 0)) < cost_amount:
		return
	resources[resource] = int(resources.get(resource, 0)) - cost_amount
	player_state["resources"] = resources
	if typeof(nested_effect) == TYPE_DICTIONARY:
		apply_reward(nested_effect, player_state, game_state, 1, callbacks)

func grant_control(board_space_id: String, player_state: Dictionary, game_state: Dictionary, callbacks: Dictionary) -> void:
	if board_space_id == "":
		return
	var owner_id := str(player_state.get("id", ""))
	if owner_id == "":
		return
	var control_map: Dictionary = game_state.get("controlBySpace", {}) if typeof(game_state.get("controlBySpace", {})) == TYPE_DICTIONARY else {}
	var previous_owner := str(control_map.get(board_space_id, ""))
	control_map[board_space_id] = owner_id
	game_state["controlBySpace"] = control_map
	var append_log: Callable = callbacks.get("append_log", Callable())
	append_log.call(game_state, {
		"type": "control_awarded",
		"boardSpaceId": board_space_id,
		"playerId": owner_id,
		"previousOwnerId": previous_owner
	})

func cost_reward_to_effect_tokens_text(reward: Dictionary) -> String:
	if str(reward.get("type", "")) != "cost":
		return "-"
	var resource := str(reward.get("resource", ""))
	var amount := int(reward.get("amount", 0))
	var effect: Variant = reward.get("effect", {})
	if typeof(effect) != TYPE_DICTIONARY:
		return "-"
	var effect_dict: Dictionary = effect
	var gain_type := str(effect_dict.get("type", ""))
	if gain_type == "vp":
		return "[cost_trade:%s:%d:vp:%d]" % [resource, amount, int(effect_dict.get("amount", 0))]
	if gain_type == "resource":
		return "[cost_trade:%s:%d:%s:%d]" % [resource, amount, str(effect_dict.get("resource", "")), int(effect_dict.get("amount", 0))]
	return "-"

func _apply_gain_influence_reward(
	normalized_reward: Dictionary,
	player_state: Dictionary,
	game_state: Dictionary,
	applied_multiplier: int,
	callbacks: Dictionary
) -> void:
	var raw_faction := str(normalized_reward.get("faction", "")).strip_edges()
	if raw_faction == "choose_two" and str(game_state.get("phase", "")) == "conflict":
		var base_amount := int(normalized_reward.get("amount", 1))
		var factions_raw: Variant = normalized_reward.get("factions", ["guild", "fremen", "beneGesserit", "emperor"])
		var template: Array = []
		if typeof(factions_raw) == TYPE_ARRAY:
			for fe in factions_raw:
				var fn := str(fe).strip_edges()
				if fn == "spacing_guild":
					fn = "guild"
				elif fn == "bene_gesserit":
					fn = "beneGesserit"
				if fn != "" and not template.has(fn):
					template.append(fn)
		if template.is_empty():
			template = ["guild", "fremen", "beneGesserit", "emperor"]
		var total_influence_rounds := 2 if applied_multiplier >= 2 else 1
		game_state["pendingConflictInfluenceChoice"] = {
			"playerId": str(player_state.get("id", "")),
			"factions": template.duplicate(),
			"factionsTemplate": template.duplicate(),
			"picksRemaining": 2,
			"amount": base_amount,
			"influenceRoundsLeft": total_influence_rounds,
			"totalInfluenceRounds": total_influence_rounds
		}
		return
	var amount := int(normalized_reward.get("amount", 0)) * applied_multiplier
	var faction := resolve_influence_faction_for_reward(normalized_reward, player_state)
	if faction == "":
		return
	var apply_influence_delta: Callable = callbacks.get("apply_influence_delta", Callable())
	apply_influence_delta.call(game_state, player_state, faction, amount)
