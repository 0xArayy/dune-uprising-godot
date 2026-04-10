extends RefCounted

const ConflictRewardsServiceScript = preload("res://scripts/domain/services/conflict_rewards_service.gd")

func run_all_checks() -> Dictionary:
	var svc: ConflictRewardsService = ConflictRewardsServiceScript.new()
	var callbacks := {
		"append_log": Callable(self, "_noop_append_log"),
		"find_player_by_id": Callable(self, "_find_player_stub"),
		"sync_pending_interactions": Callable(self, "_noop_sync"),
		"queue_contract_choice": Callable(self, "_noop_queue_contract"),
		"normalize_trash_allowed_zones": Callable(self, "_noop_zones"),
		"get_player_spy_post_ids": Callable(self, "_noop_spy_posts"),
		"recall_spy": Callable(self, "_noop_recall")
	}
	var checks: Array = [
		_check_vp_doubled_with_multiplier(svc, callbacks),
		_check_gain_control_ignores_multiplier(svc, callbacks)
	]
	for result in checks:
		if typeof(result) != TYPE_DICTIONARY:
			return {"ok": false, "reason": "conflict_rewards_invalid_check_result"}
		if not bool((result as Dictionary).get("ok", false)):
			var tagged: Dictionary = (result as Dictionary).duplicate(true)
			tagged["suite"] = "conflict_rewards"
			return tagged
	return {"ok": true}

func _noop_append_log(_gs: Dictionary, _entry: Dictionary) -> void:
	pass

func _noop_sync(_player: Dictionary) -> void:
	pass

func _noop_queue_contract(_gs: Dictionary, _player: Dictionary, _amount: int, _fallback: Array, _a: Callable, _b: Callable) -> void:
	pass

func _noop_zones(_from: Variant) -> Array:
	return []

func _noop_spy_posts(_gs: Dictionary, _pid: String) -> Array:
	return []

func _noop_recall(_gs: Dictionary, _pid: String, _post: String) -> Dictionary:
	return {"ok": false}

func _find_player_stub(game_state: Dictionary, player_id: String) -> Dictionary:
	for p in game_state.get("players", []):
		if typeof(p) == TYPE_DICTIONARY and str(p.get("id", "")) == player_id:
			return p
	return {}

func _check_vp_doubled_with_multiplier(svc, callbacks: Dictionary) -> Dictionary:
	var player := {"id": "p1", "vp": 0, "resources": {"spice": 0, "solari": 0, "water": 0}}
	var game_state := {"players": [player], "controlBySpace": {}, "phase": "conflict", "log": []}
	svc.apply_reward({"type": "vp", "amount": 1}, player, game_state, 2, callbacks)
	if int(player.get("vp", 0)) != 2:
		return {"ok": false, "reason": "vp_multiplier_not_applied", "vp": player.get("vp")}
	return {"ok": true}

func _check_gain_control_ignores_multiplier(svc, callbacks: Dictionary) -> Dictionary:
	var player := {"id": "p1", "vp": 5, "resources": {"spice": 0, "solari": 0, "water": 0}}
	var game_state := {
		"players": [player],
		"controlBySpace": {"arrakeen": ""},
		"phase": "conflict",
		"log": []
	}
	svc.apply_reward({"type": "gain_control", "boardSpaceId": "arrakeen"}, player, game_state, 2, callbacks)
	var ctrl: Dictionary = game_state.get("controlBySpace", {})
	if str(ctrl.get("arrakeen", "")) != "p1":
		return {"ok": false, "reason": "gain_control_not_set"}
	if int(player.get("vp", 0)) != 5:
		return {"ok": false, "reason": "gain_control_should_not_double_vp"}
	return {"ok": true}
