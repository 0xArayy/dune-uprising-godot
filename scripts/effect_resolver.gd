extends RefCounted
class_name EffectResolver

var faction_progression_service

func _init(faction_service = null) -> void:
	faction_progression_service = faction_service

func apply_single_effect(effect: Dictionary, player_state: Dictionary, game_state: Dictionary, context: Dictionary) -> bool:
	var effect_type = str(effect.get("type", ""))
	var amount = int(effect.get("amount", 0))

	if effect_type == "gain_resource":
		_change_resource(player_state, str(effect.get("resource", "")), amount)
		return true
	if effect_type == "spend_resource":
		_change_resource(player_state, str(effect.get("resource", "")), -amount)
		return true
	if effect_type == "gain_persuasion":
		player_state["persuasion"] = int(player_state.get("persuasion", 0)) + amount
		return true
	if effect_type == "gain_sword":
		player_state["revealedSwordPower"] = int(player_state.get("revealedSwordPower", 0)) + amount
		return true
	if effect_type == "gain_influence":
		var faction := _normalize_faction(str(effect.get("faction", "")))
		_change_influence(game_state, player_state, faction, amount)
		return true
	if effect_type == "vp":
		player_state["vp"] = int(player_state.get("vp", 0)) + amount
		return true
	if effect_type == "draw_cards":
		player_state["pendingDrawCards"] = int(player_state.get("pendingDrawCards", 0)) + amount
		return true
	if effect_type == "draw_intrigue":
		player_state["pendingDrawIntrigue"] = int(player_state.get("pendingDrawIntrigue", 0)) + amount
		return true
	if effect_type == "recruit_troops":
		player_state["garrisonTroops"] = int(player_state.get("garrisonTroops", 0)) + amount
		if bool(context.get("is_conflict_space", false)):
			var pending_conflict = context.get("pending_conflict", {})
			if typeof(pending_conflict) == TYPE_DICTIONARY:
				pending_conflict["from_effect"] = int(pending_conflict.get("from_effect", 0)) + amount
		return true
	if effect_type == "trash_card":
		var normalized_amount := maxi(amount, 0)
		if normalized_amount <= 0:
			return true
		var pending_queue_raw: Variant = player_state.get("pendingTrashQueue", [])
		var pending_queue: Array = pending_queue_raw if typeof(pending_queue_raw) == TYPE_ARRAY else []
		pending_queue.append({
			"remaining": normalized_amount,
			"allowedZones": _normalize_trash_allowed_zones(effect.get("from", null))
		})
		player_state["pendingTrashQueue"] = pending_queue
		player_state["pendingTrash"] = int(player_state.get("pendingTrash", 0)) + normalized_amount
		return true
	return false

func _normalize_faction(faction: String) -> String:
	if faction == "spacing_guild":
		return "guild"
	if faction == "bene_gesserit":
		return "beneGesserit"
	return faction

func _change_resource(player_state: Dictionary, resource: String, delta: int) -> void:
	var resources = player_state.get("resources", {})
	var current = int(resources.get(resource, 0))
	resources[resource] = max(current + delta, 0)
	player_state["resources"] = resources

func _change_influence(game_state: Dictionary, player_state: Dictionary, faction: String, delta: int) -> void:
	if faction_progression_service == null:
		return
	if not faction_progression_service.has_method("apply_influence_delta"):
		return
	faction_progression_service.apply_influence_delta(game_state, player_state, faction, delta)

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
