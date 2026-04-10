extends RefCounted
class_name HudPresenter

const GameStateAccessScript = preload("res://scripts/domain/game_state_access.gd")

func build_view_model(game_state: Dictionary) -> Dictionary:
	return {
		"phase": GameStateAccessScript.get_phase(game_state),
		"round": GameStateAccessScript.get_round(game_state),
		"currentPlayerId": GameStateAccessScript.get_current_player_id(game_state)
	}
