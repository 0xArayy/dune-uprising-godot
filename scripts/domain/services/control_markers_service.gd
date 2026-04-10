extends RefCounted
class_name ControlMarkersService

func apply_control_bonus_for_space(
	space_id: String,
	acting_player_id: String,
	game_state: Dictionary,
	control_bonus_by_space: Dictionary,
	get_player_by_id: Callable,
	change_resource: Callable,
	append_game_log: Callable
) -> void:
	if not control_bonus_by_space.has(space_id):
		return
	var raw_control_map: Variant = game_state.get("controlBySpace", {})
	if typeof(raw_control_map) != TYPE_DICTIONARY:
		return
	var control_map: Dictionary = raw_control_map
	var owner_id := str(control_map.get(space_id, ""))
	if owner_id == "":
		return
	var owner_player: Dictionary = get_player_by_id.call(game_state, owner_id)
	if owner_player.is_empty():
		return
	var bonus_def: Dictionary = control_bonus_by_space[space_id]
	var resource := str(bonus_def.get("resource", ""))
	var amount := int(bonus_def.get("amount", 0))
	if resource == "" or amount <= 0:
		return
	change_resource.call(owner_player, resource, amount)
	append_game_log.call(game_state, {
		"type": "control_bonus_paid",
		"boardSpaceId": space_id,
		"actingPlayerId": acting_player_id,
		"controllerPlayerId": owner_id,
		"resource": resource,
		"amount": amount
	})
