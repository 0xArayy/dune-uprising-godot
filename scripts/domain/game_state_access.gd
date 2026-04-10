extends RefCounted
class_name GameStateAccess

const KeysScript = preload("res://scripts/domain/game_state_keys.gd")

static func get_phase(game_state: Dictionary) -> String:
	return str(game_state.get(KeysScript.PHASE, ""))

static func set_phase(game_state: Dictionary, phase: String) -> void:
	game_state[KeysScript.PHASE] = phase

static func get_round(game_state: Dictionary) -> int:
	return int(game_state.get(KeysScript.ROUND, 0))

static func get_status(game_state: Dictionary) -> String:
	return str(game_state.get(KeysScript.STATUS, ""))

static func set_status(game_state: Dictionary, status: String) -> void:
	game_state[KeysScript.STATUS] = status

static func get_current_player_id(game_state: Dictionary) -> String:
	return str(game_state.get(KeysScript.CURRENT_PLAYER_ID, ""))

static func set_current_player_id(game_state: Dictionary, player_id: String) -> void:
	game_state[KeysScript.CURRENT_PLAYER_ID] = player_id

static func get_first_player_id(game_state: Dictionary) -> String:
	return str(game_state.get(KeysScript.FIRST_PLAYER_ID, ""))

static func set_first_player_id(game_state: Dictionary, player_id: String) -> void:
	game_state[KeysScript.FIRST_PLAYER_ID] = player_id

static func get_players(game_state: Dictionary) -> Array:
	var players_raw: Variant = game_state.get(KeysScript.PLAYERS, [])
	return players_raw if typeof(players_raw) == TYPE_ARRAY else []

static func find_player_by_id(game_state: Dictionary, player_id: String) -> Variant:
	for entry in get_players(game_state):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var player: Dictionary = entry
		if str(player.get("id", "")) == player_id:
			return player
	return null

static func get_current_player(game_state: Dictionary) -> Variant:
	var current_player_id := get_current_player_id(game_state)
	if current_player_id == "":
		return null
	return find_player_by_id(game_state, current_player_id)

static func append_log(game_state: Dictionary, entry: Dictionary) -> void:
	var log_entries_raw: Variant = game_state.get(KeysScript.LOG, [])
	var log_entries: Array = log_entries_raw if typeof(log_entries_raw) == TYPE_ARRAY else []
	log_entries.append(entry)
	game_state[KeysScript.LOG] = log_entries
