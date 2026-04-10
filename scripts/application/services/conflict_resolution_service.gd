extends RefCounted
class_name ConflictResolutionService

var _turn_controller: TurnController

func _init(turn_controller: TurnController) -> void:
	_turn_controller = turn_controller

func resolve_conflict(game_state: Dictionary) -> Dictionary:
	if _turn_controller == null:
		return {"ok": false, "reason": "turn_controller_missing"}
	return _turn_controller.resolve_conflict(game_state)
