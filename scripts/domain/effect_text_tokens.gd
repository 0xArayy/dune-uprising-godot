extends RefCounted
## Single source for effect DSL token strings: board spaces vs card faces.
class_name EffectTextTokens

const EffectDslScript = preload("res://scripts/domain/effect_dsl.gd")


# --- Board / space markers (matches former BoardMap._*ToText) ---

static func repeat_token(token: String, amount: int) -> String:
	if amount <= 0:
		return ""
	var tokens: Array[String] = []
	for _i in range(amount):
		tokens.append(token)
	return " ".join(tokens)


static func is_faction_area(area_id: String) -> bool:
	return area_id == "emperor" or area_id == "guild" or area_id == "beneGesserit" or area_id == "fremen"


static func effects_to_text_board(effects: Variant, space_area_id: String = "") -> String:
	var normalized_effects: Array = EffectDslScript.normalize_effects_with_aliases(effects)
	if normalized_effects.is_empty():
		return ""
	var parts: Array[String] = []
	for effect in normalized_effects:
		var text := effect_to_text_board(effect, space_area_id)
		if text == "":
			continue
		parts.append(text)
	return "; ".join(parts)


static func effect_to_text_board(effect: Variant, space_area_id: String = "") -> String:
	if typeof(effect) != TYPE_DICTIONARY:
		return ""
	var effect_type := str(effect.get("type", ""))
	var amount := int(effect.get("amount", 0))
	match effect_type:
		"gain_resource":
			var resource_id := str(effect.get("resource", "resource"))
			if resource_id == "solari":
				return "[solari_badge:%d]" % amount
			if resource_id == "spice":
				return "[spice_badge:%d]" % amount
			if resource_id == "water":
				return "[water_badge:%d]" % amount
			return "+%d %s" % [amount, resource_id]
		"spend_resource":
			var spend_resource_id := str(effect.get("resource", "resource"))
			if spend_resource_id == "solari":
				return "[solari_badge:%d]" % (-amount)
			if spend_resource_id == "spice":
				return "[spice_badge:%d]" % (-amount)
			if spend_resource_id == "water":
				return "[water_badge:%d]" % (-amount)
			return "-%d %s" % [amount, spend_resource_id]
		"gain_persuasion":
			return "[persuasion_badge:%d]" % amount
		"gain_sword":
			return repeat_token("[sword_icon]", max(amount, 1))
		"draw_cards":
			return repeat_token("[draw_card_icon]", amount)
		"draw_intrigue":
			return repeat_token("[intrigue_icon]", amount)
		"recruit_troops":
			return "[troops_badge:%d]" % amount
		"gain_influence":
			var faction_id := str(effect.get("faction", ""))
			if amount == 1 and faction_id != "" and faction_id == space_area_id and is_faction_area(space_area_id):
				return ""
			if faction_id == "":
				return "[influence_icon]"
			return repeat_token("[faction_icon:%s]" % faction_id, max(amount, 1))
		"trash_card":
			return repeat_token("[trash_card_icon]", amount)
		"discard_card":
			return repeat_token("[trash_card_icon]", amount)
		"trash_intrigue":
			return repeat_token("[trash_card_icon]", max(amount, 1)) + " " + repeat_token("[intrigue_icon]", max(amount, 1))
		"lose_influence":
			return "[influence_icon] -%d" % max(amount, 1)
		"get_contract":
			return "[contract_icon]"
		"place_spy":
			return repeat_token("[spy_icon]", max(amount, 1))
		"recall_agent":
			return repeat_token("[recall_agent_icon]", max(amount, 1))
		"gain_agent":
			return repeat_token("[get_agent_icon]", max(amount, 1))
		"gain_maker_hooks":
			return repeat_token("[maker_hooks_icon]", max(amount, 1))
		"collect_maker_spice":
			return ""
		"summon_sandworm":
			return repeat_token("[sand_worm_icon]", max(amount, 1))
		"deploy_to_conflict":
			return "[troops_badge:%d]" % max(amount, 1)
		"retreat_from_conflict":
			return "[troops_badge:%d] retreat" % max(amount, 1)
		"fremen_bond_deploy_or_retreat":
			return "[troops_badge:%d]" % max(amount, 1)
		"vp":
			return repeat_token("[vp_icon]", max(amount, 1))
		"gain_persuasion_per_completed_contract":
			return "[persuasion_badge:1] per completed contract"
		"gain_persuasion_per_in_play_tag":
			return "[persuasion_badge:1] per in-play %s card" % str(effect.get("tag", ""))
		"gain_sword_per_revealed_tag":
			return "[sword_icon] per revealed %s card" % str(effect.get("tag", ""))
		"remove_shield_wall":
			return "remove shield wall"
		"set_flag":
			return "set %s=%s" % [str(effect.get("key", "")), str(effect.get("value", false))]
		"resource":
			var plain_resource_id := str(effect.get("resource", "resource"))
			if plain_resource_id == "solari":
				return "[solari_badge:%d]" % amount
			if plain_resource_id == "spice":
				return "[spice_badge:%d]" % amount
			if plain_resource_id == "water":
				return "[water_badge:%d]" % amount
			return "%d %s" % [amount, plain_resource_id]
		"choice":
			return choice_to_text_board(effect, space_area_id)
		"if":
			return if_to_text_board(effect, space_area_id)
		_:
			return effect_type


