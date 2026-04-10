extends RefCounted
class_name BoardVisualSync

var _sync_markers: Callable
var _update_conflict_zone: Callable
var _update_shield_wall_visuals: Callable

func _init(
	sync_markers: Callable,
	update_conflict_zone: Callable,
	update_shield_wall_visuals: Callable
) -> void:
	_sync_markers = sync_markers
	_update_conflict_zone = update_conflict_zone
	_update_shield_wall_visuals = update_shield_wall_visuals

func sync_all(board_occupancy: Dictionary, game_state: Dictionary) -> void:
	if _sync_markers.is_valid():
		_sync_markers.call(board_occupancy, game_state)
	if _update_conflict_zone.is_valid():
		_update_conflict_zone.call(game_state)
	if _update_shield_wall_visuals.is_valid():
		_update_shield_wall_visuals.call(game_state)
