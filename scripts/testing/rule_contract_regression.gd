extends RefCounted
class_name RuleContractRegression

const RuleContractScript = preload("res://scripts/domain/rule_contract.gd")
const EffectDslScript = preload("res://scripts/domain/effect_dsl.gd")
const GameConstantsScript = preload("res://scripts/domain/game_constants.gd")

func run_all_checks() -> Dictionary:
	var checks: Array = [
		_check_phase_flow_contract(),
		_check_phase_constants_alignment(),
		_check_combat_power_formula(),
		_check_tie_break_order(),
		_check_tie_break_chain_solari_after_spice(),
		_check_tie_break_chain_water_after_solari(),
		_check_tie_break_chain_garrison_after_water(),
		_check_tie_break_chain_reveal_after_garrison(),
		_check_effect_alias_resource(),
		_check_nested_alias_normalization(),
		_check_no_units_zero_power(),
		_check_pending_slots_contract(),
		_check_resource_constants_contract(),
		_check_default_player_ids_contract()
	]
	for result in checks:
		if typeof(result) != TYPE_DICTIONARY:
			return {"ok": false, "reason": "invalid_check_result"}
		if not bool((result as Dictionary).get("ok", false)):
			return result
	return {"ok": true}

func run_minimal_checks() -> Dictionary:
	return run_all_checks()

func _check_phase_flow_contract() -> Dictionary:
	if RuleContractScript.REQUIRED_PHASE_FLOW.size() != 5:
		return {"ok": false, "reason": "phase_flow_size_mismatch"}
	var expected := PackedStringArray(["round_start", "player_turns", "conflict", "makers", "recall"])
	for i in range(expected.size()):
		if str(RuleContractScript.REQUIRED_PHASE_FLOW[i]) != str(expected[i]):
			return {
				"ok": false,
				"reason": "phase_flow_order_mismatch",
				"expected": expected,
				"actual": RuleContractScript.REQUIRED_PHASE_FLOW
			}
	return {"ok": true}

func _check_combat_power_formula() -> Dictionary:
	var sample_zone := {"troops": 2, "sandworms": 1, "revealedSwordPower": 3}
	var power := RuleContractScript.compute_combat_power(sample_zone)
	if power != 10:
		return {"ok": false, "reason": "combat_power_formula_broken", "value": power}
	var swords_only_zone := {"troops": 0, "sandworms": 2, "revealedSwordPower": 4}
	var swords_only_power := RuleContractScript.compute_combat_power(swords_only_zone)
	if swords_only_power != 10:
		return {"ok": false, "reason": "combat_power_sandworm_formula_broken", "value": swords_only_power}
	return {"ok": true}

func _check_tie_break_order() -> Dictionary:
	var a := {
		"vp": 10,
		"resources": {"spice": 3, "solari": 1, "water": 0},
		"garrisonTroops": 2,
		"lastRevealOrder": 2
	}
	var b := {
		"vp": 10,
		"resources": {"spice": 2, "solari": 9, "water": 9},
		"garrisonTroops": 9,
		"lastRevealOrder": 9
	}
	var cmp := RuleContractScript.compare_players_for_endgame(a, b)
	if cmp <= 0:
		return {"ok": false, "reason": "tie_break_order_broken", "value": cmp}
	return {"ok": true}

func _check_tie_break_chain_solari_after_spice() -> Dictionary:
	var a := {
		"vp": 8,
		"resources": {"spice": 3, "solari": 4, "water": 0},
		"garrisonTroops": 0,
		"lastRevealOrder": 0
	}
	var b := {
		"vp": 8,
		"resources": {"spice": 3, "solari": 2, "water": 9},
		"garrisonTroops": 9,
		"lastRevealOrder": 9
	}
	var cmp := RuleContractScript.compare_players_for_endgame(a, b)
	if cmp <= 0:
		return {"ok": false, "reason": "tie_break_solari_after_spice_broken", "value": cmp}
	return {"ok": true}

func _check_tie_break_chain_water_after_solari() -> Dictionary:
	var a := {
		"vp": 8,
		"resources": {"spice": 3, "solari": 2, "water": 2},
		"garrisonTroops": 1,
		"lastRevealOrder": 9
	}
	var b := {
		"vp": 8,
		"resources": {"spice": 3, "solari": 2, "water": 1},
		"garrisonTroops": 9,
		"lastRevealOrder": 9
	}
	var cmp := RuleContractScript.compare_players_for_endgame(a, b)
	if cmp <= 0:
		return {"ok": false, "reason": "tie_break_water_after_solari_broken", "value": cmp}
	return {"ok": true}

