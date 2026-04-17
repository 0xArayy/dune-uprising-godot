extends Node
class_name CardsDb

const DEFAULT_CARDS_PATH := "res://data/cards_uprising.json"
const DEFAULT_OVERRIDES_PATH := "res://data/cards_uprising_overrides.json"

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
	var overrides_by_id := _load_overrides_by_id()
	for card in parsed:
		if typeof(card) != TYPE_DICTIONARY:
			continue
		var normalized_card: Dictionary = _normalize_card_from_raw(card, overrides_by_id)
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

static func _normalize_card_from_raw(card: Dictionary, overrides_by_id: Dictionary) -> Dictionary:
	var normalized: Dictionary = card.duplicate(true)
	var card_id := str(normalized.get("id", ""))
	if overrides_by_id.has(card_id):
		var override_def: Variant = overrides_by_id.get(card_id, {})
		if typeof(override_def) == TYPE_DICTIONARY:
			for key in (override_def as Dictionary).keys():
				normalized[key] = (override_def as Dictionary)[key]
	return normalized

static func _load_overrides_by_id(path: String = DEFAULT_OVERRIDES_PATH) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("CardsDb: expected dictionary in %s" % path)
		return {}
	return parsed

