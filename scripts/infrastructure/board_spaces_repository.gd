extends RefCounted
class_name BoardSpacesRepository

const BoardSpacesDbScript = preload("res://scripts/board_spaces_db.gd")

var _cache: Dictionary = {}

func get_all() -> Dictionary:
	if _cache.is_empty():
		_cache = BoardSpacesDbScript.load_spaces_by_id()
	return _cache

func get_by_id(space_id: String) -> Dictionary:
	var all_spaces: Dictionary = get_all()
	var raw: Variant = all_spaces.get(space_id, {})
	return raw if typeof(raw) == TYPE_DICTIONARY else {}

func reload() -> Dictionary:
	_cache = BoardSpacesDbScript.load_spaces_by_id()
	return _cache
