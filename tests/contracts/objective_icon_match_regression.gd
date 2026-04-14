extends RefCounted

const ObjectiveResolutionServiceScript = preload("res://scripts/domain/services/objective_resolution_service.gd")
const TurnControllerScript = preload("res://scripts/turn_controller.gd")

func run_all_checks() -> Dictionary:
	var checks: Array = [
		_check_objective_match_grants_vp_once(),
		_check_wild_icon_matches_any_face_up_target(),
		_check_no_match_when_no_face_up_pair(),
		_check_no_resolution_when_won_card_is_face_down(),
		_check_tie_conflict_does_not_claim_or_match()
	]
	for result in checks:
		if typeof(result) != TYPE_DICTIONARY:
			return {"ok": false, "reason": "objective_icon_invalid_check_result"}
		if not bool((result as Dictionary).get("ok", false)):
			var tagged: Dictionary = (result as Dictionary).duplicate(true)
			tagged["suite"] = "objective_icon_match"
			return tagged
	return {"ok": true}

func _check_objective_match_grants_vp_once() -> Dictionary:
	var svc = ObjectiveResolutionServiceScript.new()
	var player := {
		"id": "p1",
		"vp": 0,
		"objectiveCards": [{"id": "obj1", "battleIcon": "crysknife", "faceUp": true}],
		"wonConflictCards": []
	}
	var game_state := {"log": []}
	svc.register_won_conflict_card(player, "conflict_a", "crysknife")
	var first_result: Dictionary = svc.try_resolve_battle_icon_match(player, game_state, "conflict_a")
	if not bool(first_result.get("matched", false)):
		return {"ok": false, "reason": "expected_initial_match"}
	if int(player.get("vp", 0)) != 1:
		return {"ok": false, "reason": "vp_not_granted_once", "vp": int(player.get("vp", 0))}
	var second_result: Dictionary = svc.try_resolve_battle_icon_match(player, game_state, "conflict_a")
	if bool(second_result.get("matched", false)):
		return {"ok": false, "reason": "face_down_card_should_not_match_again"}
	if int(player.get("vp", 0)) != 1:
		return {"ok": false, "reason": "vp_double_counted", "vp": int(player.get("vp", 0))}
	return {"ok": true}

func _check_wild_icon_matches_any_face_up_target() -> Dictionary:
	var svc = ObjectiveResolutionServiceScript.new()
	var player := {
		"id": "p1",
		"vp": 0,
		"objectiveCards": [{"id": "obj_wild", "battleIcon": "wild", "faceUp": true}],
		"wonConflictCards": []
	}
	var game_state := {"log": []}
	svc.register_won_conflict_card(player, "conflict_b", "desert_mouse")
	var result: Dictionary = svc.try_resolve_battle_icon_match(player, game_state, "conflict_b")
	if not bool(result.get("matched", false)):
		return {"ok": false, "reason": "wild_should_match_any_icon"}
	if int(player.get("vp", 0)) != 1:
		return {"ok": false, "reason": "wild_match_vp_not_granted"}
	return {"ok": true}

func _check_no_match_when_no_face_up_pair() -> Dictionary:
	var svc = ObjectiveResolutionServiceScript.new()
	var player := {
		"id": "p1",
		"vp": 0,
		"objectiveCards": [{"id": "obj1", "battleIcon": "ornithopter", "faceUp": true}],
		"wonConflictCards": []
	}
	var game_state := {"log": []}
	svc.register_won_conflict_card(player, "conflict_c", "crysknife")
	var result: Dictionary = svc.try_resolve_battle_icon_match(player, game_state, "conflict_c")
	if bool(result.get("matched", false)):
		return {"ok": false, "reason": "unexpected_match_without_pair"}
	if int(player.get("vp", 0)) != 0:
		return {"ok": false, "reason": "vp_changed_without_match"}
	return {"ok": true}

func _check_no_resolution_when_won_card_is_face_down() -> Dictionary:
	var svc = ObjectiveResolutionServiceScript.new()
	var player := {
		"id": "p1",
		"vp": 0,
		"objectiveCards": [{"id": "obj1", "battleIcon": "crysknife", "faceUp": true}],
		"wonConflictCards": [{"id": "conflict_d", "battleIcon": "crysknife", "faceUp": false}]
	}
	var game_state := {"log": []}
	var result: Dictionary = svc.try_resolve_battle_icon_match(player, game_state, "conflict_d")
	if bool(result.get("matched", false)):
		return {"ok": false, "reason": "face_down_won_card_should_not_match"}
	if int(player.get("vp", 0)) != 0:
		return {"ok": false, "reason": "vp_changed_for_face_down_won_card"}
	return {"ok": true}

func _check_tie_conflict_does_not_claim_or_match() -> Dictionary:
	var controller = TurnControllerScript.new()
	var p1 := {
		"id": "p1",
		"vp": 0,
		"resources": {"spice": 0, "solari": 0, "water": 0},
		"objectiveCards": [{"id": "obj1", "battleIcon": "crysknife", "faceUp": true}],
		"wonConflictCards": [],
		"revealedSwordPower": 0,
		"garrisonTroops": 0,
		"sandwormsInConflict": 0
	}
	var p2 := {
		"id": "p2",
		"vp": 0,
		"resources": {"spice": 0, "solari": 0, "water": 0},
		"objectiveCards": [{"id": "obj2", "battleIcon": "crysknife", "faceUp": true}],
		"wonConflictCards": [],
		"revealedSwordPower": 0,
		"garrisonTroops": 0,
		"sandwormsInConflict": 0
	}
	var game_state := {
		"phase": "conflict",
		"players": [p1, p2],
		"activeConflictCardId": "conflict_tie",
		"activeConflictCardDef": {
			"firstReward": [],
			"secondReward": [],
			"thirdReward": [],
			"battleIcons": ["crysknife"]
		},
		"conflictZone": {
			"p1": {"troops": 1, "sandworms": 0, "revealedSwordPower": 0},
			"p2": {"troops": 1, "sandworms": 0, "revealedSwordPower": 0}
		},
		"combatIntrigueRound": {"status": "done"},
		"log": []
	}
	var result: Dictionary = controller.resolve_conflict(game_state)
	if not bool(result.get("ok", false)):
		controller.free()
		return {"ok": false, "reason": "tie_conflict_should_resolve", "detail": result}
	if int(p1.get("vp", 0)) != 0 or int(p2.get("vp", 0)) != 0:
		controller.free()
		return {"ok": false, "reason": "tie_conflict_should_not_award_objective_vp"}
	if (p1.get("wonConflictCards", []) as Array).size() != 0:
		controller.free()
		return {"ok": false, "reason": "tie_conflict_should_not_claim_card"}
	controller.free()
	return {"ok": true}
