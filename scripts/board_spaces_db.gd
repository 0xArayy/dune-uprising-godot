extends Node
class_name BoardSpacesDb

static func load_spaces_by_id(path: String = "res://data/board_spaces_uprising.json") -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("BoardSpacesDb: failed to open %s" % path)
		return {}

	var text := file.get_as_text()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("BoardSpacesDb: expected array in %s" % path)
		return {}

	var by_id := {}
	for space in parsed:
		if typeof(space) != TYPE_DICTIONARY:
			continue
		var space_id := str(space.get("id", ""))
		if space_id == "":
			push_warning("BoardSpacesDb: space without id skipped")
			continue
		if not _is_valid_space_def(space):
			push_warning("BoardSpacesDb: invalid space schema for id=%s" % space_id)
			continue
		by_id[space_id] = space
	return by_id

static func _is_valid_space_def(space: Dictionary) -> bool:
	if not space.has("requiredAgentIcons") or typeof(space.get("requiredAgentIcons", [])) != TYPE_ARRAY:
		return false
	if typeof(space.get("cost", [])) != TYPE_ARRAY:
		return false
	if typeof(space.get("requirements", [])) != TYPE_ARRAY:
		return false
	if typeof(space.get("effects", [])) != TYPE_ARRAY:
		return false
	return true

