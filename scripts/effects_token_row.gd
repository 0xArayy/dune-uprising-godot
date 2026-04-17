extends RefCounted
class_name EffectsTokenRow

# Renders the same effect token strings as BoardSpaceMarker.set_effects_text (icons + numeric badges).

const INFLUENCE_ICON_TOKEN := "[influence_icon]"
const INFLUENCE2_ICON_TOKEN := "[influence2_icon]"
const CONTRACT_ICON_TOKEN := "[contract_icon]"
const CONTROL_ICON_TOKEN := "[control_icon]"
const CONTROL_ICON_TOKEN_PREFIX := "[control_icon:"
const INFLUENCE_CHOICE_SET_TOKEN_PREFIX := "[influence_choice_set:"
const FACTION_INFLUENCE_CHOICE_TOKEN_PREFIX := "[faction_influence_choice:"
const SPY_ICON_TOKEN := "[spy_icon]"
const RECALL_AGENT_ICON_TOKEN := "[recall_agent_icon]"
const GET_AGENT_ICON_TOKEN := "[get_agent_icon]"
const SWORD_ICON_TOKEN := "[sword_icon]"
const DRAW_CARD_ICON_TOKEN := "[draw_card_icon]"
const VP_ICON_TOKEN := "[vp_icon]"
const INTRIGUE_ICON_TOKEN := "[intrigue_icon]"
const TRASH_CARD_ICON_TOKEN := "[trash_card_icon]"
const MAKER_HOOKS_ICON_TOKEN := "[maker_hooks_icon]"
const SAND_WORM_ICON_TOKEN := "[sand_worm_icon]"
const MAKER_WORM_CHOICE_TOKEN_PREFIX := "[maker_worm_choice:"
const SIETCH_TABR_SECOND_OPTION_TOKEN_PREFIX := "[sietch_tabr_second_option:"
const SPICE_REFINERY_TRADE_TOKEN := "[spice_refinery_trade]"
const SPICE_REFINERY_ROW0_TOKEN := "[spice_refinery_row0]"
const SPICE_REFINERY_ROW1_TOKEN := "[spice_refinery_row1]"
const GATHER_SUPPORT_TRADE_TOKEN := "[gather_support_trade]"
const COST_TRADE_TOKEN_PREFIX := "[cost_trade:"
const HIGH_COUNCIL_CHOICE_TOKEN_PREFIX := "[high_council_choice:"
const GATHER_SUPPORT_ROW0_TOKEN := "[gather_support_row0]"
const GATHER_SUPPORT_ROW1_TOKEN := "[gather_support_row1]"
const SOLARI_BADGE_TOKEN_PREFIX := "[solari_badge:"
const PERSUASION_BADGE_TOKEN_PREFIX := "[persuasion_badge:"
const SPICE_BADGE_TOKEN_PREFIX := "[spice_badge:"
const MAKER_COLLECT_SPICE_BADGE_PREFIX := "[maker_collect_spice_badge:"
const WATER_BADGE_TOKEN_PREFIX := "[water_badge:"
const TROOPS_BADGE_TOKEN_PREFIX := "[troops_badge:"
const DRAW_CARD_ICON_PATH := "res://data/icons/draw_card.png"
const INTRIGUE_ICON_PATH := "res://data/icons/intrigue.png"
const TRASH_CARD_ICON_PATH := "res://data/icons/trash_card.png"
const MAKER_HOOKS_ICON_PATH := "res://data/icons/maker_hooks.png"
const SPY_ICON_PATH := "res://data/icons/spy.png"
const RECALL_AGENT_ICON_PATH := "res://data/icons/recall_agent.png"
const RECALL_SPY_ICON_PATH := "res://data/icons/recall_spy.png"
const GET_AGENT_ICON_PATH := "res://data/icons/get_agent.png"
const SWORD_ICON_PATH := "res://data/icons/sword.png"
const SAND_WORM_ICON_PATH := "res://data/icons/sand_worm.png"
const SHIELD_WALL_ICON_PATH := "res://data/icons/shield_wall.png"
const INFLUENCE_ICON_PATH := "res://data/icons/influence.png"
const INFLUENCE2_ICON_PATH := "res://data/icons/influence2.png"
const CONTRACT_ICON_PATH := "res://data/icons/contract.png"
const CONTROL_ICON_PATH := "res://data/icons/control.png"
const FREMEN_INFLUENCE_ICON_PATH := "res://data/icons/fremen_influnce.png"
const EMPEROR_INFLUENCE_ICON_PATH := "res://data/icons/emperor_influence.png"
const GUILD_INFLUENCE_ICON_PATH := "res://data/icons/spacing_guild_influence.png"
const BENE_GESSERIT_INFLUENCE_ICON_PATH := "res://data/icons/bene_gesserit_influence.png"
const SOLARI_ICON_PATH := "res://data/icons/solari.png"
const PERSUASION_ICON_PATH := "res://data/icons/persuasion.png"
const SPICE_ICON_PATH := "res://data/icons/resource_spice.png"
const WATER_ICON_PATH := "res://data/icons/water.png"
const TROOPS_ICON_PATH := "res://data/icons/troops.png"
const VP_ICON_PATH := "res://data/icons/vp.png"
const ARROW_ICON_PATH := "res://data/icons/arrow_right.png"
static var _texture_cache: Dictionary = {}