func _check_tie_break_chain_garrison_after_water() -> Dictionary:
	var a := {
		"vp": 8,
		"resources": {"spice": 3, "solari": 2, "water": 1},
		"garrisonTroops": 3,
		"lastRevealOrder": 0
	}
	var b := {
		"vp": 8,
		"resources": {"spice": 3, "solari": 2, "water": 1},
		"garrisonTroops": 2,
		"lastRevealOrder": 9
	}
	var cmp := RuleContractScript.compare_players_for_endgame(a, b)
	if cmp <= 0:
		return {"ok": false, "reason": "tie_break_garrison_after_water_broken", "value": cmp}
	return {"ok": true}

func _check_tie_break_chain_reveal_after_garrison() -> Dictionary:
	var a := {
		"vp": 8,
		"resources": {"spice": 3, "solari": 2, "water": 1},
		"garrisonTroops": 3,
		"lastRevealOrder": 4
	}
	var b := {
		"vp": 8,
		"resources": {"spice": 3, "solari": 2, "water": 1},
		"garrisonTroops": 3,
		"lastRevealOrder": 2
	}
	var cmp := RuleContractScript.compare_players_for_endgame(a, b)
	if cmp <= 0:
		return {"ok": false, "reason": "tie_break_reveal_after_garrison_broken", "value": cmp}
	return {"ok": true}

func _check_effect_alias_resource() -> Dictionary:
	var alias_norm: Dictionary = EffectDslScript.normalize_effect_alias({"type": "resource", "resource": "spice", "amount": 2})
	if str(alias_norm.get("type", "")) != "gain_resource":
		return {"ok": false, "reason": "effect_alias_resource_mismatch"}
	return {"ok": true}

func _check_nested_alias_normalization() -> Dictionary:
	var nested: Array = EffectDslScript.normalize_effects_with_aliases([
		{"type": "if", "then": [{"type": "resource", "resource": "water", "amount": 1}], "else": []}
	])
	if nested.is_empty() or typeof(nested[0]) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "effect_nested_normalize_failed"}
	var if_dict: Dictionary = nested[0]
	var then_arr: Variant = if_dict.get("then", [])
	if typeof(then_arr) != TYPE_ARRAY or (then_arr as Array).is_empty():
		return {"ok": false, "reason": "effect_nested_then_empty"}
	var inner: Dictionary = (then_arr as Array)[0]
	if str(inner.get("type", "")) != "gain_resource":
		return {"ok": false, "reason": "effect_nested_alias_not_applied"}
	return {"ok": true}

func _check_no_units_zero_power() -> Dictionary:
	var sword_only := {"troops": 0, "sandworms": 0, "revealedSwordPower": 9}
	var power := RuleContractScript.compute_combat_power(sword_only)
	if power != 0:
		return {"ok": false, "reason": "zero_units_must_have_zero_power", "value": power}
	return {"ok": true}

func _check_phase_constants_alignment() -> Dictionary:
	var expected := PackedStringArray(["round_start", "player_turns", "conflict", "makers", "recall"])
	var constants := PackedStringArray([
		GameConstantsScript.PHASE_ROUND_START,
		GameConstantsScript.PHASE_PLAYER_TURNS,
		GameConstantsScript.PHASE_CONFLICT,
		GameConstantsScript.PHASE_MAKERS,
		GameConstantsScript.PHASE_RECALL
	])
	if constants != expected:
		return {
			"ok": false,
			"reason": "phase_constants_mismatch",
			"expected": expected,
			"actual": constants
		}
	return {"ok": true}

func _check_pending_slots_contract() -> Dictionary:
	if int(GameConstantsScript.PENDING_SLOT_CONFLICT_COST) <= 0:
		return {"ok": false, "reason": "pending_slot_conflict_cost_invalid"}
	if int(GameConstantsScript.PENDING_SLOT_CONFLICT_INFLUENCE) <= 0:
		return {"ok": false, "reason": "pending_slot_conflict_influence_invalid"}
	if int(GameConstantsScript.PENDING_SLOT_CARD_EFFECT) <= 0:
		return {"ok": false, "reason": "pending_slot_card_effect_invalid"}
	if int(GameConstantsScript.PENDING_SLOT_CONTRACT) <= 0:
		return {"ok": false, "reason": "pending_slot_contract_invalid"}
	return {"ok": true}

func _check_resource_constants_contract() -> Dictionary:
	var resources := PackedStringArray([
		GameConstantsScript.RESOURCE_SPICE,
		GameConstantsScript.RESOURCE_SOLARI,
		GameConstantsScript.RESOURCE_WATER
	])
	var expected := PackedStringArray(["spice", "solari", "water"])
	if resources != expected:
		return {"ok": false, "reason": "resource_constants_mismatch", "actual": resources}
	return {"ok": true}

func _check_default_player_ids_contract() -> Dictionary:
	var expected := PackedStringArray(["p1", "p2", "p3", "p4"])
	if GameConstantsScript.DEFAULT_PLAYER_IDS != expected:
		return {
			"ok": false,
			"reason": "default_player_ids_mismatch",
			"actual": GameConstantsScript.DEFAULT_PLAYER_IDS
		}
	return {"ok": true}
