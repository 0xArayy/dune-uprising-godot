extends RefCounted
class_name ConflictRepository

const ConflictCardsDbScript = preload("res://scripts/conflict_cards_db.gd")

var _cache_by_id: Dictionary = {}

func get_all_by_id() -> Dictionary:
	if _cache_by_id.is_empty():
		var all_cards: Array = ConflictCardsDbScript.load_conflict_cards()
		for card in all_cards:
			if typeof(card) != TYPE_DICTIONARY:
				continue
			var card_id := str(card.get("id", ""))
			if card_id == "":
				continue
			_cache_by_id[card_id] = card
	return _cache_by_id

func reload() -> Dictionary:
	_cache_by_id.clear()
	return get_all_by_id()