static func populate(container: HBoxContainer, effects_text: String, icon_scale: float = 1.0) -> void:
	if container == null:
		return
	var strict_strip_mode := container.name == "AgentEffectTokens" or container.name == "RevealEffectTokens"
	icon_scale = clampf(icon_scale, 0.72, 1.0)
	for child in container.get_children():
		container.remove_child(child)
		child.free()
	effects_text = effects_text.replace("\n", " ")

	var text_stripped := effects_text.strip_edges()
	text_stripped = _strip_and_append_faction_icons(container, text_stripped, icon_scale)
	text_stripped = _strip_and_append_resource_word_icons(container, text_stripped, icon_scale)
	text_stripped = text_stripped.strip_edges()

	var has_gather_support_trade: bool = text_stripped.find(GATHER_SUPPORT_TRADE_TOKEN) >= 0
	var has_gather_support_row0: bool = text_stripped.find(GATHER_SUPPORT_ROW0_TOKEN) >= 0
	var has_gather_support_row1: bool = text_stripped.find(GATHER_SUPPORT_ROW1_TOKEN) >= 0
	var has_spice_refinery_row0: bool = text_stripped.find(SPICE_REFINERY_ROW0_TOKEN) >= 0
	var has_spice_refinery_row1: bool = text_stripped.find(SPICE_REFINERY_ROW1_TOKEN) >= 0
	text_stripped = text_stripped.replace(GATHER_SUPPORT_TRADE_TOKEN, "")
	text_stripped = text_stripped.replace(GATHER_SUPPORT_ROW0_TOKEN, "")
	text_stripped = text_stripped.replace(GATHER_SUPPORT_ROW1_TOKEN, "")
	text_stripped = text_stripped.replace(SPICE_REFINERY_ROW0_TOKEN, "")
	text_stripped = text_stripped.replace(SPICE_REFINERY_ROW1_TOKEN, "")
	text_stripped = text_stripped.strip_edges()

	if text_stripped == "":
		container.add_theme_constant_override("separation", 6)
		if has_gather_support_trade:
			if strict_strip_mode:
				container.add_child(_build_cost_trade_box("solari", 2, "troops", 2, icon_scale))
			else:
				container.add_child(build_gather_support_trade_box(icon_scale))
		elif has_gather_support_row0:
			if strict_strip_mode:
				container.add_child(_build_cost_trade_box("solari", 0, "troops", 2, icon_scale))
			else:
				container.add_child(_build_gather_support_row0(icon_scale))
		elif has_gather_support_row1:
			if strict_strip_mode:
				container.add_child(_build_cost_trade_box("solari", 2, "water", 1, icon_scale))
			else:
				container.add_child(_build_gather_support_row1(icon_scale))
		elif has_spice_refinery_row0:
			if strict_strip_mode:
				container.add_child(_build_cost_trade_box("spice", 0, "solari", 2, icon_scale))
			else:
				container.add_child(_build_spice_refinery_row0(icon_scale))
		elif has_spice_refinery_row1:
			if strict_strip_mode:
				container.add_child(_build_cost_trade_box("spice", 1, "solari", 4, icon_scale))
			else:
				container.add_child(_build_spice_refinery_row1(icon_scale))
		return

	var has_influence_icon: bool = text_stripped.find(INFLUENCE_ICON_TOKEN) >= 0
	var has_influence2_icon: bool = text_stripped.find(INFLUENCE2_ICON_TOKEN) >= 0
	var has_contract_icon: bool = text_stripped.find(CONTRACT_ICON_TOKEN) >= 0
	var has_spice_refinery_trade: bool = text_stripped.find(SPICE_REFINERY_TRADE_TOKEN) >= 0
	var parsed_spy := _extract_token_count(text_stripped, SPY_ICON_TOKEN)
	var parsed_recall_agent := _extract_token_count(str(parsed_spy.get("text", "")), RECALL_AGENT_ICON_TOKEN)
	var parsed_get_agent := _extract_token_count(str(parsed_recall_agent.get("text", "")), GET_AGENT_ICON_TOKEN)
	var parsed_sword := _extract_token_count(str(parsed_get_agent.get("text", "")), SWORD_ICON_TOKEN)
	var parsed_draw_cards := _extract_token_count(str(parsed_sword.get("text", "")), DRAW_CARD_ICON_TOKEN)
	var parsed_vp := _extract_token_count(str(parsed_draw_cards.get("text", "")), VP_ICON_TOKEN)
	var parsed_intrigue := _extract_token_count(str(parsed_vp.get("text", "")), INTRIGUE_ICON_TOKEN)
	var parsed_trash := _extract_token_count(str(parsed_intrigue.get("text", "")), TRASH_CARD_ICON_TOKEN)
	var parsed_maker_hooks := _extract_token_count(str(parsed_trash.get("text", "")), MAKER_HOOKS_ICON_TOKEN)
	var parsed_sand_worm := _extract_token_count(str(parsed_maker_hooks.get("text", "")), SAND_WORM_ICON_TOKEN)
	var parsed_sietch_tabr_second := _extract_sietch_tabr_second_option(str(parsed_sand_worm.get("text", "")))
	var parsed_maker_worm_choice := _extract_maker_worm_choice(str(parsed_sietch_tabr_second.get("text", "")))
	var parsed_solari := _extract_solari_badge_value(str(parsed_maker_worm_choice.get("text", "")))
	var parsed_persuasion := _extract_persuasion_badge_value(str(parsed_solari.get("text", "")))
	var parsed_maker_collect_spice := _extract_badge_value(str(parsed_persuasion.get("text", "")), MAKER_COLLECT_SPICE_BADGE_PREFIX)
	var parsed_spice := _extract_spice_badge_value(str(parsed_maker_collect_spice.get("text", "")))
	var parsed_water := _extract_water_badge_value(str(parsed_spice.get("text", "")))
	var parsed_troops := _extract_troops_badge_value(str(parsed_water.get("text", "")))
	var parsed_cost_trades := _extract_cost_trades(str(parsed_troops.get("text", "")))
	var parsed_high_council_choice := _extract_high_council_choice(str(parsed_cost_trades.get("text", "")))
	var parsed_control_icons := _extract_control_icons(str(parsed_high_council_choice.get("text", "")))
	var parsed_influence_choice_set := _extract_influence_choice_set(str(parsed_control_icons.get("text", "")))
	var parsed_single_influence_choice := _extract_single_influence_choice(str(parsed_influence_choice_set.get("text", "")))
	var cleaned_text: String = str(parsed_single_influence_choice.get("text", ""))
	cleaned_text = cleaned_text.replace(INFLUENCE_ICON_TOKEN, "")
	cleaned_text = cleaned_text.replace(INFLUENCE2_ICON_TOKEN, "")
	cleaned_text = cleaned_text.replace(CONTRACT_ICON_TOKEN, "")
	cleaned_text = cleaned_text.replace(CONTROL_ICON_TOKEN, "")
	cleaned_text = cleaned_text.replace(DRAW_CARD_ICON_TOKEN, "")
	cleaned_text = cleaned_text.replace(SWORD_ICON_TOKEN, "")
	cleaned_text = cleaned_text.replace(SPICE_REFINERY_TRADE_TOKEN, "")
	cleaned_text = cleaned_text.replace(GATHER_SUPPORT_TRADE_TOKEN, "")
	cleaned_text = cleaned_text.replace(GATHER_SUPPORT_ROW0_TOKEN, "")
	cleaned_text = cleaned_text.replace(GATHER_SUPPORT_ROW1_TOKEN, "")
	cleaned_text = cleaned_text.replace(SPICE_REFINERY_ROW0_TOKEN, "")
	cleaned_text = cleaned_text.replace(SPICE_REFINERY_ROW1_TOKEN, "")
	cleaned_text = cleaned_text.strip_edges()
	cleaned_text = cleaned_text.replace("; ;", ";").strip_edges()
	if cleaned_text.begins_with(";"):
		cleaned_text = cleaned_text.substr(1).strip_edges()
	if cleaned_text.ends_with(";"):
		cleaned_text = cleaned_text.left(cleaned_text.length() - 1).strip_edges()

	container.add_theme_constant_override("separation", 6)

	if has_influence_icon:
		_add_texture_icon(container, INFLUENCE_ICON_PATH, _scale_size(Vector2(34, 34), icon_scale))
	if has_influence2_icon:
		_add_texture_icon(container, INFLUENCE2_ICON_PATH, _scale_size(Vector2(34, 34), icon_scale))
	if has_contract_icon:
		_add_texture_icon(container, CONTRACT_ICON_PATH, _scale_size(Vector2(68, 34), icon_scale))
	_add_repeat_icons(container, int(parsed_spy.get("count", 0)), SPY_ICON_PATH, _scale_size(Vector2(34, 34), icon_scale))
	_add_repeat_icons(container, int(parsed_recall_agent.get("count", 0)), RECALL_AGENT_ICON_PATH, _scale_size(Vector2(43, 43), icon_scale))
	_add_repeat_icons(container, int(parsed_get_agent.get("count", 0)), GET_AGENT_ICON_PATH, _scale_size(Vector2(43, 43), icon_scale))
	_add_repeat_icons(container, int(parsed_sword.get("count", 0)), SWORD_ICON_PATH, _scale_size(Vector2(34, 34), icon_scale))
	_add_repeat_icons(container, int(parsed_draw_cards.get("count", 0)), DRAW_CARD_ICON_PATH, _scale_size(Vector2(34, 34), icon_scale))
	_add_repeat_icons(container, int(parsed_vp.get("count", 0)), VP_ICON_PATH, _scale_size(Vector2(34, 34), icon_scale))
	_add_repeat_icons(container, int(parsed_intrigue.get("count", 0)), INTRIGUE_ICON_PATH, _scale_size(Vector2(34, 34), icon_scale))
	_add_repeat_icons(container, int(parsed_trash.get("count", 0)), TRASH_CARD_ICON_PATH, _scale_size(Vector2(34, 34), icon_scale))
	_add_repeat_icons(container, int(parsed_maker_hooks.get("count", 0)), MAKER_HOOKS_ICON_PATH, _scale_size(Vector2(34, 34), icon_scale))
	_add_repeat_icons(container, int(parsed_sand_worm.get("count", 0)), SAND_WORM_ICON_PATH, _scale_size(Vector2(34, 34), icon_scale))
	if bool(parsed_maker_worm_choice.get("has_choice", false)):
		container.add_child(_build_maker_worm_choice_box(
			int(parsed_maker_worm_choice.get("spice_amount", 0)),
			int(parsed_maker_worm_choice.get("worm_amount", 0)),
			icon_scale
		))
	if bool(parsed_sietch_tabr_second.get("has_option", false)):
		container.add_child(_build_sietch_tabr_second_option_box(
			int(parsed_sietch_tabr_second.get("water_amount", 0)),
			int(parsed_sietch_tabr_second.get("shield_wall_amount", 0)),
			icon_scale
		))
	if has_spice_refinery_trade:
		if strict_strip_mode:
			container.add_child(_build_cost_trade_box("spice", 1, "solari", 4, icon_scale))
		else:
			container.add_child(_build_spice_refinery_trade_box(icon_scale))
	if has_spice_refinery_row0:
		if strict_strip_mode:
			container.add_child(_build_cost_trade_box("spice", 0, "solari", 2, icon_scale))
		else:
			container.add_child(_build_spice_refinery_row0(icon_scale))
	if has_spice_refinery_row1:
		if strict_strip_mode:
			container.add_child(_build_cost_trade_box("spice", 1, "solari", 4, icon_scale))
		else:
			container.add_child(_build_spice_refinery_row1(icon_scale))
	if has_gather_support_trade:
		if strict_strip_mode:
			container.add_child(_build_cost_trade_box("solari", 2, "troops", 2, icon_scale))
		else:
			container.add_child(build_gather_support_trade_box(icon_scale))
	if has_gather_support_row0:
		if strict_strip_mode:
			container.add_child(_build_cost_trade_box("solari", 0, "troops", 2, icon_scale))
		else:
			container.add_child(_build_gather_support_row0(icon_scale))
	if has_gather_support_row1:
		if strict_strip_mode:
			container.add_child(_build_cost_trade_box("solari", 2, "water", 1, icon_scale))
		else:
			container.add_child(_build_gather_support_row1(icon_scale))
	var cost_trades: Variant = parsed_cost_trades.get("trades", [])
	if typeof(cost_trades) == TYPE_ARRAY:
		for trade in cost_trades:
			if typeof(trade) != TYPE_DICTIONARY:
				continue
			container.add_child(_build_cost_trade_box(
				str(trade.get("pay_type", "")),
				int(trade.get("pay_amount", 0)),
				str(trade.get("gain_type", "")),
				int(trade.get("gain_amount", 0)),
				icon_scale
			))
	if bool(parsed_high_council_choice.get("has_choice", false)):
		container.add_child(_build_high_council_choice_box(
			int(parsed_high_council_choice.get("gain_solari", 0)),
			int(parsed_high_council_choice.get("pay_solari", 0)),
			icon_scale,
			strict_strip_mode
		))
	var control_entries: Variant = parsed_control_icons.get("entries", [])
	if typeof(control_entries) == TYPE_ARRAY:
		for _entry in control_entries:
			_add_texture_icon(container, CONTROL_ICON_PATH, _scale_size(Vector2(42, 42), icon_scale))
	var influence_choice_factions: Variant = parsed_influence_choice_set.get("factions", [])
	if typeof(influence_choice_factions) == TYPE_ARRAY and not influence_choice_factions.is_empty():
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 4)
		container.add_child(row)
		for faction_value in influence_choice_factions:
			var path := _resolve_influence_choice_icon_path(str(faction_value))
			if path == "":
				continue
			_add_texture_icon(row, path, _scale_size(Vector2(36, 36), icon_scale))
	var single_influence_faction := str(parsed_single_influence_choice.get("faction", ""))
	if single_influence_faction != "":
		var single_path := _resolve_influence_choice_icon_path(single_influence_faction)
		if single_path != "":
			_add_texture_icon(container, single_path, _scale_size(Vector2(40, 40), icon_scale))
	if bool(parsed_solari.get("has_badge", false)):
		_add_numeric_badge(container, SOLARI_ICON_PATH, int(parsed_solari.get("amount", 0)), icon_scale)
	if bool(parsed_persuasion.get("has_badge", false)):
		_add_numeric_badge(container, PERSUASION_ICON_PATH, int(parsed_persuasion.get("amount", 0)), icon_scale)
	if bool(parsed_maker_collect_spice.get("has_badge", false)):
		_add_numeric_badge(container, SPICE_ICON_PATH, int(parsed_maker_collect_spice.get("amount", 0)), icon_scale)
	if bool(parsed_spice.get("has_badge", false)):
		_add_numeric_badge(container, SPICE_ICON_PATH, int(parsed_spice.get("amount", 0)), icon_scale)
	if bool(parsed_water.get("has_badge", false)):
		_add_numeric_badge(container, WATER_ICON_PATH, int(parsed_water.get("amount", 0)), icon_scale)
	if bool(parsed_troops.get("has_badge", false)):
		_add_numeric_badge(container, TROOPS_ICON_PATH, int(parsed_troops.get("amount", 0)), icon_scale)

	if cleaned_text != "" and not strict_strip_mode:
		var remainder := Label.new()
		remainder.text = cleaned_text
		remainder.autowrap_mode = TextServer.AUTOWRAP_OFF
		remainder.add_theme_font_size_override("font_size", int(round(12.0 * icon_scale)))
		container.add_child(remainder)

	if strict_strip_mode:
		container.alignment = BoxContainer.ALIGNMENT_BEGIN


