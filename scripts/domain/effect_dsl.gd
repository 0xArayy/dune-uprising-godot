extends RefCounted
class_name EffectDsl

## Single source of truth for effect list duplication and JSON alias normalization
## (must match runtime interpretation in BoardMap.resolve_space_effects).

const ANY_INFLUENCE_FACTIONS: Array[String] = ["emperor", "guild", "beneGesserit", "fremen"]


static func duplicate_effects(effects: Variant) -> Array:
	if typeof(effects) == TYPE_ARRAY:
		return (effects as Array).duplicate(true)
	return []


static func normalize_effects_with_aliases(effects: Variant) -> Array:
	if typeof(effects) != TYPE_ARRAY:
		return []
	var normalized: Array = []
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			normalized.append(effect)
			continue
		normalized.append(normalize_effect_alias(effect))
	return normalized


static func normalize_effect_alias(effect: Dictionary) -> Dictionary:
	var normalized: Dictionary = effect.duplicate(true)
	var effect_type := str(normalized.get("type", ""))
	if effect_type == "resource":
		normalized["type"] = "gain_resource"
		return normalized
	if effect_type == "intrigue":
		normalized["type"] = "draw_intrigue"
		return normalized
	if effect_type == "contract":
		normalized["type"] = "get_contract"
		return normalized
	if effect_type == "deploy_recruited_to_conflict":
		normalized["type"] = "deploy_to_conflict"
		return normalized
	if effect_type == "fremen_bond_deploy_or_retreat":
		var amount := int(normalized.get("amount", 1))
		return {
			"type": "if",
			"requirement": {"type": "has_fremen_bond", "value": true},
			"then": [{
				"type": "choice",
				"options": [
					{
						"label": "deploy troop",
						"effects": [{"type": "deploy_to_conflict", "amount": amount}]
					},
					{
						"label": "retreat troop",
						"effects": [{"type": "retreat_from_conflict", "amount": amount}]
					}
				]
			}],
			"else": []
		}
	if effect_type == "gain_influence" and str(normalized.get("faction", "")) == "anyone":
		var amount := int(normalized.get("amount", 1))
		var options: Array = []
		for faction_id in ANY_INFLUENCE_FACTIONS:
			options.append({
				"label": "influence: %s" % faction_id,
				"effects": [{
					"type": "gain_influence",
					"faction": faction_id,
					"amount": amount
				}]
			})
		return {
			"type": "choice",
			"options": options
		}
	if effect_type == "choice":
		var options = normalized.get("options", [])
		if typeof(options) == TYPE_ARRAY:
			var normalized_options: Array = []
			for option in options:
				if typeof(option) != TYPE_DICTIONARY:
					normalized_options.append(option)
					continue
				var normalized_option: Dictionary = option.duplicate(true)
				normalized_option["effects"] = normalize_effects_with_aliases(option.get("effects", []))
				normalized_options.append(normalized_option)
			normalized["options"] = normalized_options
		return normalized
	if effect_type == "if":
		normalized["then"] = normalize_effects_with_aliases(normalized.get("then", []))
		normalized["else"] = normalize_effects_with_aliases(normalized.get("else", []))
	return normalized
