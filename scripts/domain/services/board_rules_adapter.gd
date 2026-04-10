extends RefCounted
class_name BoardRulesAdapter

var _placement_rules_service: PlacementRulesService
var _board_effects_service: BoardEffectsService

func _init(
	placement_rules_service: PlacementRulesService,
	board_effects_service: BoardEffectsService
) -> void:
	_placement_rules_service = placement_rules_service
	_board_effects_service = board_effects_service

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
	if _placement_rules_service == null:
		return {"ok": false, "reason": "placement_rules_service_missing"}
	return _placement_rules_service.can_place_agent(
		space_id,
		player_state,
		board_occupancy,
		played_card,
		game_state,
		resolve_space_def,
		check_card_access,
		check_requirements,
		check_cost,
		is_occupied,
		has_spy_access
	)

func resolve_space_effects(
	normalized_effects: Array,
	player_state: Dictionary,
	game_state: Dictionary,
	context: Dictionary,
	choice_option_is_choosable: Callable,
	is_requirement_met: Callable,
	apply_single_effect: Callable,
	contains_effect_type: Callable,
	update_shield_wall_visuals: Callable
) -> Dictionary:
	if _board_effects_service == null:
		return {"ok": false, "reason": "board_effects_service_missing"}
	return _board_effects_service.resolve_space_effects(
		normalized_effects,
		player_state,
		game_state,
		context,
		choice_option_is_choosable,
		is_requirement_met,
		apply_single_effect,
		contains_effect_type,
		update_shield_wall_visuals
	)
