extends RefCounted
class_name CardEffectPresentation

const EffectDslScript = preload("res://scripts/domain/effect_dsl.gd")
const EffectTextTokensScript = preload("res://scripts/domain/effect_text_tokens.gd")

const TRACKED_RESOURCES := ["solari", "spice", "water"]
const TRACKED_FACTIONS := ["emperor", "guild", "beneGesserit", "fremen"]

static func build(effects: Variant) -> Dictionary:
	var normalized: Array = EffectDslScript.normalize_effects_with_aliases(effects)
	var guaranteed := _collect_totals(normalized, true)
	var potential := _collect_totals(normalized, false)
	var complexity := _count_complexity(normalized, 0)
	return {
		"normalized_effects": normalized,
		"guaranteed": guaranteed,
		"potential": potential,
		"complexity": complexity,
		"tokens_full": EffectTextTokensScript.effects_to_text_card_nested(normalized),
		"tokens_without_core_icons": EffectTextTokensScript.effects_to_text_card_with_skips(
			normalized,
			true, true, true, true, true, true, true, true, true, true, true, true, true, true
		)
	}

static func _empty_totals() -> Dictionary:
	var resources := {}
	for key in TRACKED_RESOURCES:
		resources[key] = 0
	var influence := {}
	for key in TRACKED_FACTIONS:
		influence[key] = 0
	return {
		"persuasion": 0,
		"troops": 0,
		"sword": 0,
		"draw_cards": 0,
		"draw_intrigue": 0,
		"trash_card": 0,
		"vp": 0,
		"get_contract": 0,
		"place_spy": 0,
		"summon_sandworm": 0,
		"resources": resources,
		"influence": influence
	}

static func _collect_totals(effects: Array, guaranteed_only: bool) -> Dictionary:
	var totals := _empty_totals()
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		var effect_type := str(effect.get("type", ""))
		match effect_type:
			"gain_persuasion":
				totals["persuasion"] = int(totals.get("persuasion", 0)) + int(effect.get("amount", 0))
			"recruit_troops":
				totals["troops"] = int(totals.get("troops", 0)) + int(effect.get("amount", 0))
			"gain_sword":
				totals["sword"] = int(totals.get("sword", 0)) + int(effect.get("amount", 0))
			"draw_cards":
				totals["draw_cards"] = int(totals.get("draw_cards", 0)) + int(effect.get("amount", 0))
			"draw_intrigue":
				totals["draw_intrigue"] = int(totals.get("draw_intrigue", 0)) + int(effect.get("amount", 0))
			"trash_card":
				totals["trash_card"] = int(totals.get("trash_card", 0)) + int(effect.get("amount", 0))
			"vp":
				totals["vp"] = int(totals.get("vp", 0)) + int(effect.get("amount", 0))
			"get_contract":
				totals["get_contract"] = int(totals.get("get_contract", 0)) + int(effect.get("amount", 0))
			"place_spy":
				totals["place_spy"] = int(totals.get("place_spy", 0)) + int(effect.get("amount", 0))
			"summon_sandworm":
				totals["summon_sandworm"] = int(totals.get("summon_sandworm", 0)) + int(effect.get("amount", 0))
			"gain_resource", "spend_resource":
				_merge_resource_effect(totals, effect)
			"gain_influence":
				_merge_influence_effect(totals, effect)
			"if":
				if guaranteed_only:
					continue
				var then_totals := _collect_totals(_to_effect_array(effect.get("then", [])), guaranteed_only)
				var else_totals := _collect_totals(_to_effect_array(effect.get("else", [])), guaranteed_only)
				_merge_totals(totals, then_totals)
				_merge_totals(totals, else_totals)
			"choice":
				if guaranteed_only:
					continue
				var options: Variant = effect.get("options", [])
				if typeof(options) != TYPE_ARRAY:
					continue
				for option in options:
					if typeof(option) != TYPE_DICTIONARY:
						continue
					_merge_totals(totals, _collect_totals(_to_effect_array((option as Dictionary).get("effects", [])), guaranteed_only))
			_:
				pass
	return totals

static func _merge_resource_effect(totals: Dictionary, effect: Dictionary) -> void:
	var resource_id := str(effect.get("resource", ""))
	var resources: Dictionary = totals.get("resources", {})
	if not resources.has(resource_id):
		return
	var amount := int(effect.get("amount", 0))
	if str(effect.get("type", "")) == "spend_resource":
		amount = -amount
	resources[resource_id] = int(resources.get(resource_id, 0)) + amount

static func _merge_influence_effect(totals: Dictionary, effect: Dictionary) -> void:
	var faction_id := str(effect.get("faction", ""))
	var influence: Dictionary = totals.get("influence", {})
	if not influence.has(faction_id):
		return
	influence[faction_id] = int(influence.get(faction_id, 0)) + int(effect.get("amount", 0))

static func _merge_totals(base: Dictionary, add: Dictionary) -> void:
	for key in ["persuasion", "troops", "sword", "draw_cards", "draw_intrigue", "trash_card", "vp", "get_contract", "place_spy", "summon_sandworm"]:
		base[key] = int(base.get(key, 0)) + int(add.get(key, 0))
	var base_resources: Dictionary = base.get("resources", {})
	var add_resources: Dictionary = add.get("resources", {})
	for resource_id in TRACKED_RESOURCES:
		base_resources[resource_id] = int(base_resources.get(resource_id, 0)) + int(add_resources.get(resource_id, 0))
	var base_influence: Dictionary = base.get("influence", {})
	var add_influence: Dictionary = add.get("influence", {})
	for faction_id in TRACKED_FACTIONS:
		base_influence[faction_id] = int(base_influence.get(faction_id, 0)) + int(add_influence.get(faction_id, 0))

static func _count_complexity(effects: Array, depth: int) -> Dictionary:
	var nodes := 0
	var branch_nodes := 0
	var max_depth := depth
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		nodes += 1
		var effect_type := str(effect.get("type", ""))
		if effect_type == "if":
			branch_nodes += 1
			var then_complexity := _count_complexity(_to_effect_array(effect.get("then", [])), depth + 1)
			var else_complexity := _count_complexity(_to_effect_array(effect.get("else", [])), depth + 1)
			nodes += int(then_complexity.get("nodes", 0)) + int(else_complexity.get("nodes", 0))
			branch_nodes += int(then_complexity.get("branch_nodes", 0)) + int(else_complexity.get("branch_nodes", 0))
			max_depth = maxi(max_depth, int(then_complexity.get("max_depth", depth)))
			max_depth = maxi(max_depth, int(else_complexity.get("max_depth", depth)))
		elif effect_type == "choice":
			branch_nodes += 1
			var options: Variant = effect.get("options", [])
			if typeof(options) != TYPE_ARRAY:
				continue
			for option in options:
				if typeof(option) != TYPE_DICTIONARY:
					continue
				var option_complexity := _count_complexity(_to_effect_array((option as Dictionary).get("effects", [])), depth + 1)
				nodes += int(option_complexity.get("nodes", 0))
				branch_nodes += int(option_complexity.get("branch_nodes", 0))
				max_depth = maxi(max_depth, int(option_complexity.get("max_depth", depth)))
	return {"nodes": nodes, "branch_nodes": branch_nodes, "max_depth": max_depth}

static func _to_effect_array(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return value
	return []
