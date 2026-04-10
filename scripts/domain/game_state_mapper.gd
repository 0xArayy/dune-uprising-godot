extends RefCounted
class_name GameStateMapper

const GameStateModelScript = preload("res://scripts/domain/models/game_state_model.gd")
const PlayerStateModelScript = preload("res://scripts/domain/models/player_state_model.gd")
const ConflictStateModelScript = preload("res://scripts/domain/models/conflict_state_model.gd")
const PendingInteractionModelScript = preload("res://scripts/domain/models/pending_interaction_model.gd")

func to_models(game_state: Dictionary) -> Dictionary:
	var game_model: GameStateModel = GameStateModelScript.new().from_dict(game_state)
	var conflict_model: ConflictStateModel = ConflictStateModelScript.new().from_dict(game_state)
	var players_models: Array[PlayerStateModel] = []
	var pending_models: Array[PendingInteractionModel] = []
	var players_raw: Variant = game_state.get("players", [])
	if typeof(players_raw) == TYPE_ARRAY:
		for entry in players_raw:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var player_dict := entry as Dictionary
			players_models.append(PlayerStateModelScript.new().from_dict(player_dict))
			pending_models.append(PendingInteractionModelScript.new().from_player_dict(player_dict))
	return {
		"game": game_model,
		"conflict": conflict_model,
		"players": players_models,
		"pending": pending_models
	}

func apply_models_to_state(game_state: Dictionary, model_bundle: Dictionary) -> Dictionary:
	var out: Dictionary = game_state.duplicate(true)
	var game_model: Variant = model_bundle.get("game", null)
	if game_model is GameStateModel:
		var gd: Dictionary = (game_model as GameStateModel).to_dict()
		for key in gd.keys():
			out[key] = gd[key]
	var conflict_model: Variant = model_bundle.get("conflict", null)
	if conflict_model is ConflictStateModel:
		var cd: Dictionary = (conflict_model as ConflictStateModel).to_dict()
		for key in cd.keys():
			out[key] = cd[key]
	return out