static func choice_to_text_board(effect: Dictionary, space_area_id: String = "") -> String:
	if is_influence_choice(effect):
		return "[influence_icon]"
	if is_spice_refinery_trade_choice(effect):
		return "[spice_refinery_trade]"
	if is_gather_support_trade_choice(effect):
		return "[gather_support_trade]"
	var sietch_choice := extract_sietch_tabr_choice(effect)
	if bool(sietch_choice.get("ok", false)):
		return "%s [sietch_tabr_second_option:%d:%d]" % [
			str(sietch_choice.get("first_tokens", "")),
			int(sietch_choice.get("second_water", 0)),
			int(sietch_choice.get("second_shield_wall", 0))
		]
	var maker_worm_choice := extract_maker_worm_choice(effect)
	if bool(maker_worm_choice.get("ok", false)):
		return "[maker_worm_choice:%d:%d]" % [
			int(maker_worm_choice.get("spice_amount", 0)),
			int(maker_worm_choice.get("worm_amount", 0))
		]
	var options = effect.get("options", [])
	if typeof(options) != TYPE_ARRAY or options.is_empty():
		return "choice"
	var option_parts: Array[String] = []
	for option in options:
		if typeof(option) != TYPE_DICTIONARY:
			continue
		var label := str(option.get("label", "")).strip_edges()
		var nested_effects = option.get("effects", [])
		var nested_text := effects_to_text_board(nested_effects, space_area_id)
		if nested_text == "":
			nested_text = label if label != "" else "option"
		elif label != "":
			nested_text = "%s: %s" % [label, nested_text]
		option_parts.append(nested_text)
	if option_parts.is_empty():
		return "choice"
	return "choice[%s]" % " | ".join(option_parts)


static func if_to_text_board(effect: Dictionary, space_area_id: String = "") -> String:
	var then_text := effects_to_text_board(effect.get("then", []), space_area_id)
	var else_text := effects_to_text_board(effect.get("else", []), space_area_id)
	var requirement_text := requirement_to_text_board(effect.get("requirement", {}))
	if then_text == "":
		then_text = "-"
	if else_text == "":
		return "if %s -> %s" % [requirement_text, then_text]
	return "if %s -> %s else %s" % [requirement_text, then_text, else_text]


static func requirement_to_text_board(requirement: Variant) -> String:
	if typeof(requirement) != TYPE_DICTIONARY:
		return "requirement"
	var req_type := str(requirement.get("type", ""))
	match req_type:
		"min_influence":
			return "influence(%s) >= %d" % [str(requirement.get("faction", "")), int(requirement.get("value", 0))]
		"has_maker_hooks":
			return "maker_hooks == %s" % str(bool(requirement.get("value", true)))
		"flag":
			return "%s == %s" % [str(requirement.get("key", "")), str(requirement.get("value", false))]
		"completed_contracts_at_least":
			return "completed_contracts >= %d" % int(requirement.get("value", 0))
		_:
			return req_type


