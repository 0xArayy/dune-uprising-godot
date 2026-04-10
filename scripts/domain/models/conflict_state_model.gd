extends RefCounted
class_name ConflictStateModel

var active_card_id: String = ""
var phase: String = ""
var shield_wall_intact: bool = true

func from_dict(data: Dictionary) -> ConflictStateModel:
	active_card_id = str(data.get("activeConflictCardId", ""))
	phase = str(data.get("phase", ""))
	shield_wall_intact = bool(data.get("shieldWallIntact", true))
	return self

func to_dict() -> Dictionary:
	return {
		"activeConflictCardId": active_card_id,
		"phase": phase,
		"shieldWallIntact": shield_wall_intact
	}
