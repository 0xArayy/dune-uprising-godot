extends Node
class_name GameCoordinator

const TurnPipelineScript = preload("res://scripts/application/turn_pipeline.gd")
const RuleContractScript = preload("res://scripts/domain/rule_contract.gd")
const GameStateMapperScript = preload("res://scripts/domain/game_state_mapper.gd")

var _turn_controller: TurnController
var _pipeline: TurnPipeline
var _state_mapper: GameStateMapper = GameStateMapperScript.new()

func setup(turn_controller: TurnController) -> void:
	_turn_controller = turn_controller
	_pipeline = TurnPipelineScript.new(turn_controller)

func start_round(game_state: Dictionary) -> Dictionary:
	if _turn_controller == null:
		return {"ok": false, "reason": "not_setup"}
	var shape_check: Dictionary = RuleContractScript.validate_game_state_shape(game_state)
	if not bool(shape_check.get("ok", false)):
		return shape_check
	# Keep a typed boundary at the application layer to reduce accidental
	# dictionary-key drift while domain migration is in progress.
	var model_bundle: Dictionary = _state_mapper.to_models(game_state)
	var normalized_state: Dictionary = _state_mapper.apply_models_to_state(game_state, model_bundle)
	game_state.clear()
	for key in normalized_state.keys():
		game_state[key] = normalized_state[key]
	return _turn_controller.start_round(game_state)

func finish_round(game_state: Dictionary, board_map: Node) -> Dictionary:
	if _pipeline == null:
		return {"ok": false, "reason": "not_setup"}
	return _pipeline.execute_after_player_turns(game_state, board_map)

func continue_round_pipeline_from_current_phase(game_state: Dictionary, board_map: Node) -> Dictionary:
	if _turn_controller == null:
		return {"ok": false, "reason": "not_setup"}
	return _turn_controller.continue_round_pipeline_from_current_phase(game_state, board_map)
