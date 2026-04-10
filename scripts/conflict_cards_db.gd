extends Node
class_name ConflictCardsDb

const LEVEL_ALIASES := {
	"1": "I",
	"2": "II",
	"3": "III",
	"I": "I",
	"II": "II",
	"III": "III"
}
const ALLOWED_SANDWORM_POLICIES := {
	"always_allowed": true,
	"blocked_by_shield_wall": true
}
const SANDWORM_POLICY_ALIASES := {
	"blocked_until_wall_broken": "blocked_by_shield_wall"
}
const ALLOWED_BATTLE_ICONS := {
	"crysknife": true,
	"desert_mouse": true,
	"ornithopter": true,
	"wild": true
}
const FACTION_ALIASES := {
	"spacing_guild": "guild",
	"bene_gesserit": "beneGesserit"
}
const ALLOWED_INFLUENCE_FACTIONS := {
	"emperor": true,
	"guild": true,
	"beneGesserit": true,
	"fremen": true,
	"anyone": true,
	"choose_two": true
}

static func load_conflict_cards(path: String = "res://data/conflict_cards_base.json") -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ConflictCardsDb: failed to open %s" % path)
		return []

	var text := file.get_as_text()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("ConflictCardsDb: expected array in %s" % path)
		return []

	var valid: Array = []
	var seen_ids: Dictionary = {}
	for card in parsed:
		if typeof(card) != TYPE_DICTIONARY:
			continue
		var normalized_card := _normalize_conflict_card(card)
		var card_id := str(normalized_card.get("id", ""))
		if card_id == "":
			push_warning("ConflictCardsDb: card without id skipped")
			continue
		if seen_ids.has(card_id):
			push_warning("ConflictCardsDb: duplicate id=%s skipped" % card_id)
			continue
		if not _is_valid_conflict_card(normalized_card):
			push_warning("ConflictCardsDb: invalid conflict schema for id=%s" % card_id)
			continue
		seen_ids[card_id] = true
		valid.append(normalized_card)
	return valid

static func _normalize_conflict_card(card: Dictionary) -> Dictionary:
	var normalized: Dictionary = card.duplicate(true)
	normalized["id"] = str(card.get("id", "")).strip_edges()
	normalized["name"] = str(card.get("name", "")).strip_edges()
	normalized["level"] = _normalize_level(card.get("level", ""))
	normalized["shieldWallProtected"] = bool(card.get("shieldWallProtected", false))
	normalized["sandwormPolicy"] = _normalize_sandworm_policy(card.get("sandwormPolicy", "always_allowed"))
	normalized["battleIcons"] = _normalize_battle_icons(card.get("battleIcons", []))
	var default_control_space := str(card.get("controlSpaceId", "")).strip_edges()
	normalized["controlSpaceId"] = default_control_space
	normalized["firstReward"] = _normalize_reward_list(card.get("firstReward", []), default_control_space)
	normalized["secondReward"] = _normalize_reward_list(card.get("secondReward", []), default_control_space)
	normalized["thirdReward"] = _normalize_reward_list(card.get("thirdReward", []), default_control_space)
	return normalized

static func _normalize_level(value: Variant) -> String:
	var key := str(value).strip_edges().to_upper()
	if LEVEL_ALIASES.has(key):
		return str(LEVEL_ALIASES[key])
	return key

static func _normalize_sandworm_policy(value: Variant) -> String:
	var policy := str(value).strip_edges()
	if SANDWORM_POLICY_ALIASES.has(policy):
		return str(SANDWORM_POLICY_ALIASES[policy])
	if ALLOWED_SANDWORM_POLICIES.has(policy):
		return policy
	return "always_allowed"

static func _normalize_battle_icons(icons: Variant) -> Array:
	if typeof(icons) != TYPE_ARRAY:
		return []
	var normalized_icons: Array = []
	for raw_icon in icons:
		var icon := str(raw_icon).strip_edges()
		if icon == "":
			continue
		if not ALLOWED_BATTLE_ICONS.has(icon):
			continue
		if normalized_icons.has(icon):
			continue
		normalized_icons.append(icon)
	return normalized_icons

static func _normalize_reward_list(rewards: Variant, default_control_space_id: String) -> Array:
	if typeof(rewards) != TYPE_ARRAY:
		return []
	var normalized: Array = []
	for reward in rewards:
		if typeof(reward) != TYPE_DICTIONARY:
			continue
		normalized.append(_normalize_reward(reward, default_control_space_id))
	return normalized

