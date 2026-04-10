extends RefCounted
class_name IntrigueCardsDb

const ALLOWED_INTRIGUE_TYPES := {
	"plot": true,
	"combat": true,
	"endgame": true
}

static func load_intrigue_cards_by_id(path: String = "res://data/intrigue_cards_uprising.json") -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("IntrigueCardsDb: failed to open %s" % path)
		return {}

	var text := file.get_as_text()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("IntrigueCardsDb: expected array in %s" % path)
		return {}

	var by_id: Dictionary = {}
	var seen_ids: Dictionary = {}
	for card in parsed:
		if typeof(card) != TYPE_DICTIONARY:
			continue
		var normalized := _normalize_intrigue_card(card)
		var card_id := str(normalized.get("id", ""))
		if card_id == "":
			push_warning("IntrigueCardsDb: card without id skipped")
			continue
		if seen_ids.has(card_id):
			push_warning("IntrigueCardsDb: duplicate id=%s skipped" % card_id)
			continue
		if not _is_valid_intrigue_card(normalized):
			push_warning("IntrigueCardsDb: invalid schema for id=%s" % card_id)
			continue
		seen_ids[card_id] = true
		by_id[card_id] = normalized
	return by_id

static func _normalize_intrigue_card(card: Dictionary) -> Dictionary:
	var normalized: Dictionary = card.duplicate(true)
	normalized["id"] = str(card.get("id", "")).strip_edges()
	normalized["name"] = str(card.get("name", "")).strip_edges()
	normalized["intrigueType"] = str(card.get("intrigueType", "plot")).strip_edges().to_lower()
	if not ALLOWED_INTRIGUE_TYPES.has(normalized["intrigueType"]):
		normalized["intrigueType"] = "plot"
	var play_fx: Variant = card.get("playEffect", [])
	normalized["playEffect"] = play_fx if typeof(play_fx) == TYPE_ARRAY else []
	var play_cost: Variant = card.get("playCost", [])
	normalized["playCost"] = play_cost if typeof(play_cost) == TYPE_ARRAY else []
	normalized["immediateOnConflictWinReward"] = bool(card.get("immediateOnConflictWinReward", false))
	return normalized

static func _is_valid_intrigue_card(card: Dictionary) -> bool:
	if str(card.get("id", "")) == "":
		return false
	if str(card.get("name", "")) == "":
		return false
	var t := str(card.get("intrigueType", "")).strip_edges().to_lower()
	if not ALLOWED_INTRIGUE_TYPES.has(t):
		return false
	if typeof(card.get("playEffect", [])) != TYPE_ARRAY:
		return false
	if card.has("playCost") and typeof(card.get("playCost")) != TYPE_ARRAY:
		return false
	return true
