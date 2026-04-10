extends RefCounted
class_name IntrigueEffectText

## Human-readable lines for intrigue card playEffect arrays (English, for UI).
static func format_play_effect_list(effects: Array) -> String:
	if effects.is_empty():
		return "(no effect)"
	var lines: Array[String] = []
	for raw in effects:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var effect_line := _format_one_effect(raw as Dictionary)
		if effect_line != "":
			lines.append(effect_line)
	if lines.is_empty():
		return "(unknown effects)"
	var out := ""
	for i in range(lines.size()):
		if i > 0:
			out += "\n"
		out += lines[i]
	return out

static func format_intrigue_card_def(def: Dictionary) -> String:
	var fx: Variant = def.get("playEffect", [])
	if typeof(fx) != TYPE_ARRAY:
		return "(no effect)"
	return format_play_effect_list(fx as Array)

static func _format_one_effect(effect: Dictionary) -> String:
	var t := str(effect.get("type", "")).strip_edges()
	match t:
		"gain_resource":
			return "Gain %d %s" % [int(effect.get("amount", 0)), str(effect.get("resource", ""))]
		"spend_resource":
			return "Spend %d %s" % [int(effect.get("amount", 0)), str(effect.get("resource", ""))]
		"vp":
			return "Gain %d VP" % int(effect.get("amount", 0))
		"gain_sword":
			return "+%d combat strength (swords)" % int(effect.get("amount", 0))
		"gain_persuasion":
			return "+%d persuasion" % int(effect.get("amount", 0))
		"draw_cards":
			return "Draw %d card(s)" % int(effect.get("amount", 0))
		"draw_intrigue":
			return "Draw %d intrigue" % int(effect.get("amount", 0))
		"recruit_troops":
			return "Recruit %d troop(s)" % int(effect.get("amount", 0))
		_:
			return "%s: %s" % [t, str(effect)]
