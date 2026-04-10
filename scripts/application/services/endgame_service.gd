extends RefCounted
class_name EndgameService

var _turn_controller: TurnController

func _init(turn_controller: TurnController) -> void:
	_turn_controller = turn_controller

func continue_or_finish(game_state: Dictionary, board_map: Node) -> Dictionary:
	if _turn_controller == null:
		return {"ok": false, "reason": "turn_controller_missing"}
	return _turn_controller.continue_round_pipeline_from_current_phase(game_state, board_map)
