extends RefCounted
class_name ObjectiveCardsDb

const ALLOWED_BATTLE_ICONS := {
	"crysknife": true,
	"desert_mouse": true,
	"ornithopter": true,
	"wild": true
}

static func load_objective_cards(path: String = "res://data/objective_cards_base.json") -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ObjectiveCardsDb: failed to open %s" % path)
		return []

	var text := file.get_as_text()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("ObjectiveCardsDb: expected array in %s" % path)
		return []

	var out: Array = []
	var seen: Dictionary = {}
	for raw in parsed:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var objective := _normalize_objective(raw)
		var objective_id := str(objective.get("id", ""))
		if objective_id == "" or seen.has(objective_id):
			continue
		if not _is_valid_objective(objective):
			push_warning("ObjectiveCardsDb: invalid objective schema for id=%s" % objective_id)
			continue
		seen[objective_id] = true
		out.append(objective)
	return out

static func _normalize_objective(raw: Dictionary) -> Dictionary:
	var objective: Dictionary = raw.duplicate(true)
	objective["id"] = str(raw.get("id", "")).strip_edges()
	objective["name"] = str(raw.get("name", "")).strip_edges()
	objective["battleIcon"] = str(raw.get("battleIcon", "")).strip_edges()
	return objective

static func _is_valid_objective(objective: Dictionary) -> bool:
	if str(objective.get("id", "")) == "":
		return false
	if str(objective.get("name", "")) == "":
		return false
	var icon := str(objective.get("battleIcon", "")).strip_edges()
	return ALLOWED_BATTLE_ICONS.has(icon)
