extends RefCounted

const CardsDbScript = preload("res://scripts/cards_db.gd")
const EffectTextTokensScript = preload("res://scripts/domain/effect_text_tokens.gd")
const CardEffectPresentationScript = preload("res://scripts/domain/card_effect_presentation.gd")

func run_all_checks() -> Dictionary:
	var checks: Array = [
		_check_alliance_requirement_tokenized(),
		_check_influence_choice_set_tokenized(),
		_check_overrides_loaded_from_json(),
		_check_presentation_counts_include_guaranteed_values()
	]
	for result in checks:
		if typeof(result) != TYPE_DICTIONARY:
			return {"ok": false, "reason": "card_effect_presentation_invalid_check_result"}
		if not bool((result as Dictionary).get("ok", false)):
			var tagged: Dictionary = (result as Dictionary).duplicate(true)
			tagged["suite"] = "card_effect_presentation"
			return tagged
	return {"ok": true}

func _check_alliance_requirement_tokenized() -> Dictionary:
	var text := EffectTextTokensScript.effects_to_text_card_nested([
		{
			"type": "if",
			"requirement": {"type": "has_alliance", "faction": "fremen"},
			"then": [{"type": "gain_sword", "amount": 2}],
			"else": []
		}
	])
	if text.find("[faction_icon:fremen] alliance") < 0:
		return {"ok": false, "reason": "has_alliance_not_tokenized", "text": text}
	return {"ok": true}

func _check_influence_choice_set_tokenized() -> Dictionary:
	var text := EffectTextTokensScript.effects_to_text_card_nested([
		{
			"type": "choice",
			"options": [
				{"effects": [{"type": "gain_influence", "faction": "emperor", "amount": 1}]},
				{"effects": [{"type": "gain_influence", "faction": "guild", "amount": 1}]},
				{"effects": [{"type": "gain_influence", "faction": "fremen", "amount": 1}]}
			]
		}
	])
	if text.find("[influence_choice_set:") < 0:
		return {"ok": false, "reason": "influence_choice_set_missing", "text": text}
	return {"ok": true}

func _check_overrides_loaded_from_json() -> Dictionary:
	var cards: Dictionary = CardsDbScript.load_cards_by_id()
	var shishakli_raw: Variant = cards.get("imperium_shishakli", {})
	if typeof(shishakli_raw) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "cards_db_missing_shishakli"}
	var shishakli: Dictionary = shishakli_raw
	var reveal_effect: Variant = shishakli.get("revealEffect", [])
	if typeof(reveal_effect) != TYPE_ARRAY or (reveal_effect as Array).is_empty():
		return {"ok": false, "reason": "cards_db_override_reveal_missing"}
	return {"ok": true}

func _check_presentation_counts_include_guaranteed_values() -> Dictionary:
	var presentation := CardEffectPresentationScript.build([
		{"type": "gain_sword", "amount": 2},
		{
			"type": "choice",
			"options": [
				{"effects": [{"type": "gain_resource", "resource": "solari", "amount": 2}]},
				{"effects": [{"type": "gain_resource", "resource": "spice", "amount": 1}]}
			]
		}
	])
	var guaranteed: Dictionary = presentation.get("guaranteed", {})
	var potential: Dictionary = presentation.get("potential", {})
	if int(guaranteed.get("sword", 0)) != 2:
		return {"ok": false, "reason": "presentation_guaranteed_sword_mismatch", "value": guaranteed.get("sword", 0)}
	var potential_resources: Dictionary = potential.get("resources", {})
	if int(potential_resources.get("solari", 0)) < 2:
		return {"ok": false, "reason": "presentation_potential_solari_missing", "value": potential_resources.get("solari", 0)}
	return {"ok": true}
