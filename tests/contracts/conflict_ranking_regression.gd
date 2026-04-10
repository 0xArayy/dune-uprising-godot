extends RefCounted

const ConflictResolutionRulesScript = preload("res://scripts/domain/conflict_resolution_rules.gd")

func run_all_checks() -> Dictionary:
	var rules := ConflictResolutionRulesScript.new()
	var checks: Array = [
		_check_ranking_distinct_powers(rules),
		_check_ranking_tie_first_place(rules),
		_check_ranking_all_tied(rules),
		_check_power_snapshots_participants(rules)
	]
	for result in checks:
		if typeof(result) != TYPE_DICTIONARY:
			return {"ok": false, "reason": "conflict_ranking_invalid_check_result"}
		if not bool((result as Dictionary).get("ok", false)):
			var tagged: Dictionary = (result as Dictionary).duplicate(true)
			tagged["suite"] = "conflict_ranking"
			return tagged
	return {"ok": true}

func _check_ranking_distinct_powers(rules) -> Dictionary:
	var groups: Array = rules.compute_ranking_groups({"p1": 6, "p2": 4, "p3": 2})
	if groups.size() != 3:
		return {"ok": false, "reason": "ranking_distinct_group_count", "groups": groups}
	if str((groups[0] as Array)[0]) != "p1":
		return {"ok": false, "reason": "ranking_distinct_first_wrong"}
	return {"ok": true}

func _check_ranking_tie_first_place(rules) -> Dictionary:
	var groups: Array = rules.compute_ranking_groups({"p1": 4, "p2": 4, "p3": 2})
	if groups.size() != 2:
		return {"ok": false, "reason": "ranking_tie_first_group_count", "groups": groups}
	var g0: Array = groups[0]
	if g0.size() != 2:
		return {"ok": false, "reason": "ranking_tie_first_size"}
	var g1: Array = groups[1]
	if g1.size() != 1 or str(g1[0]) != "p3":
		return {"ok": false, "reason": "ranking_tie_second_wrong"}
	return {"ok": true}

func _check_ranking_all_tied(rules) -> Dictionary:
	var groups: Array = rules.compute_ranking_groups({"p1": 2, "p2": 2})
	if groups.size() != 1:
		return {"ok": false, "reason": "ranking_all_tied_group_count"}
	if (groups[0] as Array).size() != 2:
		return {"ok": false, "reason": "ranking_all_tied_group_size"}
	return {"ok": true}

func _check_power_snapshots_participants(rules) -> Dictionary:
	var players: Array = [
		{"id": "p1"},
		{"id": "p2"},
		{"id": "p3"}
	]
	var conflict_zone := {
		"p1": {"troops": 1, "sandworms": 0, "revealedSwordPower": 0},
		"p2": {"troops": 0, "sandworms": 0, "revealedSwordPower": 5},
		"p3": {"troops": 0, "sandworms": 1, "revealedSwordPower": 0}
	}
	var snap: Dictionary = rules.build_power_snapshots(players, conflict_zone)
	var part: Dictionary = snap.get("participantPowerByPlayer", {})
	if not part.has("p1") or not part.has("p3"):
		return {"ok": false, "reason": "participant_power_missing_units"}
	if part.has("p2"):
		return {"ok": false, "reason": "participant_power_should_exclude_swords_only"}
	return {"ok": true}