static func is_influence_choice(effect: Dictionary) -> bool:
	var options = effect.get("options", [])
	if typeof(options) != TYPE_ARRAY or options.size() != 4:
		return false
	var expected_factions := ["emperor", "guild", "beneGesserit", "fremen"]
	for option in options:
		if typeof(option) != TYPE_DICTIONARY:
			return false
		var nested_effects = option.get("effects", [])
		if typeof(nested_effects) != TYPE_ARRAY or nested_effects.size() != 1:
			return false
		var nested_effect = nested_effects[0]
		if typeof(nested_effect) != TYPE_DICTIONARY:
			return false
		if str(nested_effect.get("type", "")) != "gain_influence":
			return false
		if int(nested_effect.get("amount", 0)) != 1:
			return false
		var faction_id := str(nested_effect.get("faction", ""))
		if not expected_factions.has(faction_id):
			return false
	return true


static func is_spice_refinery_trade_choice(effect: Dictionary) -> bool:
	var options = effect.get("options", [])
	if typeof(options) != TYPE_ARRAY or options.size() != 2:
		return false
	var option_zero = options[0]
	var option_one = options[1]
	if typeof(option_zero) != TYPE_DICTIONARY or typeof(option_one) != TYPE_DICTIONARY:
		return false
	var zero_effects = option_zero.get("effects", [])
	if typeof(zero_effects) != TYPE_ARRAY or zero_effects.size() != 1:
		return false
	var zero_gain = zero_effects[0]
	if typeof(zero_gain) != TYPE_DICTIONARY:
		return false
	if str(zero_gain.get("type", "")) != "gain_resource":
		return false
	if str(zero_gain.get("resource", "")) != "solari":
		return false
	if int(zero_gain.get("amount", 0)) != 2:
		return false
	var one_effects = option_one.get("effects", [])
	if typeof(one_effects) != TYPE_ARRAY or one_effects.size() != 2:
		return false
	var one_spend = one_effects[0]
	var one_gain = one_effects[1]
	if typeof(one_spend) != TYPE_DICTIONARY or typeof(one_gain) != TYPE_DICTIONARY:
		return false
	if str(one_spend.get("type", "")) != "spend_resource":
		return false
	if str(one_spend.get("resource", "")) != "spice":
		return false
	if int(one_spend.get("amount", 0)) != 1:
		return false
	if str(one_gain.get("type", "")) != "gain_resource":
		return false
	if str(one_gain.get("resource", "")) != "solari":
		return false
	if int(one_gain.get("amount", 0)) != 4:
		return false
	return true


static func is_gather_support_trade_choice(effect: Dictionary) -> bool:
	var options = effect.get("options", [])
	if typeof(options) != TYPE_ARRAY or options.size() != 2:
		return false
	var option_zero = options[0]
	var option_one = options[1]
	if typeof(option_zero) != TYPE_DICTIONARY or typeof(option_one) != TYPE_DICTIONARY:
		return false
	var zero_effects = option_zero.get("effects", [])
	if typeof(zero_effects) != TYPE_ARRAY or zero_effects.size() != 1:
		return false
	var zero_recruit = zero_effects[0]
	if typeof(zero_recruit) != TYPE_DICTIONARY:
		return false
	if str(zero_recruit.get("type", "")) != "recruit_troops":
		return false
	if int(zero_recruit.get("amount", 0)) != 2:
		return false
	var one_effects = option_one.get("effects", [])
	if typeof(one_effects) != TYPE_ARRAY or one_effects.size() != 3:
		return false
	var one_spend = one_effects[0]
	var one_recruit = one_effects[1]
	var one_water = one_effects[2]
	if typeof(one_spend) != TYPE_DICTIONARY or typeof(one_recruit) != TYPE_DICTIONARY or typeof(one_water) != TYPE_DICTIONARY:
		return false
	if str(one_spend.get("type", "")) != "spend_resource":
		return false
	if str(one_spend.get("resource", "")) != "solari":
		return false
	if int(one_spend.get("amount", 0)) != 2:
		return false
	if str(one_recruit.get("type", "")) != "recruit_troops":
		return false
	if int(one_recruit.get("amount", 0)) != 2:
		return false
	if str(one_water.get("type", "")) != "gain_resource":
		return false
	if str(one_water.get("resource", "")) != "water":
		return false
	if int(one_water.get("amount", 0)) != 1:
		return false
	return true


