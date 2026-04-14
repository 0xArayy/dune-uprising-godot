extends RefCounted

const RuleContractScript = preload("res://scripts/domain/rule_contract.gd")

func run_all_checks() -> Dictionary:
	var checks: Array = [
		_check_valid_two_players(),
		_check_valid_three_players(),
		_check_valid_four_players(),
		_check_invalid_players_not_array(),
		_check_invalid_player_count_low(),
		_check_invalid_player_count_high(),
		_check_invalid_empty_phase()
	]
	for result in checks:
		if typeof(result) != TYPE_DICTIONARY:
			return {"ok": false, "reason": "game_state_shape_invalid_check_result"}
		if not bool((result as Dictionary).get("ok", false)):
			var out: Dictionary = (result as Dictionary).duplicate(true)
			out["suite"] = "game_state_shape"
			return out
	return {"ok": true}

func _check_valid_two_players() -> Dictionary:
	var gs := {"players": [{"id": "p1"}, {"id": "p2"}], "phase": "round_start"}
	var r: Dictionary = RuleContractScript.validate_game_state_shape(gs)
	if not bool(r.get("ok", false)):
		return {"ok": false, "reason": "valid_two_should_pass", "detail": r}
	return {"ok": true}

func _three_players() -> Array:
	return [{"id": "p1"}, {"id": "p2"}, {"id": "p3"}]

func _check_valid_three_players() -> Dictionary:
	var gs := {"players": _three_players(), "phase": "round_start"}
	var r: Dictionary = RuleContractScript.validate_game_state_shape(gs)
	if not bool(r.get("ok", false)):
		return {"ok": false, "reason": "valid_three_should_pass", "detail": r}
	return {"ok": true}

func _check_valid_four_players() -> Dictionary:
	var gs := {
		"players": [{"id": "p1"}, {"id": "p2"}, {"id": "p3"}, {"id": "p4"}],
		"phase": "player_turns"
	}
	var r: Dictionary = RuleContractScript.validate_game_state_shape(gs)
	if not bool(r.get("ok", false)):
		return {"ok": false, "reason": "valid_four_should_pass", "detail": r}
	return {"ok": true}

func _check_invalid_players_not_array() -> Dictionary:
	var gs := {"players": "bad", "phase": "round_start"}
	var r: Dictionary = RuleContractScript.validate_game_state_shape(gs)
	if bool(r.get("ok", false)):
		return {"ok": false, "reason": "players_not_array_should_fail"}
	if str(r.get("reason", "")) != "players_not_array":
		return {"ok": false, "reason": "players_not_array_wrong_reason", "detail": r}
	return {"ok": true}

func _check_invalid_player_count_low() -> Dictionary:
	var gs := {"players": [{"id": "p1"}], "phase": "round_start"}
	var r: Dictionary = RuleContractScript.validate_game_state_shape(gs)
	if bool(r.get("ok", false)):
		return {"ok": false, "reason": "one_player_should_fail"}
	if str(r.get("reason", "")) != "players_count_out_of_standard_range":
		return {"ok": false, "reason": "one_player_wrong_reason", "detail": r}
	return {"ok": true}

func _check_invalid_player_count_high() -> Dictionary:
	var p: Array = []
	for i in range(5):
		p.append({"id": "p%d" % (i + 1)})
	var gs := {"players": p, "phase": "round_start"}
	var r: Dictionary = RuleContractScript.validate_game_state_shape(gs)
	if bool(r.get("ok", false)):
		return {"ok": false, "reason": "five_players_should_fail"}
	return {"ok": true}

func _check_invalid_empty_phase() -> Dictionary:
	var gs := {"players": _three_players(), "phase": ""}
	var r: Dictionary = RuleContractScript.validate_game_state_shape(gs)
	if bool(r.get("ok", false)):
		return {"ok": false, "reason": "empty_phase_should_fail"}
	if str(r.get("reason", "")) != "missing_phase":
		return {"ok": false, "reason": "empty_phase_wrong_reason", "detail": r}
	return {"ok": true}