static func build_gather_support_trade_box(icon_scale: float = 1.0) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.add_child(_build_gather_support_row0(icon_scale))
	box.add_child(_build_gather_support_row1(icon_scale))
	return box


static func _build_gather_support_row0(icon_scale: float = 1.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(_make_badge_pair(SOLARI_ICON_PATH, 0, icon_scale))
	row.add_child(_texture_rect(ARROW_ICON_PATH, _scale_size(Vector2(18, 18), icon_scale)))
	row.add_child(_make_badge_pair(TROOPS_ICON_PATH, 2, icon_scale))
	return row


static func _build_gather_support_row1(icon_scale: float = 1.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(_make_badge_pair(SOLARI_ICON_PATH, 2, icon_scale))
	row.add_child(_texture_rect(ARROW_ICON_PATH, _scale_size(Vector2(18, 18), icon_scale)))
	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.add_child(_make_badge_pair(TROOPS_ICON_PATH, 2, icon_scale))
	right.add_child(_make_badge_pair(WATER_ICON_PATH, 1, icon_scale))
	row.add_child(right)
	return row


static func _build_spice_refinery_trade_box(icon_scale: float = 1.0) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var row0 := _build_spice_refinery_row0(icon_scale)
	var row1 := _build_spice_refinery_row1(icon_scale)
	box.add_child(row0)
	box.add_child(row1)
	return box


static func _build_spice_refinery_row0(icon_scale: float = 1.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(_make_badge_pair(SPICE_ICON_PATH, 0, icon_scale))
	row.add_child(_texture_rect(ARROW_ICON_PATH, _scale_size(Vector2(18, 18), icon_scale)))
	row.add_child(_make_badge_pair(SOLARI_ICON_PATH, 2, icon_scale))
	return row


static func _build_spice_refinery_row1(icon_scale: float = 1.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(_make_badge_pair(SPICE_ICON_PATH, 1, icon_scale))
	row.add_child(_texture_rect(ARROW_ICON_PATH, _scale_size(Vector2(18, 18), icon_scale)))
	row.add_child(_make_badge_pair(SOLARI_ICON_PATH, 4, icon_scale))
	return row

static func _build_cost_trade_box(
	pay_type: String,
	pay_amount: int,
	gain_type: String,
	gain_amount: int,
	icon_scale: float = 1.0
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var left := _build_trade_side(pay_type, pay_amount, icon_scale)
	if left != null:
		row.add_child(left)
	row.add_child(_texture_rect(ARROW_ICON_PATH, _scale_size(Vector2(18, 18), icon_scale)))
	var right := _build_trade_side(gain_type, gain_amount, icon_scale)
	if right != null:
		row.add_child(right)
	return row

static func _build_high_council_choice_box(
	gain_solari: int,
	pay_solari: int,
	icon_scale: float = 1.0,
	strict_strip_mode: bool = false
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(_make_badge_pair(SOLARI_ICON_PATH, maxi(gain_solari, 1), icon_scale))
	var or_label := Label.new()
	or_label.text = "OR"
	or_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	or_label.add_theme_font_size_override("font_size", int(round(11.0 * icon_scale)))
	row.add_child(or_label)
	row.add_child(_make_badge_pair(SOLARI_ICON_PATH, maxi(pay_solari, 1), icon_scale))
	row.add_child(_texture_rect(ARROW_ICON_PATH, _scale_size(Vector2(18, 18), icon_scale)))
	var text_label := Label.new()
	if strict_strip_mode:
		text_label.text = "High Council seat"
	else:
		text_label.text = "Take your seat on the High Council (if you haven't already)."
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.add_theme_font_size_override("font_size", int(round(11.0 * icon_scale)))
	text_label.clip_text = strict_strip_mode
	row.add_child(text_label)
	return row

static func _build_trade_side(kind: String, amount: int, icon_scale: float = 1.0) -> Control:
	match kind:
		"solari":
			return _make_badge_pair(SOLARI_ICON_PATH, amount, icon_scale)
		"spice":
			return _make_badge_pair(SPICE_ICON_PATH, amount, icon_scale)
		"water":
			return _make_badge_pair(WATER_ICON_PATH, amount, icon_scale)
		"recall_spy":
			return _make_badge_pair(RECALL_SPY_ICON_PATH, amount, icon_scale)
		"influence":
			if amount <= 1:
				return _texture_rect(INFLUENCE_ICON_PATH, _scale_size(Vector2(34, 34), icon_scale))
			return _make_badge_pair(INFLUENCE_ICON_PATH, amount, icon_scale)
		"vp":
			return _texture_rect(VP_ICON_PATH, _scale_size(Vector2(34, 34), icon_scale))
		_:
			var fallback := Label.new()
			fallback.text = "%d %s" % [amount, kind]
			fallback.add_theme_font_size_override("font_size", int(round(12.0 * icon_scale)))
			return fallback


static func _build_maker_worm_choice_box(spice_amount: int, worm_amount: int, icon_scale: float = 1.0) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var row_spice := HBoxContainer.new()
	row_spice.add_theme_constant_override("separation", 4)
	row_spice.add_child(_make_badge_pair(SPICE_ICON_PATH, spice_amount, icon_scale))
	var row_worm := HBoxContainer.new()
	row_worm.add_theme_constant_override("separation", 4)
	_add_repeat_icons(row_worm, worm_amount, SAND_WORM_ICON_PATH, _scale_size(Vector2(34, 34), icon_scale))
	box.add_child(row_spice)
	box.add_child(row_worm)
	return box


static func _build_sietch_tabr_second_option_box(
	water_amount: int,
	shield_wall_amount: int,
	icon_scale: float = 1.0
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(_make_badge_pair(WATER_ICON_PATH, water_amount, icon_scale))
	_add_repeat_icons(row, shield_wall_amount, SHIELD_WALL_ICON_PATH, _scale_size(Vector2(34, 34), icon_scale))
	return row


static func _make_badge_pair(icon_path: String, amount: int, icon_scale: float = 1.0) -> Control:
	return _badge_control(
		icon_path,
		amount,
		_scale_size(Vector2(24, 24), icon_scale),
		int(round(12.0 * icon_scale))
	)


static func _badge_control(icon_path: String, amount: int, min_size: Vector2, font_size: int) -> Control:
	var badge := Control.new()
	badge.custom_minimum_size = min_size
	var tex := TextureRect.new()
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.texture = _get_cached_texture(icon_path)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.add_child(tex)
	var val := Label.new()
	val.set_anchors_preset(Control.PRESET_FULL_RECT)
	# For single-stack effects, do not paint numeric overlay on top of the icon.
	if absi(amount) == 1:
		val.text = ""
	else:
		val.text = str(amount)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val.mouse_filter = Control.MOUSE_FILTER_IGNORE
	val.add_theme_font_size_override("font_size", font_size)
	val.add_theme_color_override("font_color", Color(0.12, 0.12, 0.12, 1))
	badge.add_child(val)
	return badge


static func _add_numeric_badge(parent: HBoxContainer, icon_path: String, amount: int, icon_scale: float = 1.0) -> void:
	parent.add_child(
		_badge_control(
			icon_path,
			amount,
			_scale_size(Vector2(34, 34), icon_scale),
			int(round(16.0 * icon_scale))
		)
	)


static func _add_texture_icon(parent: HBoxContainer, path: String, min_size: Vector2) -> void:
	parent.add_child(_texture_rect(path, min_size))


static func _texture_rect(path: String, min_size: Vector2) -> TextureRect:
	var texture_rect := TextureRect.new()
	texture_rect.custom_minimum_size = min_size
	texture_rect.texture = _get_cached_texture(path)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return texture_rect


static func _add_repeat_icons(
	parent: HBoxContainer,
	amount: int,
	texture_path: String,
	icon_size: Vector2 = Vector2(34, 34)
) -> void:
	if amount <= 0:
		return
	var tex: Texture2D = _get_cached_texture(texture_path)
	if tex == null:
		return
	for _i in range(amount):
		var icon := TextureRect.new()
		icon.custom_minimum_size = icon_size
		icon.texture = tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(icon)


static func _extract_solari_badge_value(text: String) -> Dictionary:
	return _extract_badge_value(text, SOLARI_BADGE_TOKEN_PREFIX)


static func _extract_persuasion_badge_value(text: String) -> Dictionary:
	return _extract_badge_value(text, PERSUASION_BADGE_TOKEN_PREFIX)


static func _extract_spice_badge_value(text: String) -> Dictionary:
	return _extract_badge_value(text, SPICE_BADGE_TOKEN_PREFIX)


static func _extract_water_badge_value(text: String) -> Dictionary:
	return _extract_badge_value(text, WATER_BADGE_TOKEN_PREFIX)


static func _extract_troops_badge_value(text: String) -> Dictionary:
	return _extract_badge_value(text, TROOPS_BADGE_TOKEN_PREFIX)


static func _extract_maker_worm_choice(text: String) -> Dictionary:
	var cleaned_text := text
	var token_start: int = cleaned_text.find(MAKER_WORM_CHOICE_TOKEN_PREFIX)
	if token_start < 0:
		return {
			"has_choice": false,
			"spice_amount": 0,
			"worm_amount": 0,
			"text": cleaned_text
		}
	var token_end: int = cleaned_text.find("]", token_start)
	if token_end < 0:
		return {
			"has_choice": false,
			"spice_amount": 0,
			"worm_amount": 0,
			"text": cleaned_text
		}
	var payload_start: int = token_start + MAKER_WORM_CHOICE_TOKEN_PREFIX.length()
	var payload: String = cleaned_text.substr(payload_start, token_end - payload_start)
	var parts: PackedStringArray = payload.split(":", false)
	if parts.size() != 2:
		return {
			"has_choice": false,
			"spice_amount": 0,
			"worm_amount": 0,
			"text": cleaned_text
		}
	var spice_amount := int(parts[0])
	var worm_amount := int(parts[1])
	cleaned_text = cleaned_text.substr(0, token_start) + cleaned_text.substr(token_end + 1)
	return {
		"has_choice": true,
		"spice_amount": spice_amount,
		"worm_amount": worm_amount,
		"text": cleaned_text
	}


static func _extract_sietch_tabr_second_option(text: String) -> Dictionary:
	var cleaned_text := text
	var token_start: int = cleaned_text.find(SIETCH_TABR_SECOND_OPTION_TOKEN_PREFIX)
	if token_start < 0:
		return {
			"has_option": false,
			"water_amount": 0,
			"shield_wall_amount": 0,
			"text": cleaned_text
		}
	var token_end: int = cleaned_text.find("]", token_start)
	if token_end < 0:
		return {
			"has_option": false,
			"water_amount": 0,
			"shield_wall_amount": 0,
			"text": cleaned_text
		}
	var payload_start: int = token_start + SIETCH_TABR_SECOND_OPTION_TOKEN_PREFIX.length()
	var payload: String = cleaned_text.substr(payload_start, token_end - payload_start)
	var parts: PackedStringArray = payload.split(":", false)
	if parts.size() != 2:
		return {
			"has_option": false,
			"water_amount": 0,
			"shield_wall_amount": 0,
			"text": cleaned_text
		}
	var water_amount := int(parts[0])
	var shield_wall_amount := int(parts[1])
	cleaned_text = cleaned_text.substr(0, token_start) + cleaned_text.substr(token_end + 1)
	return {
		"has_option": true,
		"water_amount": water_amount,
		"shield_wall_amount": shield_wall_amount,
		"text": cleaned_text
	}


static func _extract_badge_value(text: String, token_prefix: String) -> Dictionary:
	var cleaned_text := text
	var total_amount := 0
	var has_badge := false

	while true:
		var token_start: int = cleaned_text.find(token_prefix)
		if token_start < 0:
			break
		var token_end: int = cleaned_text.find("]", token_start)
		if token_end < 0:
			break

		var amount_start: int = token_start + token_prefix.length()
		var amount_text: String = cleaned_text.substr(amount_start, token_end - amount_start)
		total_amount += int(amount_text)
		has_badge = true
		cleaned_text = cleaned_text.substr(0, token_start) + cleaned_text.substr(token_end + 1)

	return {
		"has_badge": has_badge,
		"amount": total_amount,
		"text": cleaned_text
	}

static func _extract_cost_trades(text: String) -> Dictionary:
	var cleaned_text := text
	var trades: Array = []
	while true:
		var token_start: int = cleaned_text.find(COST_TRADE_TOKEN_PREFIX)
		if token_start < 0:
			break
		var token_end: int = cleaned_text.find("]", token_start)
		if token_end < 0:
			break
		var payload_start: int = token_start + COST_TRADE_TOKEN_PREFIX.length()
		var payload: String = cleaned_text.substr(payload_start, token_end - payload_start)
		var parts: PackedStringArray = payload.split(":", false)
		if parts.size() == 4:
			trades.append({
				"pay_type": str(parts[0]).strip_edges(),
				"pay_amount": int(parts[1]),
				"gain_type": str(parts[2]).strip_edges(),
				"gain_amount": int(parts[3])
			})
		cleaned_text = cleaned_text.substr(0, token_start) + cleaned_text.substr(token_end + 1)
	return {
		"trades": trades,
		"text": cleaned_text
	}

static func _extract_high_council_choice(text: String) -> Dictionary:
	var cleaned_text := text
	var token_start: int = cleaned_text.find(HIGH_COUNCIL_CHOICE_TOKEN_PREFIX)
	if token_start < 0:
		return {
			"has_choice": false,
			"gain_solari": 0,
			"pay_solari": 0,
			"text": cleaned_text
		}
	var token_end: int = cleaned_text.find("]", token_start)
	if token_end < 0:
		return {
			"has_choice": false,
			"gain_solari": 0,
			"pay_solari": 0,
			"text": cleaned_text
		}
	var payload_start: int = token_start + HIGH_COUNCIL_CHOICE_TOKEN_PREFIX.length()
	var payload: String = cleaned_text.substr(payload_start, token_end - payload_start)
	var parts: PackedStringArray = payload.split(":", false)
	if parts.size() != 2:
		return {
			"has_choice": false,
			"gain_solari": 0,
			"pay_solari": 0,
			"text": cleaned_text
		}
	var gain_solari := int(str(parts[0]).replace("gain", ""))
	var pay_solari := int(str(parts[1]).replace("pay", ""))
	cleaned_text = cleaned_text.substr(0, token_start) + cleaned_text.substr(token_end + 1)
	return {
		"has_choice": true,
		"gain_solari": gain_solari,
		"pay_solari": pay_solari,
		"text": cleaned_text
	}

static func _extract_control_icons(text: String) -> Dictionary:
	var cleaned_text := text
	var entries: Array = []
	while true:
		var token_start: int = cleaned_text.find(CONTROL_ICON_TOKEN_PREFIX)
		if token_start < 0:
			break
		var token_end: int = cleaned_text.find("]", token_start)
		if token_end < 0:
			break
		var payload_start: int = token_start + CONTROL_ICON_TOKEN_PREFIX.length()
		var payload: String = cleaned_text.substr(payload_start, token_end - payload_start).strip_edges()
		entries.append({"boardSpaceId": payload})
		cleaned_text = cleaned_text.substr(0, token_start) + cleaned_text.substr(token_end + 1)
	while true:
		var flat_token_start: int = cleaned_text.find(CONTROL_ICON_TOKEN)
		if flat_token_start < 0:
			break
		entries.append({"boardSpaceId": ""})
		cleaned_text = cleaned_text.substr(0, flat_token_start) + cleaned_text.substr(flat_token_start + CONTROL_ICON_TOKEN.length())
	return {
		"entries": entries,
		"text": cleaned_text
	}

static func _extract_influence_choice_set(text: String) -> Dictionary:
	var cleaned_text := text
	var token_start: int = cleaned_text.find(INFLUENCE_CHOICE_SET_TOKEN_PREFIX)
	if token_start < 0:
		return {"factions": [], "text": cleaned_text}
	var token_end: int = cleaned_text.find("]", token_start)
	if token_end < 0:
		return {"factions": [], "text": cleaned_text}
	var payload_start: int = token_start + INFLUENCE_CHOICE_SET_TOKEN_PREFIX.length()
	var payload: String = cleaned_text.substr(payload_start, token_end - payload_start)
	var raw_parts: PackedStringArray = payload.split(",", false)
	var factions: Array[String] = []
	for raw in raw_parts:
		var faction := str(raw).strip_edges()
		if faction == "":
			continue
		factions.append(faction)
	cleaned_text = cleaned_text.substr(0, token_start) + cleaned_text.substr(token_end + 1)
	return {
		"factions": factions,
		"text": cleaned_text
	}

static func _extract_single_influence_choice(text: String) -> Dictionary:
	var cleaned_text := text
	var token_start: int = cleaned_text.find(FACTION_INFLUENCE_CHOICE_TOKEN_PREFIX)
	if token_start < 0:
		return {"faction": "", "text": cleaned_text}
	var token_end: int = cleaned_text.find("]", token_start)
	if token_end < 0:
		return {"faction": "", "text": cleaned_text}
	var payload_start: int = token_start + FACTION_INFLUENCE_CHOICE_TOKEN_PREFIX.length()
	var faction := cleaned_text.substr(payload_start, token_end - payload_start).strip_edges()
	cleaned_text = cleaned_text.substr(0, token_start) + cleaned_text.substr(token_end + 1)
	return {
		"faction": faction,
		"text": cleaned_text
	}

static func _resolve_influence_choice_icon_path(faction: String) -> String:
	match faction:
		"fremen":
			return FREMEN_INFLUENCE_ICON_PATH
		"emperor":
			return EMPEROR_INFLUENCE_ICON_PATH
		"guild":
			return GUILD_INFLUENCE_ICON_PATH
		"beneGesserit":
			return BENE_GESSERIT_INFLUENCE_ICON_PATH
		_:
			return ""


static func _strip_and_append_faction_icons(
	container: HBoxContainer,
	text: String,
	icon_scale: float = 1.0
) -> String:
	var work := text
	const PREFIX := "[faction_icon:"
	while true:
		var start: int = work.find(PREFIX)
		if start < 0:
			break
		var end: int = work.find("]", start)
		if end < 0:
			break
		var fac: String = work.substr(start + PREFIX.length(), end - start - PREFIX.length()).strip_edges()
		var path := _resolve_faction_icon_path(fac)
		if path != "":
			_add_texture_icon(container, path, _scale_size(Vector2(56, 56), icon_scale))
		work = work.substr(0, start) + work.substr(end + 1)
	return work

static func _strip_and_append_resource_word_icons(
	container: HBoxContainer,
	text: String,
	icon_scale: float = 1.0
) -> String:
	var work := text
	var resource_words := [
		{"word": "solari", "path": SOLARI_ICON_PATH},
		{"word": "spice", "path": SPICE_ICON_PATH},
		{"word": "water", "path": WATER_ICON_PATH},
		{"word": "troops", "path": TROOPS_ICON_PATH},
		{"word": "troop", "path": TROOPS_ICON_PATH},
		{"word": "influence", "path": INFLUENCE_ICON_PATH},
		{"word": "agent", "path": GET_AGENT_ICON_PATH}
	]
	for entry in resource_words:
		var word := str(entry.get("word", ""))
		var path := str(entry.get("path", ""))
		if word == "" or path == "":
			continue
		while true:
			var marker := _find_standalone_word(work, word)
			var start := int(marker.get("start", -1))
			var end := int(marker.get("end", -1))
			if start < 0 or end < 0:
				break
			_add_texture_icon(container, path, _scale_size(Vector2(34, 34), icon_scale))
			work = work.substr(0, start) + work.substr(end)
	return work

static func _is_word_boundary(ch: String) -> bool:
	if ch == "":
		return true
	var code := ch.unicode_at(0)
	var is_digit := code >= 48 and code <= 57
	var is_upper := code >= 65 and code <= 90
	var is_lower := code >= 97 and code <= 122
	var is_underscore := ch == "_"
	return not (is_digit or is_upper or is_lower or is_underscore)

static func _find_standalone_word(text: String, word: String) -> Dictionary:
	if text == "" or word == "":
		return {"start": -1, "end": -1}
	var lower_text := text.to_lower()
	var lower_word := word.to_lower()
	var from := 0
	while true:
		var idx := lower_text.find(lower_word, from)
		if idx < 0:
			return {"start": -1, "end": -1}
		var before_char := ""
		if idx > 0:
			before_char = lower_text.substr(idx - 1, 1)
		var after_pos := idx + lower_word.length()
		var after_char := ""
		if after_pos < lower_text.length():
			after_char = lower_text.substr(after_pos, 1)
		if _is_word_boundary(before_char) and _is_word_boundary(after_char):
			return {"start": idx, "end": after_pos}
		from = idx + 1
	return {"start": -1, "end": -1}


static func _scale_size(size: Vector2, icon_scale: float) -> Vector2:
	var applied := clampf(icon_scale, 0.72, 1.0)
	# Keep a predictable footprint in dense rows.
	if applied < 0.999:
		applied *= 0.8
	return Vector2(maxf(1.0, size.x * applied), maxf(1.0, size.y * applied))

static func _trim_to_single_line_budget(container: HBoxContainer) -> void:
	if container == null:
		return
	var budget := container.size.x
	if budget <= 0.0 and container.get_parent_control() != null:
		budget = container.get_parent_control().size.x
	if budget <= 0.0:
		budget = 88.0
	budget = maxf(42.0, budget)
	while _measure_container_width(container) > budget and container.get_child_count() > 0:
		var last := container.get_child(container.get_child_count() - 1)
		container.remove_child(last)
		last.free()

static func _measure_container_width(container: HBoxContainer) -> float:
	var total := 0.0
	var sep := float(container.get_theme_constant("separation"))
	for idx in range(container.get_child_count()):
		var child := container.get_child(idx)
		total += _measure_node_width(child)
		if idx < container.get_child_count() - 1:
			total += sep
	return total

static func _measure_node_width(node: Node) -> float:
	if node is Control:
		var control := node as Control
		if control.custom_minimum_size.x > 0.0:
			return control.custom_minimum_size.x
		if control.size.x > 0.0:
			return control.size.x
		if control is Label:
			var label := control as Label
			return maxf(float(label.text.length()) * 6.0, 10.0)
	return 10.0


static func _resolve_faction_icon_path(faction: String) -> String:
	var base := "res://data/icons/"
	var stem := ""
	match faction:
		"emperor":
			stem = "emperor"
		"guild":
			stem = "spacing_guild"
		"beneGesserit":
			stem = "bene_gesserit"
		"fremen":
			stem = "fremen"
		_:
			return ""
	for ext in [".png", ".jpeg", ".jpg"]:
		var p: String = base + stem + ext
		if ResourceLoader.exists(p):
			return p
	return ""


static func _extract_token_count(text: String, token: String) -> Dictionary:
	var cleaned_text := text
	var count := 0
	while true:
		var token_start: int = cleaned_text.find(token)
		if token_start < 0:
			break
		count += 1
		cleaned_text = cleaned_text.substr(0, token_start) + cleaned_text.substr(token_start + token.length())
	return {
		"count": count,
		"text": cleaned_text
	}

static func _get_cached_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if _texture_cache.has(path):
		return _texture_cache[path] as Texture2D
	var texture := load(path) as Texture2D
	_texture_cache[path] = texture
	return texture