static func extract_maker_worm_choice(effect: Dictionary) -> Dictionary:
	var options = effect.get("options", [])
	if typeof(options) != TYPE_ARRAY or options.size() != 2:
		return {"ok": false}
	var spice_option = options[0]
	var worm_option = options[1]
	if typeof(spice_option) != TYPE_DICTIONARY or typeof(worm_option) != TYPE_DICTIONARY:
		return {"ok": false}
	var spice_effects = spice_option.get("effects", [])
	if typeof(spice_effects) != TYPE_ARRAY or spice_effects.size() != 1:
		return {"ok": false}
	var spice_gain = spice_effects[0]
	if typeof(spice_gain) != TYPE_DICTIONARY:
		return {"ok": false}
	if str(spice_gain.get("type", "")) != "gain_resource":
		return {"ok": false}
	if str(spice_gain.get("resource", "")) != "spice":
		return {"ok": false}
	var spice_amount := int(spice_gain.get("amount", 0))
	if spice_amount <= 0:
		return {"ok": false}
	var worm_effects = worm_option.get("effects", [])
	if typeof(worm_effects) != TYPE_ARRAY or worm_effects.size() != 1:
		return {"ok": false}
	var conditional = worm_effects[0]
	if typeof(conditional) != TYPE_DICTIONARY:
		return {"ok": false}
	if str(conditional.get("type", "")) != "if":
		return {"ok": false}
	var requirement = conditional.get("requirement", {})
	if typeof(requirement) != TYPE_DICTIONARY:
		return {"ok": false}
	if str(requirement.get("type", "")) != "has_maker_hooks":
		return {"ok": false}
	if not bool(requirement.get("value", false)):
		return {"ok": false}
	var then_effects = conditional.get("then", [])
	if typeof(then_effects) != TYPE_ARRAY or then_effects.size() != 1:
		return {"ok": false}
	var summon = then_effects[0]
	if typeof(summon) != TYPE_DICTIONARY:
		return {"ok": false}
	if str(summon.get("type", "")) != "summon_sandworm":
		return {"ok": false}
	var worm_amount := int(summon.get("amount", 0))
	if worm_amount <= 0:
		return {"ok": false}
	return {"ok": true, "spice_amount": spice_amount, "worm_amount": worm_amount}


static func extract_sietch_tabr_choice(effect: Dictionary) -> Dictionary:
	var options = effect.get("options", [])
	if typeof(options) != TYPE_ARRAY or options.size() != 2:
		return {"ok": false}
	var first = options[0]
	var second = options[1]
	if typeof(first) != TYPE_DICTIONARY or typeof(second) != TYPE_DICTIONARY:
		return {"ok": false}
	var first_effects = first.get("effects", [])
	if typeof(first_effects) != TYPE_ARRAY or first_effects.size() != 3:
		return {"ok": false}
	var first_hooks = first_effects[0]
	var first_troops = first_effects[1]
	var first_water = first_effects[2]
	if typeof(first_hooks) != TYPE_DICTIONARY or typeof(first_troops) != TYPE_DICTIONARY or typeof(first_water) != TYPE_DICTIONARY:
		return {"ok": false}
	if str(first_hooks.get("type", "")) != "gain_maker_hooks":
		return {"ok": false}
	if str(first_troops.get("type", "")) != "recruit_troops":
		return {"ok": false}
	if str(first_water.get("type", "")) != "gain_resource" or str(first_water.get("resource", "")) != "water":
		return {"ok": false}
	var troops_amount := int(first_troops.get("amount", 0))
	var water_amount := int(first_water.get("amount", 0))
	if troops_amount <= 0 or water_amount <= 0:
		return {"ok": false}
	var first_tokens := "%s [troops_badge:%d] [water_badge:%d]" % [
		repeat_token("[maker_hooks_icon]", max(int(first_hooks.get("amount", 1)), 1)),
		troops_amount,
		water_amount
	]
	var second_effects = second.get("effects", [])
	if typeof(second_effects) != TYPE_ARRAY or second_effects.size() != 2:
		return {"ok": false}
	var second_water = second_effects[0]
	var second_shield = second_effects[1]
	if typeof(second_water) != TYPE_DICTIONARY or typeof(second_shield) != TYPE_DICTIONARY:
		return {"ok": false}
	if str(second_water.get("type", "")) != "gain_resource" or str(second_water.get("resource", "")) != "water":
		return {"ok": false}
	if str(second_shield.get("type", "")) != "remove_shield_wall":
		return {"ok": false}
	var second_water_amount := int(second_water.get("amount", 0))
	var second_shield_amount := int(second_shield.get("amount", 0))
	if second_water_amount <= 0 or second_shield_amount <= 0:
		return {"ok": false}
	return {
		"ok": true,
		"first_tokens": first_tokens,
		"second_water": second_water_amount,
		"second_shield_wall": second_shield_amount
	}


