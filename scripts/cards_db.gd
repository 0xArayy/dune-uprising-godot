extends Node
class_name CardsDb

static func load_cards_by_id(path: String = "res://data/cards_uprising.json") -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("CardsDb: failed to open %s" % path)
		return {}

	var text := file.get_as_text()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("CardsDb: expected array in %s" % path)
		return {}

	var by_id := {}
	for card in parsed:
		if typeof(card) != TYPE_DICTIONARY:
			continue
		var normalized_card: Dictionary = _normalize_card_from_raw(card)
		var card_id := str(card.get("id", ""))
		if card_id == "":
			push_warning("CardsDb: card without id skipped")
			continue
		if not _is_valid_card_def(normalized_card):
			push_warning("CardsDb: invalid card schema for id=%s" % card_id)
			continue
		by_id[card_id] = normalized_card
	return by_id

static func _is_valid_card_def(card: Dictionary) -> bool:
	if not card.has("name") or not card.has("agentIcons"):
		return false
	if typeof(card.get("agentIcons", [])) != TYPE_ARRAY:
		return false
	if typeof(card.get("agentEffect", [])) != TYPE_ARRAY:
		return false
	if typeof(card.get("revealEffect", [])) != TYPE_ARRAY:
		return false
	if typeof(card.get("purchaseBonus", [])) != TYPE_ARRAY:
		return false
	return true

