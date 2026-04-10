extends RefCounted
class_name PhaseHandler

func to_conflict(game_state: Dictionary) -> void:
	game_state["phase"] = "conflict"

func to_makers(game_state: Dictionary) -> void:
	game_state["phase"] = "makers"

func to_recall(game_state: Dictionary) -> void:
	game_state["phase"] = "recall"

func to_player_turns(game_state: Dictionary) -> void:
	game_state["phase"] = "player_turns"