# --- Card face text (matches former CardVisuals._effect_to_text paths) ---

static func repeat_effect_token(token: String, amount: int) -> String:
	return repeat_token(token, amount)


static func effects_to_text_card_nested(effects: Variant) -> String:
	return effects_to_text_card_with_skips(
		effects,
		false, false, false, false, false, false, false, false, false, false, false, false, false, false
	)


static func effects_to_text_card_with_skips(
	effects: Variant,
	skip_persuasion: bool,
	skip_sword: bool,
	skip_draw_cards: bool,
	skip_recruit_troops: bool,
	skip_draw_intrigue: bool,
	skip_trash_card: bool,
	skip_gain_resource: bool,
	skip_spend_resource: bool,
	skip_gain_influence: bool,
	skip_vp: bool,
	skip_get_contract: bool,
	skip_summon_sandworm: bool,
	skip_maker_space_conditional_if: bool,
	skip_place_spy: bool
) -> String:
	var normalized_effects: Array = EffectDslScript.normalize_effects_with_aliases(effects)
	if normalized_effects.is_empty():
		return ""
	var parts: Array[String] = []
	for effect in normalized_effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		if skip_persuasion and str(effect.get("type", "")) == "gain_persuasion":
			continue
		if skip_sword and str(effect.get("type", "")) == "gain_sword":
			continue
		if skip_draw_cards and str(effect.get("type", "")) == "draw_cards":
			continue
		if skip_recruit_troops and str(effect.get("type", "")) == "recruit_troops":
			continue
		if skip_draw_intrigue and str(effect.get("type", "")) == "draw_intrigue":
			continue
		if skip_trash_card and str(effect.get("type", "")) == "trash_card":
			continue
		if skip_gain_resource and str(effect.get("type", "")) == "gain_resource":
			continue
		if skip_spend_resource and str(effect.get("type", "")) == "spend_resource":
			continue
		if skip_gain_influence and str(effect.get("type", "")) == "gain_influence":
			continue
		if skip_vp and str(effect.get("type", "")) == "vp":
			continue
		if skip_get_contract and str(effect.get("type", "")) == "get_contract":
			continue
		if skip_summon_sandworm and str(effect.get("type", "")) == "summon_sandworm":
			continue
		if skip_place_spy and str(effect.get("type", "")) == "place_spy":
			continue
		if skip_maker_space_conditional_if and str(effect.get("type", "")) == "if":
			var req_raw: Variant = effect.get("requirement", {})
			var req: Dictionary = req_raw if typeof(req_raw) == TYPE_DICTIONARY else {}
			if str(req.get("type", "")) == "sent_agent_to_maker_space_this_turn":
				continue
		parts.append(effect_to_text_card(effect))
	if parts.is_empty():
		return ""
	return "; ".join(parts)


static func try_build_recall_spy_trade_token(then_raw: Variant) -> String:
	if typeof(then_raw) != TYPE_ARRAY:
		return ""
	var then_effects: Array = then_raw
	if then_effects.size() != 1:
		return ""
	var single: Variant = then_effects[0]
	if typeof(single) != TYPE_DICTIONARY:
		return ""
	if str(single.get("type", "")) != "gain_influence":
		return ""
	var amount := int(single.get("amount", 0))
	var faction := str(single.get("faction", ""))
	if amount <= 0:
		return ""
	if faction != "anyone":
		return ""
	return "[cost_trade:recall_spy:1:influence:%d]" % amount


