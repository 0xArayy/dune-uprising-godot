extends RefCounted
class_name TurnPipeline

const RoundPhaseServiceScript = preload("res://scripts/application/services/round_phase_service.gd")
const ConflictResolutionServiceScript = preload("res://scripts/application/services/conflict_resolution_service.gd")
const PendingChoicesServiceScript = preload("res://scripts/application/services/pending_choices_service.gd")
const EndgameServiceScript = preload("res://scripts/application/services/endgame_service.gd")

var _turn_controller: TurnController
var _round_phase: RoundPhaseService
var _conflict_resolution: ConflictResolutionService
var _pending_choices: PendingChoicesService
var _endgame: EndgameService

func _init(turn_controller: TurnController) -> void:
	_turn_controller = turn_controller
	_round_phase = RoundPhaseServiceScript.new(turn_controller)
	_conflict_resolution = ConflictResolutionServiceScript.new(turn_controller)
	_pending_choices = PendingChoicesServiceScript.new(turn_controller)
	_endgame = EndgameServiceScript.new(turn_controller)

func execute_after_player_turns(game_state: Dictionary, board_map: Node) -> Dictionary:
	if _turn_controller == null or _round_phase == null or _conflict_resolution == null:
		return {"ok": false, "reason": "turn_controller_missing"}
	var end_turns: Dictionary = _round_phase.end_player_turns_phase(game_state, board_map)
	if not bool(end_turns.get("ok", false)):
		return {"ok": false, "step": "end_player_turns_phase", "detail": end_turns}
	var conflict: Dictionary = _conflict_resolution.resolve_conflict(game_state)
	if not bool(conflict.get("ok", false)):
		return {"ok": false, "step": "resolve_conflict", "detail": conflict}
	if _pending_choices.has_pending(game_state) or bool(conflict.get("awaitingInteraction", false)):
		return {"ok": true, "awaitingInteraction": true, "step": "resolve_conflict"}
	return _endgame.continue_or_finish(game_state, board_map)
