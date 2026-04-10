extends RefCounted
class_name PlacementRulesService

func can_place_agent(
	space_id: String,
	player_state: Dictionary,
	board_occupancy: Dictionary,
	played_card: Dictionary,
	game_state: Dictionary,
	resolve_space_def: Callable,
	check_card_access: Callable,
	check_requirements: Callable,
	check_cost: Callable,
	is_occupied: Callable,
	has_spy_access: Callable
) -> Dictionary:
	var space_def: Variant = resolve_space_def.call(space_id)
	if space_def == null:
		return {"ok": false, "reason": "unknown_space"}
	var card_ok: Dictionary = check_card_access.call(space_def, played_card, player_state, game_state, space_id)
	if not bool(card_ok.get("ok", false)):
		return card_ok
	var occupied := bool(is_occupied.call(space_id, board_occupancy))
	if occupied:
		var is_infiltration := bool(card_ok.get("access", "") == "spy")
		var connected := bool(has_spy_access.call(space_id, player_state, game_state))
		if not is_infiltration and not connected:
			return {"ok": false, "reason": "occupied"}
	var requirements_ok: Dictionary = check_requirements.call(space_def, player_state, played_card)
	if not bool(requirements_ok.get("ok", false)):
		return requirements_ok
	var cost_ok: Dictionary = check_cost.call(space_def, player_state)
	if not bool(cost_ok.get("ok", false)):
		return cost_ok
	return {"ok": true}