static func _normalize_reward(reward: Dictionary, default_control_space_id: String = "") -> Dictionary:
	var normalized: Dictionary = reward.duplicate(true)
	var reward_type := str(normalized.get("type", "")).strip_edges()
	if reward_type == "control":
		reward_type = "gain_control"
	elif reward_type == "resource":
		reward_type = "gain_resource"
	elif reward_type == "intrigue":
		reward_type = "draw_intrigue"
	elif reward_type == "contract":
		reward_type = "get_contract"
	normalized["type"] = reward_type
	match reward_type:
		"vp", "recruit_troops", "draw_intrigue", "get_contract", "place_spy", "trash_card":
			normalized["amount"] = int(normalized.get("amount", 1))
		"gain_resource":
			normalized["resource"] = str(normalized.get("resource", "")).strip_edges()
			normalized["amount"] = int(normalized.get("amount", 0))
		"gain_influence":
			normalized["faction"] = _normalize_faction(str(normalized.get("faction", "")).strip_edges())
			normalized["amount"] = int(normalized.get("amount", 0))
			if normalized["faction"] == "choose_two":
				normalized["factions"] = _normalize_faction_list(normalized.get("factions", []))
			else:
				normalized.erase("factions")
		"gain_control":
			var board_space_id := str(normalized.get("boardSpaceId", "")).strip_edges()
			if board_space_id == "":
				board_space_id = str(normalized.get("controlSpaceId", "")).strip_edges()
			if board_space_id == "":
				board_space_id = default_control_space_id
			normalized["boardSpaceId"] = board_space_id
		"cost":
			normalized["resource"] = str(normalized.get("resource", "")).strip_edges()
			normalized["amount"] = int(normalized.get("amount", 0))
			var nested_effect: Variant = normalized.get("effect", {})
			if typeof(nested_effect) == TYPE_DICTIONARY:
				normalized["effect"] = _normalize_reward(nested_effect, default_control_space_id)
			else:
				normalized["effect"] = {}
	return normalized

static func _normalize_faction(faction: String) -> String:
	if FACTION_ALIASES.has(faction):
		return str(FACTION_ALIASES[faction])
	return faction

static func _normalize_faction_list(factions: Variant) -> Array:
	if typeof(factions) != TYPE_ARRAY:
		return []
	var out: Array = []
	for value in factions:
		var faction := _normalize_faction(str(value).strip_edges())
		if faction == "":
			continue
		if out.has(faction):
			continue
		out.append(faction)
	return out

static func _is_valid_conflict_card(card: Dictionary) -> bool:
	if str(card.get("id", "")) == "":
		return false
	if str(card.get("name", "")) == "":
		return false
	var level := str(card.get("level", "")).to_upper()
	if not LEVEL_ALIASES.has(level):
		return false

	if card.has("shieldWallProtected") and typeof(card.get("shieldWallProtected")) != TYPE_BOOL:
		return false
	if card.has("sandwormPolicy"):
		var policy := str(card.get("sandwormPolicy", ""))
		if not ALLOWED_SANDWORM_POLICIES.has(policy):
			return false
	if card.has("controlSpaceId") and typeof(card.get("controlSpaceId")) != TYPE_STRING:
		return false
	if card.has("battleIcons") and not _is_valid_battle_icons(card.get("battleIcons", [])):
		return false

	if typeof(card.get("firstReward", [])) != TYPE_ARRAY:
		return false
	if typeof(card.get("secondReward", [])) != TYPE_ARRAY:
		return false
	if typeof(card.get("thirdReward", [])) != TYPE_ARRAY:
		return false
	if not _is_valid_reward_list(card.get("firstReward", [])):
		return false
	if not _is_valid_reward_list(card.get("secondReward", [])):
		return false
	if not _is_valid_reward_list(card.get("thirdReward", [])):
		return false
	return true

static func _is_valid_battle_icons(icons: Variant) -> bool:
	if typeof(icons) != TYPE_ARRAY:
		return false
	for icon in icons:
		var value := str(icon).strip_edges()
		if value == "":
			return false
		if not ALLOWED_BATTLE_ICONS.has(value):
			return false
	return true

static func _is_valid_reward_list(rewards: Variant) -> bool:
	if typeof(rewards) != TYPE_ARRAY:
		return false
	for reward in rewards:
		if typeof(reward) != TYPE_DICTIONARY:
			return false
		if not _is_valid_reward(reward):
			return false
	return true

static func _is_valid_reward(reward: Dictionary) -> bool:
	var reward_type := str(reward.get("type", ""))
	match reward_type:
		"vp", "recruit_troops", "draw_intrigue", "get_contract", "place_spy", "trash_card":
			return int(reward.get("amount", 1)) >= 0
		"gain_resource":
			var resource := str(reward.get("resource", ""))
			return (resource == "solari" or resource == "spice" or resource == "water") and int(reward.get("amount", 0)) >= 0
		"gain_influence":
			var faction := str(reward.get("faction", ""))
			if not ALLOWED_INFLUENCE_FACTIONS.has(faction):
				return false
			if int(reward.get("amount", 0)) < 0:
				return false
			if faction == "choose_two":
				var factions: Variant = reward.get("factions", [])
				return typeof(factions) == TYPE_ARRAY and not factions.is_empty()
			return true
		"gain_control":
			return true
		"cost":
			if int(reward.get("amount", 0)) < 0:
				return false
			var cost_resource := str(reward.get("resource", ""))
			if cost_resource == "":
				return false
			var nested_effect: Variant = reward.get("effect", {})
			return _is_valid_cost_effect(nested_effect)
		_:
			return false

static func _is_valid_cost_effect(effect: Variant) -> bool:
	if typeof(effect) != TYPE_DICTIONARY:
		return false
	var effect_type := str(effect.get("type", ""))
	if effect_type == "vp":
		return int(effect.get("amount", 0)) >= 0
	if effect_type == "resource" or effect_type == "gain_resource":
		var resource := str(effect.get("resource", ""))
		return (resource == "solari" or resource == "spice" or resource == "water") and int(effect.get("amount", 0)) >= 0
	return false
