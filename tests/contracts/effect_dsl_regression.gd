extends RefCounted

const EffectDslScript = preload("res://scripts/domain/effect_dsl.gd")

func run_all_checks() -> Dictionary:
	var checks: Array = [
		_check_intrigue_alias(),
		_check_contract_alias(),
		_check_deploy_recruited_alias(),
		_check_fremen_bond_structure(),
		_check_gain_influence_anyone_becomes_choice(),
		_check_choice_nested_effects_normalized(),
		_check_if_else_branches()
	]
	for result in checks:
		if typeof(result) != TYPE_DICTIONARY:
			return {"ok": false, "reason": "effect_dsl_invalid_check_result"}
		if not bool((result as Dictionary).get("ok", false)):
			var tagged: Dictionary = (result as Dictionary).duplicate(true)
			tagged["suite"] = "effect_dsl"
			return tagged
	return {"ok": true}

func _check_intrigue_alias() -> Dictionary:
	var n: Dictionary = EffectDslScript.normalize_effect_alias({"type": "intrigue", "amount": 2})
	if str(n.get("type", "")) != "draw_intrigue":
		return {"ok": false, "reason": "effect_alias_intrigue_mismatch"}
	return {"ok": true}

func _check_contract_alias() -> Dictionary:
	var n: Dictionary = EffectDslScript.normalize_effect_alias({"type": "contract", "amount": 1})
	if str(n.get("type", "")) != "get_contract":
		return {"ok": false, "reason": "effect_alias_contract_mismatch"}
	return {"ok": true}

func _check_deploy_recruited_alias() -> Dictionary:
	var n: Dictionary = EffectDslScript.normalize_effect_alias({"type": "deploy_recruited_to_conflict", "amount": 2})
	if str(n.get("type", "")) != "deploy_to_conflict":
		return {"ok": false, "reason": "effect_alias_deploy_recruited_mismatch"}
	if int(n.get("amount", 0)) != 2:
		return {"ok": false, "reason": "effect_alias_deploy_amount_preserved"}
	return {"ok": true}

func _check_fremen_bond_structure() -> Dictionary:
	var n: Dictionary = EffectDslScript.normalize_effect_alias({"type": "fremen_bond_deploy_or_retreat", "amount": 1})
	if str(n.get("type", "")) != "if":
		return {"ok": false, "reason": "fremen_bond_not_if"}
	var then_arr: Variant = n.get("then", [])
	if typeof(then_arr) != TYPE_ARRAY or (then_arr as Array).is_empty():
		return {"ok": false, "reason": "fremen_bond_then_missing"}
	var inner: Dictionary = (then_arr as Array)[0]
	if str(inner.get("type", "")) != "choice":
		return {"ok": false, "reason": "fremen_bond_then_not_choice"}
	return {"ok": true}

func _check_gain_influence_anyone_becomes_choice() -> Dictionary:
	var n: Dictionary = EffectDslScript.normalize_effect_alias({"type": "gain_influence", "faction": "anyone", "amount": 1})
	if str(n.get("type", "")) != "choice":
		return {"ok": false, "reason": "gain_influence_anyone_not_choice"}
	var opts: Variant = n.get("options", [])
	if typeof(opts) != TYPE_ARRAY or (opts as Array).size() != 4:
		return {"ok": false, "reason": "gain_influence_anyone_options_count"}
	return {"ok": true}

func _check_choice_nested_effects_normalized() -> Dictionary:
	var arr: Array = EffectDslScript.normalize_effects_with_aliases([
		{
			"type": "choice",
			"options": [
				{"label": "a", "effects": [{"type": "resource", "resource": "spice", "amount": 1}]}
			]
		}
	])
	if arr.is_empty() or typeof(arr[0]) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "choice_nested_normalize_missing"}
	var ch: Dictionary = arr[0]
	var options: Variant = ch.get("options", [])
	if typeof(options) != TYPE_ARRAY or (options as Array).is_empty():
		return {"ok": false, "reason": "choice_nested_options_empty"}
	var first_opt: Dictionary = (options as Array)[0]
	var eff: Variant = first_opt.get("effects", [])
	if typeof(eff) != TYPE_ARRAY or (eff as Array).is_empty():
		return {"ok": false, "reason": "choice_nested_effects_empty"}
	var inner_eff: Dictionary = (eff as Array)[0]
	if str(inner_eff.get("type", "")) != "gain_resource":
		return {"ok": false, "reason": "choice_nested_inner_not_gain_resource"}
	return {"ok": true}

func _check_if_else_branches() -> Dictionary:
	var arr: Array = EffectDslScript.normalize_effects_with_aliases([
		{
			"type": "if",
			"requirement": {"type": "test"},
			"then": [{"type": "resource", "resource": "spice", "amount": 1}],
			"else": [{"type": "intrigue", "amount": 1}]
		}
	])
	if arr.is_empty():
		return {"ok": false, "reason": "if_else_normalize_missing"}
	var if_dict: Dictionary = arr[0]
	var else_arr: Variant = if_dict.get("else", [])
	if typeof(else_arr) != TYPE_ARRAY or (else_arr as Array).is_empty():
		return {"ok": false, "reason": "if_else_branch_empty"}
	var else_inner: Dictionary = (else_arr as Array)[0]
	if str(else_inner.get("type", "")) != "draw_intrigue":
		return {"ok": false, "reason": "if_else_alias_not_applied"}
	return {"ok": true}
