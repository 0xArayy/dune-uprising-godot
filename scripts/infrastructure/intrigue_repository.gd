extends RefCounted
class_name IntrigueRepository

const IntrigueCardsDbScript = preload("res://scripts/intrigue_cards_db.gd")

var _cache: Dictionary = {}

func get_all_by_id() -> Dictionary:
	if _cache.is_empty():
		_cache = IntrigueCardsDbScript.load_intrigue_cards_by_id()
	return _cache

func reload() -> Dictionary:
	_cache = IntrigueCardsDbScript.load_intrigue_cards_by_id()
	return _cache
