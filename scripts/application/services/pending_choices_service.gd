extends RefCounted
class_name PendingChoicesService

var _turn_controller: TurnController

func _init(turn_controller: TurnController) -> void:
	_turn_controller = turn_controller

func has_pending(game_state: Dictionary) -> bool:
	if _turn_controller == null:
		return false
	return _turn_controller.has_pending_player_interaction(game_state)

func get_pending_state(game_state: Dictionary) -> Dictionary:
	if _turn_controller == null:
		return {}
	return _turn_controller.get_pending_state_for_current_player(game_state)
