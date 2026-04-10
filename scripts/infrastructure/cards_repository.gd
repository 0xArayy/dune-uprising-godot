extends RefCounted
class_name CardsRepository

const CardsDbScript = preload("res://scripts/cards_db.gd")

var _cache: Dictionary = {}

func get_all() -> Dictionary:
	if _cache.is_empty():
		_cache = CardsDbScript.load_cards_by_id()
	return _cache

func reload() -> Dictionary:
	_cache = CardsDbScript.load_cards_by_id()
	return _cache