static func requirement_to_text_card(requirement_raw: Variant) -> String:
	if typeof(requirement_raw) != TYPE_DICTIONARY:
		return "condition"
	var requirement: Dictionary = requirement_raw
	var req_type := str(requirement.get("type", ""))
	match req_type:
		"sent_agent_to_maker_space_this_turn":
			return "sent agent to maker space"
		"sent_agent_to_faction_space_this_turn":
			return "sent agent to faction space"
		"has_fremen_bond":
			return "have Fremen Bond"
		"spying_on_maker_space":
			return "spying on maker space"
		"recalled_spy_this_turn":
			return "recalled spy this turn"
		"has_another_card_in_play_tag":
			return "another %s card in play" % str(requirement.get("tag", "matching"))
		"completed_contracts_at_least":
			return "completed contracts >= %d" % int(requirement.get("value", 0))
		"has_swordmaster":
			return "have Swordmaster"
		"units_in_conflict_at_least":
			return "units in conflict >= %d" % int(requirement.get("value", 0))
		"has_spies_at_least":
			return "spies on board >= %d" % int(requirement.get("value", 0))
		"discarded_card_has_tag":
			return "discarded card has %s tag" % str(requirement.get("tag", "required"))
		"min_influence":
			return "influence(%s) >= %d" % [str(requirement.get("faction", "")), int(requirement.get("value", 0))]
		"flag":
			return "%s == %s" % [str(requirement.get("key", "")), str(requirement.get("value", false))]
		_:
			return req_type if req_type != "" else "condition"


