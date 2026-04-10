extends RefCounted
class_name GameStateModel

var phase: String = ""
var round_number: int = 0
var current_player_id: String = ""
var first_player_id: String = ""
var status: String = ""
var winner_player_id: String = ""

func from_dict(data: Dictionary) -> GameStateModel:
	phase = str(data.get("phase", ""))
	round_number = int(data.get("round", 0))
	current_player_id = str(data.get("currentPlayerId", ""))
	first_player_id = str(data.get("firstPlayerId", ""))
	status = str(data.get("status", ""))
	winner_player_id = str(data.get("winnerPlayerId", ""))
	return self

func to_dict() -> Dictionary:
	return {
		"phase": phase,
		"round": round_number,
		"currentPlayerId": current_player_id,
		"firstPlayerId": first_player_id,
		"status": status,
		"winnerPlayerId": winner_player_id
	}