static func _normalize_card_from_raw(card: Dictionary) -> Dictionary:
	var normalized: Dictionary = card.duplicate(true)
	var card_id := str(normalized.get("id", ""))
	match card_id:
		"imperium_bene_gesserit_operative":
			normalized["revealEffect"] = [
				{"type": "gain_persuasion", "amount": 1},
				{
					"type": "if",
					"requirement": {"type": "has_spies_at_least", "value": 2},
					"then": [{"type": "gain_persuasion", "amount": 2}],
					"else": []
				}
			]
		"imperium_shishakli":
			normalized["agentEffect"] = [
				{
					"type": "choice",
					"options": [
						{
							"label": "trash 1 card -> draw 1 card",
							"effects": [
								{"type": "trash_card", "from": ["hand", "discard", "inPlay"], "amount": 1},
								{"type": "draw_cards", "amount": 1}
							]
						}
					]
				}
			]
			normalized["revealEffect"] = [
				{"type": "gain_sword", "amount": 2},
				{
					"type": "if",
					"requirement": {"type": "has_fremen_bond", "value": true},
					"then": [{"type": "gain_influence", "faction": "fremen", "amount": 1}],
					"else": []
				}
			]
		"imperium_sardaukar_coordination":
			normalized["revealEffect"] = [
				{"type": "gain_persuasion", "amount": 2},
				{"type": "gain_sword_per_revealed_tag", "tag": "emperor", "amount": 1, "include_this_card": true}
			]
		"imperium_interstellar_trade":
			normalized["revealEffect"] = [
				{"type": "gain_persuasion_per_completed_contract", "amount": 1}
			]
		"imperium_cargo_runner":
			normalized["agentEffect"] = [
				{
					"type": "if",
					"requirement": {"type": "completed_contracts_at_least", "value": 2},
					"then": [{"type": "draw_cards", "amount": 1}],
					"else": []
				},
				{
					"type": "if",
					"requirement": {"type": "completed_contracts_at_least", "value": 4},
					"then": [{"type": "draw_cards", "amount": 1}],
					"else": []
				}
			]
		"imperium_weirding_woman":
			normalized["agentEffect"] = [
				{
					"type": "if",
					"requirement": {"type": "has_another_card_in_play_tag", "tag": "beneGesserit", "value": true},
					"then": [{"type": "return_this_card_to_hand", "amount": 1}],
					"else": []
				}
			]
		"imperium_subversive_advisor":
			normalized["agentEffect"] = [
				{
					"type": "if",
					"requirement": {"type": "sent_agent_to_faction_space_this_turn", "value": true},
					"then": [
						{"type": "gain_influence", "faction": "anyone", "amount": 2},
						{"type": "trash_this_card", "amount": 1}
					],
					"else": [{"type": "gain_influence", "faction": "anyone", "amount": 1}]
				}
			]
		"imperium_leadership":
			normalized["agentEffect"] = [
				{"type": "draw_cards_per_sandworm_in_conflict", "amount": 1}
			]
		"imperium_undercover_asset":
			normalized["revealEffect"] = [
				{
					"type": "choice",
					"options": [
						{
							"label": "gain 1 spy",
							"effects": [{"type": "place_spy", "amount": 1}]
						},
						{
							"label": "gain 2 swords",
							"effects": [{"type": "gain_sword", "amount": 2}]
						}
					]
				}
			]
		"imperium_sardaukar_soldier":
			normalized["purchaseBonus"] = []
		"imperium_desert_survival":
			normalized["agentEffect"] = [
				{"type": "trash_card", "from": ["hand", "discard", "inPlay"], "amount": 1}
			]
		"imperium_calculus_of_power":
			normalized["agentEffect"] = [
				{"type": "trash_card", "from": ["hand", "discard", "inPlay"], "amount": 1}
			]
		"imperium_tread_in_darkness":
			normalized["agentEffect"] = [
				{
					"type": "if",
					"requirement": {"type": "has_another_card_in_play_tag", "tag": "beneGesserit", "value": true},
					"then": [
						{
							"type": "choice",
							"options": [
								{
									"label": "trash 1 card -> draw 1 card",
									"effects": [
										{"type": "trash_card", "from": ["hand", "discard", "inPlay"], "amount": 1},
										{"type": "draw_cards", "amount": 1}
									]
								}
							]
						}
					],
					"else": []
				}
			]
		"imperium_spacing_guild_s_favor":
			normalized["onDiscardEffects"] = [
				{"type": "gain_resource", "resource": "spice", "amount": 2}
			]
		"imperium_covert_operation":
			normalized["agentEffect"] = [
				{"type": "opponents_discard_card", "amount": 1}
			]
		"imperium_wheels_within_wheels":
			normalized["agentEffect"] = [
				{
					"type": "if",
					"requirement": {"type": "min_influence", "faction": "emperor", "value": 2},
					"then": [{"type": "gain_resource", "resource": "solari", "amount": 2}],
					"else": []
				},
				{
					"type": "if",
					"requirement": {"type": "min_influence", "faction": "guild", "value": 2},
					"then": [{"type": "gain_resource", "resource": "spice", "amount": 1}],
					"else": []
				}
			]
		"imperium_guild_envoy":
			normalized["agentEffect"] = [
				{"type": "discard_card", "from": "hand", "amount": 1},
				{
					"type": "if",
					"requirement": {"type": "discarded_card_has_tag", "tag": "guild", "value": true},
					"then": [{"type": "draw_cards", "amount": 2}],
					"else": []
				}
			]
		"imperium_paracompass":
			normalized["revealEffect"] = [
				{
					"type": "if",
					"requirement": {"type": "flag", "key": "has_high_council_seat", "value": true},
					"then": [
						{"type": "gain_persuasion", "amount": 2},
						{
							"type": "if",
							"requirement": {"type": "has_swordmaster", "value": true},
							"then": [{"type": "gain_persuasion", "amount": 1}],
							"else": []
						}
					],
					"else": []
				}
			]
		"imperium_chani_clever_tactician":
			normalized["agentEffect"] = [
				{
					"type": "if",
					"requirement": {"type": "units_in_conflict_at_least", "value": 3},
					"then": [{"type": "draw_intrigue", "amount": 1}],
					"else": []
				}
			]
			normalized["revealEffect"] = [
				{
					"type": "choice",
					"options": [
						{"label": "do not retreat troops", "effects": []},
						{
							"label": "retreat 2 troops -> gain 4 swords",
							"effects": [
								{"type": "retreat_from_conflict", "amount": 2},
								{"type": "gain_sword", "amount": 4}
							]
						}
					]
				},
				{
					"type": "if",
					"requirement": {"type": "has_fremen_bond", "value": true},
					"then": [{"type": "gain_persuasion", "amount": 2}],
					"else": []
				}
			]
		"imperium_spy_network":
			normalized["revealEffect"] = [
				{"type": "gain_persuasion", "amount": 2},
				{"type": "gain_sword", "amount": 1},
				{
					"type": "if",
					"requirement": {"type": "has_spies_at_least", "value": 2},
					"then": [
						{
							"type": "choice",
							"options": [
								{"label": "do not recall spy", "effects": []},
								{
									"label": "recall a spy -> draw 1 intrigue",
									"effects": [
										{
											"type": "recall_spy_for_effect",
											"amount": 1,
											"rewardEffects": [{"type": "draw_intrigue", "amount": 1}]
										}
									]
								}
							]
						}
					],
					"else": []
				}
			]
		"imperium_stilgar_the_devoted":
			normalized["revealEffect"] = [
				{"type": "gain_persuasion_per_revealed_tag", "tag": "fremen", "amount": 2, "include_this_card": true}
			]
		"imperium_price_is_no_object":
			normalized["purchaseBonus"] = [{"type": "gain_resource", "resource": "solari", "amount": 2}]
	return normalized

