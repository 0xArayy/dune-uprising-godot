extends RefCounted
class_name ObjectiveResolutionService

func register_won_conflict_card(player_state: Dictionary, conflict_card_id: String, battle_icon: String) -> void:
	if typeof(player_state) != TYPE_DICTIONARY:
		return
	var card_id := str(conflict_card_id).strip_edges()
	var icon := str(battle_icon).strip_edges()
	if card_id == "" or icon == "":
		return
	var won_cards_raw: Variant = player_state.get("wonConflictCards", [])
	var won_cards: Array = won_cards_raw if typeof(won_cards_raw) == TYPE_ARRAY else []
	won_cards.append({
		"id": card_id,
		"battleIcon": icon,
		"faceUp": true
	})
	player_state["wonConflictCards"] = won_cards

func try_resolve_battle_icon_match(player_state: Dictionary, game_state: Dictionary, won_conflict_card_id: String) -> Dictionary:
	if typeof(player_state) != TYPE_DICTIONARY or typeof(game_state) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "invalid_input"}
	var winner_id := str(player_state.get("id", "")).strip_edges()
	if winner_id == "":
		return {"ok": false, "reason": "missing_player_id"}
	var conflict_id := str(won_conflict_card_id).strip_edges()
	if conflict_id == "":
		return {"ok": false, "reason": "missing_conflict_card_id"}

	var won_cards_raw: Variant = player_state.get("wonConflictCards", [])
	if typeof(won_cards_raw) != TYPE_ARRAY:
		return {"ok": true, "matched": false}
	var won_cards: Array = won_cards_raw
	var won_idx := _find_conflict_entry_index_by_id(won_cards, conflict_id)
	if won_idx < 0:
		return {"ok": true, "matched": false}
	var won_entry_raw: Variant = won_cards[won_idx]
	if typeof(won_entry_raw) != TYPE_DICTIONARY:
		return {"ok": true, "matched": false}
	var won_entry: Dictionary = won_entry_raw
	if not bool(won_entry.get("faceUp", false)):
		return {"ok": true, "matched": false}
	var won_icon := str(won_entry.get("battleIcon", "")).strip_edges()
	if won_icon == "":
		return {"ok": true, "matched": false}

	var match_target := _find_face_up_match_target(player_state, won_icon, conflict_id)
	if str(match_target.get("type", "")) == "":
		return {"ok": true, "matched": false}

	won_cards[won_idx]["faceUp"] = false
	player_state["wonConflictCards"] = won_cards
	var target_type := str(match_target.get("type", ""))
	var target_id := str(match_target.get("id", ""))
	if target_type == "objective":
		_set_objective_face_up(player_state, target_id, false)
	else:
		_set_won_conflict_face_up(player_state, target_id, false)

	player_state["vp"] = int(player_state.get("vp", 0)) + 1
	_append_log(game_state, {
		"type": "objective_battle_icon_matched",
		"playerId": winner_id,
		"conflictCardId": conflict_id,
		"matchedType": target_type,
		"matchedId": target_id,
		"icon": won_icon,
		"vpGranted": 1
	})
	return {
		"ok": true,
		"matched": true,
		"targetType": target_type,
		"targetId": target_id,
		"icon": won_icon,
		"vpGranted": 1
	}

func _find_face_up_match_target(player_state: Dictionary, won_icon: String, won_conflict_card_id: String) -> Dictionary:
	var won_cards_raw: Variant = player_state.get("wonConflictCards", [])
	var won_cards: Array = won_cards_raw if typeof(won_cards_raw) == TYPE_ARRAY else []
	for entry_raw in won_cards:
		if typeof(entry_raw) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_raw
		if str(entry.get("id", "")) == won_conflict_card_id:
			continue
		if not bool(entry.get("faceUp", false)):
			continue
		var icon := str(entry.get("battleIcon", "")).strip_edges()
		if _icons_match(won_icon, icon):
			return {"type": "conflict", "id": str(entry.get("id", ""))}

	var objective_cards_raw: Variant = player_state.get("objectiveCards", [])
	var objective_cards: Array = objective_cards_raw if typeof(objective_cards_raw) == TYPE_ARRAY else []
	for entry_raw in objective_cards:
		if typeof(entry_raw) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_raw
		if not bool(entry.get("faceUp", false)):
			continue
		var icon := str(entry.get("battleIcon", "")).strip_edges()
		if _icons_match(won_icon, icon):
			return {"type": "objective", "id": str(entry.get("id", ""))}
	return {}

func _set_objective_face_up(player_state: Dictionary, objective_id: String, face_up: bool) -> void:
	var objective_cards_raw: Variant = player_state.get("objectiveCards", [])
	var objective_cards: Array = objective_cards_raw if typeof(objective_cards_raw) == TYPE_ARRAY else []
	for i in range(objective_cards.size()):
		if typeof(objective_cards[i]) != TYPE_DICTIONARY:
			continue
		if str((objective_cards[i] as Dictionary).get("id", "")) != objective_id:
			continue
		objective_cards[i]["faceUp"] = face_up
		break
	player_state["objectiveCards"] = objective_cards

func _set_won_conflict_face_up(player_state: Dictionary, conflict_card_id: String, face_up: bool) -> void:
	var won_cards_raw: Variant = player_state.get("wonConflictCards", [])
	var won_cards: Array = won_cards_raw if typeof(won_cards_raw) == TYPE_ARRAY else []
	for i in range(won_cards.size()):
		if typeof(won_cards[i]) != TYPE_DICTIONARY:
			continue
		if str((won_cards[i] as Dictionary).get("id", "")) != conflict_card_id:
			continue
		won_cards[i]["faceUp"] = face_up
		break
	player_state["wonConflictCards"] = won_cards

func _find_conflict_entry_index_by_id(won_cards: Array, conflict_card_id: String) -> int:
	for i in range(won_cards.size()):
		if typeof(won_cards[i]) != TYPE_DICTIONARY:
			continue
		if str((won_cards[i] as Dictionary).get("id", "")) == conflict_card_id:
			return i
	return -1

func _icons_match(left_icon: String, right_icon: String) -> bool:
	var left := left_icon.strip_edges()
	var right := right_icon.strip_edges()
	if left == "" or right == "":
		return false
	if left == "wild" or right == "wild":
		return true
	return left == right

func _append_log(game_state: Dictionary, entry: Dictionary) -> void:
	var log_raw: Variant = game_state.get("log", [])
	var entries: Array = log_raw if typeof(log_raw) == TYPE_ARRAY else []
	entries.append(entry)
	game_state["log"] = entries
