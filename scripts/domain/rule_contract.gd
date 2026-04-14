extends RefCounted
class_name RuleContract

const REQUIRED_PHASE_FLOW: PackedStringArray = [
	"round_start",
	"player_turns",
	"conflict",
	"makers",
	"recall"
]

const TIE_BREAK_ORDER: PackedStringArray = [
	"spice",
	"solari",
	"water",
	"garrisonTroops",
	"lastRevealOrder"
]

static func validate_game_state_shape(game_state: Dictionary) -> Dictionary:
	var players_raw: Variant = game_state.get("players", [])
	if typeof(players_raw) != TYPE_ARRAY:
		return {"ok": false, "reason": "players_not_array"}
	var players: Array = players_raw
	if players.size() < 2 or players.size() > 4:
		return {"ok": false, "reason": "players_count_out_of_standard_range"}
	if str(game_state.get("phase", "")) == "":
		return {"ok": false, "reason": "missing_phase"}
	return {"ok": true}

static func compute_combat_power(zone_entry: Dictionary) -> int:
	var troops := int(zone_entry.get("troops", 0))
	var sandworms := int(zone_entry.get("sandworms", 0))
	var swords := int(zone_entry.get("revealedSwordPower", 0))
	if troops <= 0 and sandworms <= 0:
		return 0
	return troops * 2 + sandworms * 3 + swords

static func compare_players_for_endgame(a: Dictionary, b: Dictionary) -> int:
	var a_vp := int(a.get("vp", 0))
	var b_vp := int(b.get("vp", 0))
	if a_vp != b_vp:
		return a_vp - b_vp

	var a_res: Dictionary = a.get("resources", {}) if typeof(a.get("resources", {})) == TYPE_DICTIONARY else {}
	var b_res: Dictionary = b.get("resources", {}) if typeof(b.get("resources", {})) == TYPE_DICTIONARY else {}

	var spice_cmp := int(a_res.get("spice", 0)) - int(b_res.get("spice", 0))
	if spice_cmp != 0:
		return spice_cmp

	var solari_cmp := int(a_res.get("solari", 0)) - int(b_res.get("solari", 0))
	if solari_cmp != 0:
		return solari_cmp

	var water_cmp := int(a_res.get("water", 0)) - int(b_res.get("water", 0))
	if water_cmp != 0:
		return water_cmp

	var garrison_cmp := int(a.get("garrisonTroops", 0)) - int(b.get("garrisonTroops", 0))
	if garrison_cmp != 0:
		return garrison_cmp

	# Larger reveal order means revealed later in the round.
	var reveal_cmp := int(a.get("lastRevealOrder", -1)) - int(b.get("lastRevealOrder", -1))
	return reveal_cmp