static func effect_to_text_card(effect: Dictionary) -> String:
	var effect_type := str(effect.get("type", "effect"))
	var amount := int(effect.get("amount", 0))
	if effect_type == "gain_resource":
		var resource := str(effect.get("resource", "resource"))
		if resource == "solari":
			return "[solari_badge:%d]" % amount
		if resource == "spice":
			return "[spice_badge:%d]" % amount
		if resource == "water":
			return "[water_badge:%d]" % amount
		return "+%d %s" % [amount, resource]
	if effect_type == "spend_resource":
		var resource_spend := str(effect.get("resource", "resource"))
		if resource_spend == "solari":
			return "[solari_badge:%d]" % (-amount)
		if resource_spend == "spice":
			return "[spice_badge:%d]" % (-amount)
		if resource_spend == "water":
			return "[water_badge:%d]" % (-amount)
		return "-%d %s" % [amount, resource_spend]
	if effect_type == "gain_persuasion":
		return "[persuasion_badge:%d]" % amount
	if effect_type == "gain_sword":
		return repeat_effect_token("[sword_icon]", max(amount, 1))
	if effect_type == "draw_cards":
		return repeat_effect_token("[draw_card_icon]", max(amount, 1))
	if effect_type == "draw_intrigue":
		return repeat_effect_token("[intrigue_icon]", max(amount, 1))
	if effect_type == "trash_card":
		return repeat_effect_token("[trash_card_icon]", max(amount, 1))
	if effect_type == "trash_this_card":
		return "[trash_card_icon] this card"
	if effect_type == "trash_intrigue":
		return repeat_effect_token("[trash_card_icon]", max(amount, 1)) + " intrigue"
	if effect_type == "recruit_troops":
		return "[troops_badge:%d]" % amount
	if effect_type == "deploy_recruited_to_conflict":
		return "[troops_badge:%d] to conflict" % max(amount, 1)
	if effect_type == "fremen_bond_deploy_or_retreat":
		return "[troops_badge:%d] deploy/retreat" % max(amount, 1)
	if effect_type == "discard_card":
		return "discard %d" % max(amount, 1)
	if effect_type == "gain_influence":
		var faction := str(effect.get("faction", "faction"))
		if faction == "anyone":
			return "[influence_icon]"
		return repeat_effect_token("[faction_icon:%s]" % faction, max(amount, 1))
	if effect_type == "lose_influence":
		var lose_faction := str(effect.get("faction", "faction"))
		if lose_faction == "anyone":
			return "-%d [influence_icon]" % max(amount, 1)
		return "-%d [faction_icon:%s]" % [max(amount, 1), lose_faction]
	if effect_type == "place_spy":
		return repeat_effect_token("[spy_icon]", max(amount, 1))
	if effect_type == "get_contract":
		return repeat_effect_token("[contract_icon]", max(amount, 1))
	if effect_type == "recall_agent":
		return repeat_effect_token("[recall_agent_icon]", max(amount, 1))
	if effect_type == "summon_sandworm":
		return repeat_effect_token("[sand_worm_icon]", max(amount, 1))
	if effect_type == "vp":
		return repeat_effect_token("[vp_icon]", max(amount, 1))
	if effect_type == "gain_persuasion_per_completed_contract":
		return "[persuasion_badge:%d] per completed contract" % amount
	if effect_type == "gain_persuasion_per_in_play_tag":
		return "[persuasion_badge:%d] per in-play %s card" % [amount, str(effect.get("tag", "card"))]
	if effect_type == "gain_persuasion_per_revealed_tag":
		return "[persuasion_badge:%d] per revealed %s card" % [amount, str(effect.get("tag", "card"))]
	if effect_type == "gain_sword_per_revealed_tag":
		return "%s per revealed %s card" % [repeat_effect_token("[sword_icon]", max(amount, 1)), str(effect.get("tag", "card"))]
	if effect_type == "draw_cards_per_sandworm_in_conflict":
		return repeat_effect_token("[draw_card_icon]", max(amount, 1)) + " per [sand_worm_icon] in conflict"
	if effect_type == "return_this_card_to_hand":
		return "[recall_agent_icon] this card to hand"
	if effect_type == "opponents_discard_card":
		return repeat_effect_token("[trash_card_icon]", maxi(amount, 1)) + " each opponent"
	if effect_type == "recall_spy_for_effect":
		var reward_raw: Variant = effect.get("rewardEffects", [])
		var reward_text := effects_to_text_card_nested(reward_raw)
		if reward_text == "":
			reward_text = repeat_effect_token("[intrigue_icon]", max(amount, 1))
		return "[spy_icon] recall -> %s" % reward_text
	if effect_type == "if":
		var requirement_text := requirement_to_text_card(effect.get("requirement", {}))
		var then_text := effects_to_text_card_nested(effect.get("then", []))
		var else_text := effects_to_text_card_nested(effect.get("else", []))
		var req_raw: Variant = effect.get("requirement", {})
		var req: Dictionary = req_raw if typeof(req_raw) == TYPE_DICTIONARY else {}
		var req_type := str(req.get("type", ""))
		if req_type == "recalled_spy_this_turn":
			var recall_trade := try_build_recall_spy_trade_token(effect.get("then", []))
			if recall_trade != "":
				if else_text == "":
					return recall_trade
				return "%s else %s" % [recall_trade, else_text]
		if req_type == "spying_on_maker_space":
			if then_text == "":
				then_text = "-"
			if else_text == "":
				return "[maker_hooks_icon] -> %s" % then_text
			return "[maker_hooks_icon] -> %s else %s" % [then_text, else_text]
		if then_text == "":
			then_text = "-"
		if else_text == "":
			return "if %s -> %s" % [requirement_text, then_text]
		return "if %s -> %s else %s" % [requirement_text, then_text, else_text]
	if effect_type == "choice":
		var options_raw: Variant = effect.get("options", [])
		if typeof(options_raw) == TYPE_ARRAY:
			var labels: Array[String] = []
			for option in options_raw:
				if typeof(option) != TYPE_DICTIONARY:
					continue
				var option_dict: Dictionary = option
				var effects_text := effects_to_text_card_nested(option_dict.get("effects", []))
				var label := effects_text
				if label == "":
					label = str(option_dict.get("label", ""))
				var lower_label := label.to_lower()
				if lower_label.begins_with("do not ") or lower_label == "no payment" or lower_label == "":
					continue
				labels.append(label)
			if not labels.is_empty():
				return " OR ".join(labels)
		return "or"
	return effect_type
