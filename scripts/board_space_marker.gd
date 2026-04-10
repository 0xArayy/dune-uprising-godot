extends Node2D
class_name BoardSpaceMarker

var board_space_id = ""
var slot_size = Vector2(220.0, 110.0)
var display_name = ""
var area_id = ""
var effects_text = ""
var required_icons: Array = []
var icon_size = Vector2(24.0, 24.0)
var icon_dir = "res://data/icons/"
var highlight_modulate = Color(1.0, 0.96, 0.78, 1.0)
var occupied_modulate = Color(0.58, 0.62, 0.68, 1.0)
var normal_modulate = Color(1.0, 1.0, 1.0, 1.0)
const INFLUENCE_ICON_TOKEN := "[influence_icon]"
const CONTRACT_ICON_TOKEN := "[contract_icon]"
const SPY_ICON_TOKEN := "[spy_icon]"
const RECALL_AGENT_ICON_TOKEN := "[recall_agent_icon]"
const GET_AGENT_ICON_TOKEN := "[get_agent_icon]"
const DRAW_CARD_ICON_TOKEN := "[draw_card_icon]"
const INTRIGUE_ICON_TOKEN := "[intrigue_icon]"
const TRASH_CARD_ICON_TOKEN := "[trash_card_icon]"
const MAKER_HOOKS_ICON_TOKEN := "[maker_hooks_icon]"
const MAKER_WORM_CHOICE_TOKEN_PREFIX := "[maker_worm_choice:"
const SIETCH_TABR_SECOND_OPTION_TOKEN_PREFIX := "[sietch_tabr_second_option:"
const SPICE_REFINERY_TRADE_TOKEN := "[spice_refinery_trade]"
const GATHER_SUPPORT_TRADE_TOKEN := "[gather_support_trade]"
const HIGH_COUNCIL_FIRST_TOKEN := "[high_council_1st]"
const HIGH_COUNCIL_REPEAT_DIM_TOKEN := "[hc_repeat_dim]"
const HIGH_COUNCIL_REPEAT_BRIGHT_TOKEN := "[hc_repeat_bright]"
const SOLARI_BADGE_TOKEN_PREFIX := "[solari_badge:"
const PERSUASION_BADGE_TOKEN_PREFIX := "[persuasion_badge:"
const SPICE_BADGE_TOKEN_PREFIX := "[spice_badge:"
const WATER_BADGE_TOKEN_PREFIX := "[water_badge:"
const TROOPS_BADGE_TOKEN_PREFIX := "[troops_badge:"
const DRAW_CARD_ICON_PATH := "res://data/icons/draw_card.png"
const INTRIGUE_ICON_PATH := "res://data/icons/intrigue.png"
const TRASH_CARD_ICON_PATH := "res://data/icons/trash_card.png"
const MAKER_HOOKS_ICON_PATH := "res://data/icons/maker_hooks.png"
const SPY_ICON_PATH := "res://data/icons/spy.png"
const RECALL_AGENT_ICON_PATH := "res://data/icons/recall_agent.png"
const GET_AGENT_ICON_PATH := "res://data/icons/get_agent.png"
const PERSUASION_ICON_PATH := "res://data/icons/persuasion.png"
const CONTROL_ICON_PATH := "res://data/icons/control.png"
const CONTROL_MARKER_OFFSET := Vector2(-86, 74)
const CONTROL_MARKER_TARGET_SIZE := 56.0
const CONTROL_BONUS_BADGE_OFFSET := Vector2(-68, 74)
const CONTROL_BONUS_BADGE_SIZE := Vector2(22, 22)
const CONTROL_BONUS_SOLARI_ICON_PATH := "res://data/icons/solari.png"
const CONTROL_BONUS_SPICE_ICON_PATH := "res://data/icons/resource_spice.png"
const CONFLICT_ICON_PATH := "res://data/icons/sword.png"
const CONFLICT_ICON_OFFSET := Vector2(92, -43)
const CONFLICT_ICON_TARGET_SIZE := 30.0

var occupant_id = ""
var occupant_ids: Array = []
var occupant_colors: Array = []
var highlighted = false
@onready var root_frame: PanelContainer = $RootFrame
@onready var inner_frame: PanelContainer = $RootFrame/InnerFrame
@onready var effects_block: PanelContainer = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock
@onready var area_label: Label = $RootFrame/InnerFrame/ContentMargin/ContentRow/LeftContent/AreaLabel
@onready var name_label: Label = $RootFrame/InnerFrame/ContentMargin/ContentRow/LeftContent/NameLabel
@onready var occupant_agent_icon: TextureRect = $RootFrame/InnerFrame/ContentMargin/ContentRow/LeftContent/OccupantAgentIcon
@onready var cost_icons_row: HBoxContainer = $RootFrame/InnerFrame/ContentMargin/ContentRow/LeftContent/CostIconsRow
@onready var cost_solari_badge: Control = $RootFrame/InnerFrame/ContentMargin/ContentRow/LeftContent/CostIconsRow/SolariBadge
@onready var cost_solari_value: Label = $RootFrame/InnerFrame/ContentMargin/ContentRow/LeftContent/CostIconsRow/SolariBadge/BadgeValue
@onready var cost_spice_badge: Control = $RootFrame/InnerFrame/ContentMargin/ContentRow/LeftContent/CostIconsRow/SpiceBadge
@onready var cost_spice_value: Label = $RootFrame/InnerFrame/ContentMargin/ContentRow/LeftContent/CostIconsRow/SpiceBadge/BadgeValue
@onready var cost_water_badge: Control = $RootFrame/InnerFrame/ContentMargin/ContentRow/LeftContent/CostIconsRow/WaterBadge
@onready var cost_water_value: Label = $RootFrame/InnerFrame/ContentMargin/ContentRow/LeftContent/CostIconsRow/WaterBadge/BadgeValue
@onready var effects_label: Label = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/EffectsLabel
@onready var influence_icon: TextureRect = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/EffectIconsRow/InfluenceIcon
@onready var contract_icon: TextureRect = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/EffectIconsRow/ContractIcon
var control_marker_sprite: Sprite2D = null
var control_bonus_badge: Control = null
var control_bonus_icon: TextureRect = null
var control_bonus_value: Label = null
var conflict_space_icon_sprite: Sprite2D = null
@onready var spy_icons: HBoxContainer = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/EffectIconsRow/SpyIcons
@onready var recall_agent_icons: HBoxContainer = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/EffectIconsRow/RecallAgentIcons
@onready var get_agent_icons: HBoxContainer = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/EffectIconsRow/GetAgentIcons
@onready var draw_cards_icons: HBoxContainer = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/EffectIconsRow/DrawCardsIcons
@onready var intrigue_icons: HBoxContainer = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/EffectIconsRow/IntrigueIcons
@onready var trash_card_icons: HBoxContainer = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/EffectIconsRow/TrashCardIcons
@onready var maker_hooks_icons: HBoxContainer = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/EffectIconsRow/MakerHooksIcons
@onready var spice_refinery_trade_box: VBoxContainer = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/SpiceRefineryTradeBox
@onready var gather_support_trade_box: VBoxContainer = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/GatherSupportTradeBox
@onready var maker_worm_choice_box: VBoxContainer = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/MakerWormChoiceBox
@onready var maker_worm_icons: HBoxContainer = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/MakerWormChoiceBox/RowWorm/WormIcons
@onready var sietch_tabr_second_option_box: VBoxContainer = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/SietchTabrSecondOptionBox
@onready var sietch_tabr_water_value: Label = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/SietchTabrSecondOptionBox/RowSecond/WaterGain/BadgeValue
@onready var sietch_tabr_worm_icons: HBoxContainer = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/SietchTabrSecondOptionBox/RowSecond/WormIcons
@onready var effect_icons_row: HBoxContainer = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/EffectIconsRow
@onready var high_council_first_row: HBoxContainer = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/HighCouncilFirstRow
@onready var high_council_second_prefix: Label = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/HighCouncilSecondPrefix
@onready var solari_badge: Control = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/EffectIconsRow/SolariBadge
@onready var solari_badge_value: Label = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/EffectIconsRow/SolariBadge/BadgeValue
@onready var persuasion_badge: Control = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/EffectIconsRow/PersuasionBadge
@onready var persuasion_badge_value: Label = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/EffectIconsRow/PersuasionBadge/BadgeValue
@onready var spice_badge: Control = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/EffectIconsRow/SpiceBadge
@onready var spice_badge_value: Label = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/EffectIconsRow/SpiceBadge/BadgeValue
@onready var water_badge: Control = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/EffectIconsRow/WaterBadge
@onready var water_badge_value: Label = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/EffectIconsRow/WaterBadge/BadgeValue
@onready var troops_badge: Control = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/EffectIconsRow/TroopsBadge
@onready var troops_badge_value: Label = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/EffectIconsRow/TroopsBadge/BadgeValue
@onready var maker_spice_row: HBoxContainer = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/MakerSpiceRow
@onready var maker_base_spice_value: Label = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/MakerSpiceRow/BaseSpiceBadge/BadgeValue
@onready var maker_plus_label: Label = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/MakerSpiceRow/PlusLabel
@onready var maker_icon: TextureRect = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/MakerSpiceRow/MakerIcon
@onready var maker_pool_spice_badge: Control = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/MakerSpiceRow/PoolSpiceBadge
@onready var maker_pool_spice_value: Label = $RootFrame/InnerFrame/ContentMargin/ContentRow/EffectsBlock/EffectsMargin/EffectsVBox/MakerSpiceRow/PoolSpiceBadge/BadgeValue
@onready var required_icons_row: HBoxContainer = $RequiredIcons
var occupant_icons_row: HBoxContainer = null

func _ready():
	if board_space_id == "" or board_space_id == "board_space_1":
		board_space_id = str(name)
	if display_name == "":
		display_name = _humanize_space_id(board_space_id)
	_update_name_label()
	_update_area_label()
	_refresh_required_icons()
	_apply_area_visual_theme()
	_setup_occupant_icons_row()
	_ensure_control_marker_sprite()
	_ensure_conflict_space_icon_sprite()
	_ensure_control_bonus_badge()
	_refresh_visual_state()
	# Used by `BoardMap` to find and update all markers.
	add_to_group("board_space_markers")

func set_occupant_id(new_occupant_id):
	occupant_ids = []
	occupant_colors = []
	occupant_id = ""
	if new_occupant_id != null:
		occupant_id = str(new_occupant_id)
		if occupant_id != "":
			occupant_ids.append(occupant_id)
	_refresh_visual_state()
	_refresh_occupant_icons()

func clear_occupant():
	occupant_ids = []
	occupant_colors = []
	occupant_id = ""
	set_occupant_player_color(Color(1, 1, 1, 1), false)
	_refresh_visual_state()
	_refresh_occupant_icons()

func set_occupant_player_color(player_color: Color, visible_value: bool) -> void:
	if occupant_agent_icon == null or (occupant_icons_row != null and occupant_icons_row != occupant_agent_icon.get_parent()):
		return
	occupant_agent_icon.visible = visible_value
	occupant_agent_icon.modulate = player_color

func set_occupants(new_occupant_ids: Array, new_occupant_colors: Array = []) -> void:
	occupant_ids = []
	for value in new_occupant_ids:
		var id := str(value)
		if id != "":
			occupant_ids.append(id)
	occupant_colors = []
	if typeof(new_occupant_colors) == TYPE_ARRAY:
		for value in new_occupant_colors:
			if typeof(value) == TYPE_COLOR:
				occupant_colors.append(value)
	occupant_id = str(occupant_ids[0]) if not occupant_ids.is_empty() else ""
	_refresh_visual_state()
	_refresh_occupant_icons()

func set_highlighted(value: bool):
	highlighted = value
	_refresh_visual_state()

func set_display_name(new_display_name: String) -> void:
	display_name = new_display_name.strip_edges()
	if display_name == "":
		display_name = _humanize_space_id(board_space_id)
	_update_name_label()

func set_area(new_area_id: String) -> void:
	area_id = new_area_id
	_update_area_label()
	_apply_area_visual_theme()

func _apply_area_visual_theme() -> void:
	if root_frame == null or inner_frame == null or effects_block == null:
		return

	var theme := _get_area_theme(area_id)
	var outer_style := root_frame.get_theme_stylebox("panel")
	var inner_style := inner_frame.get_theme_stylebox("panel")
	var effects_style := effects_block.get_theme_stylebox("panel")
	if outer_style is StyleBoxFlat:
		var outer := (outer_style as StyleBoxFlat).duplicate()
		outer.bg_color = Color(0, 0, 0, 0)
		outer.border_color = theme.get("outer_border", Color(0.73, 0.69, 0.56, 1.0))
		root_frame.add_theme_stylebox_override("panel", outer)
	if inner_style is StyleBoxFlat:
		var inner := (inner_style as StyleBoxFlat).duplicate()
		inner.bg_color = theme.get("inner_bg", Color(0.2, 0.18, 0.15, 0.94))
		inner.border_color = theme.get("inner_border", Color(0.84, 0.76, 0.56, 0.9))
		inner_frame.add_theme_stylebox_override("panel", inner)
	if effects_style is StyleBoxFlat:
		var effects := (effects_style as StyleBoxFlat).duplicate()
		effects.bg_color = theme.get("effects_bg", Color(0.16, 0.15, 0.13, 0.94))
		effects.border_color = theme.get("effects_border", Color(0.83, 0.76, 0.58, 0.85))
		effects_block.add_theme_stylebox_override("panel", effects)

func _get_area_theme(area: String) -> Dictionary:
	# Faction/region tints keep spaces readable while matching Uprising's board mood.
	match area:
		"emperor":
			return {
				"outer_border": Color(0.58, 0.6, 0.64, 1.0),
				"inner_bg": Color(0.2, 0.22, 0.25, 0.95),
				"inner_border": Color(0.73, 0.76, 0.82, 0.9),
				"effects_bg": Color(0.17, 0.19, 0.22, 0.95),
				"effects_border": Color(0.67, 0.71, 0.78, 0.84)
			}
		"guild":
			return {
				"outer_border": Color(0.72, 0.38, 0.34, 1.0),
				"inner_bg": Color(0.29, 0.15, 0.14, 0.95),
				"inner_border": Color(0.85, 0.56, 0.52, 0.9),
				"effects_bg": Color(0.24, 0.12, 0.11, 0.95),
				"effects_border": Color(0.8, 0.5, 0.47, 0.84)
			}
		"beneGesserit":
			return {
				"outer_border": Color(0.61, 0.48, 0.62, 1.0),
				"inner_bg": Color(0.21, 0.16, 0.24, 0.95),
				"inner_border": Color(0.76, 0.62, 0.78, 0.9),
				"effects_bg": Color(0.18, 0.14, 0.2, 0.95),
				"effects_border": Color(0.7, 0.56, 0.73, 0.84)
			}
		"fremen":
			return {
				"outer_border": Color(0.46, 0.65, 0.78, 1.0),
				"inner_bg": Color(0.13, 0.22, 0.3, 0.95),
				"inner_border": Color(0.59, 0.8, 0.94, 0.9),
				"effects_bg": Color(0.11, 0.19, 0.26, 0.95),
				"effects_border": Color(0.54, 0.75, 0.9, 0.84)
			}
		"landsraad":
			return {
				"outer_border": Color(0.44, 0.64, 0.42, 1.0),
				"inner_bg": Color(0.14, 0.24, 0.14, 0.95),
				"inner_border": Color(0.61, 0.83, 0.58, 0.9),
				"effects_bg": Color(0.12, 0.2, 0.12, 0.95),
				"effects_border": Color(0.55, 0.78, 0.52, 0.84)
			}
		"city":
			return {
				"outer_border": Color(0.49, 0.62, 0.67, 1.0),
				"inner_bg": Color(0.14, 0.2, 0.22, 0.95),
				"inner_border": Color(0.63, 0.79, 0.83, 0.9),
				"effects_bg": Color(0.12, 0.17, 0.19, 0.95),
				"effects_border": Color(0.57, 0.74, 0.77, 0.84)
			}
		"spice":
			return {
				"outer_border": Color(0.72, 0.55, 0.35, 1.0),
				"inner_bg": Color(0.3, 0.2, 0.12, 0.95),
				"inner_border": Color(0.86, 0.67, 0.46, 0.9),
				"effects_bg": Color(0.25, 0.17, 0.1, 0.95),
				"effects_border": Color(0.82, 0.62, 0.41, 0.84)
			}
		_:
			return {
				"outer_border": Color(0.73, 0.69, 0.56, 1.0),
				"inner_bg": Color(0.2, 0.18, 0.15, 0.94),
				"inner_border": Color(0.84, 0.76, 0.56, 0.9),
				"effects_bg": Color(0.16, 0.15, 0.13, 0.94),
				"effects_border": Color(0.83, 0.76, 0.58, 0.85)
			}

func contains_global_point(point: Vector2) -> bool:
	if root_frame != null:
		return root_frame.get_global_rect().has_point(point)
	var half_size: Vector2 = slot_size * 0.5
	var local_point := to_local(point)
	return Rect2(-half_size, slot_size).has_point(local_point)

func _update_name_label() -> void:
	if name_label == null:
		return
	name_label.text = display_name

func set_maker_spice_state(is_maker_space: bool, base_spice: int, accumulated: int) -> void:
	if maker_spice_row == null:
		return
	if not is_maker_space or base_spice <= 0:
		maker_spice_row.visible = false
		return
	maker_spice_row.visible = true
	if maker_base_spice_value != null:
		maker_base_spice_value.text = str(base_spice)
	if accumulated <= 0:
		if maker_plus_label != null:
			maker_plus_label.visible = true
		if maker_icon != null:
			maker_icon.visible = true
		if maker_pool_spice_badge != null:
			maker_pool_spice_badge.visible = false
		if maker_pool_spice_value != null:
			maker_pool_spice_value.text = ""
	else:
		if maker_plus_label != null:
			maker_plus_label.visible = false
		if maker_icon != null:
			maker_icon.visible = false
		if maker_pool_spice_badge != null:
			maker_pool_spice_badge.visible = true
		if maker_pool_spice_value != null:
			maker_pool_spice_value.text = str(accumulated)

func set_effects_text(new_effects_text: String) -> void:
	effects_text = new_effects_text.strip_edges()
	if effects_label == null:
		return

	if effect_icons_row != null:
		effect_icons_row.modulate = Color(1, 1, 1, 1)

	var text_for_parsing: String = effects_text
	var has_high_council_first: bool = false
	var repeat_dim: bool = false
	var repeat_bright: bool = false

	if effects_text.find("\n") >= 0:
		var parts: PackedStringArray = effects_text.split("\n", false)
		if parts.size() >= 2:
			var top: String = parts[0].strip_edges()
			var bottom: String = parts[1].strip_edges()
			if top.find(HIGH_COUNCIL_FIRST_TOKEN) >= 0:
				has_high_council_first = true
				text_for_parsing = bottom
				repeat_dim = true

	if text_for_parsing.find(HIGH_COUNCIL_REPEAT_BRIGHT_TOKEN) >= 0:
		repeat_bright = true
		text_for_parsing = text_for_parsing.replace(HIGH_COUNCIL_REPEAT_BRIGHT_TOKEN, "").strip_edges()

	if repeat_dim:
		text_for_parsing = text_for_parsing.replace(HIGH_COUNCIL_REPEAT_DIM_TOKEN, "").strip_edges()

	if not has_high_council_first:
		has_high_council_first = effects_text.find(HIGH_COUNCIL_FIRST_TOKEN) >= 0

	if has_high_council_first and text_for_parsing.find(HIGH_COUNCIL_FIRST_TOKEN) >= 0:
		text_for_parsing = text_for_parsing.replace(HIGH_COUNCIL_FIRST_TOKEN, "").strip_edges()

	var has_influence_icon: bool = text_for_parsing.find(INFLUENCE_ICON_TOKEN) >= 0
	var has_contract_icon: bool = text_for_parsing.find(CONTRACT_ICON_TOKEN) >= 0
	var parsed_spy := _extract_token_count(text_for_parsing, SPY_ICON_TOKEN)
	var parsed_recall_agent := _extract_token_count(str(parsed_spy.get("text", "")), RECALL_AGENT_ICON_TOKEN)
	var parsed_get_agent := _extract_token_count(str(parsed_recall_agent.get("text", "")), GET_AGENT_ICON_TOKEN)
	var has_spice_refinery_trade: bool = text_for_parsing.find(SPICE_REFINERY_TRADE_TOKEN) >= 0
	var has_gather_support_trade: bool = text_for_parsing.find(GATHER_SUPPORT_TRADE_TOKEN) >= 0
	var parsed_draw_cards := _extract_token_count(str(parsed_get_agent.get("text", "")), DRAW_CARD_ICON_TOKEN)
	var parsed_intrigue := _extract_token_count(str(parsed_draw_cards.get("text", "")), INTRIGUE_ICON_TOKEN)
	var parsed_trash := _extract_token_count(str(parsed_intrigue.get("text", "")), TRASH_CARD_ICON_TOKEN)
	var parsed_maker_hooks := _extract_token_count(str(parsed_trash.get("text", "")), MAKER_HOOKS_ICON_TOKEN)
	var parsed_sietch_tabr_second := _extract_sietch_tabr_second_option(str(parsed_maker_hooks.get("text", "")))
	var parsed_maker_worm_choice := _extract_maker_worm_choice(str(parsed_sietch_tabr_second.get("text", "")))
	var parsed_solari := _extract_solari_badge_value(str(parsed_maker_worm_choice.get("text", "")))
	var parsed_persuasion := _extract_persuasion_badge_value(str(parsed_solari.get("text", "")))
	var parsed_spice := _extract_spice_badge_value(str(parsed_persuasion.get("text", "")))
	var parsed_water := _extract_water_badge_value(str(parsed_spice.get("text", "")))
	var parsed_troops := _extract_troops_badge_value(str(parsed_water.get("text", "")))
	var cleaned_text: String = str(parsed_troops.get("text", ""))
	cleaned_text = cleaned_text.replace(INFLUENCE_ICON_TOKEN, "")
	cleaned_text = cleaned_text.replace(CONTRACT_ICON_TOKEN, "")
	cleaned_text = cleaned_text.replace(DRAW_CARD_ICON_TOKEN, "")
	cleaned_text = cleaned_text.replace(SPICE_REFINERY_TRADE_TOKEN, "")
	cleaned_text = cleaned_text.replace(GATHER_SUPPORT_TRADE_TOKEN, "")
	cleaned_text = cleaned_text.replace(HIGH_COUNCIL_FIRST_TOKEN, "")
	cleaned_text = cleaned_text.replace(HIGH_COUNCIL_REPEAT_DIM_TOKEN, "")
	cleaned_text = cleaned_text.replace(HIGH_COUNCIL_REPEAT_BRIGHT_TOKEN, "")
	cleaned_text = cleaned_text.strip_edges()
	cleaned_text = cleaned_text.replace("; ;", ";").strip_edges()
	if cleaned_text.begins_with(";"):
		cleaned_text = cleaned_text.substr(1).strip_edges()
	if cleaned_text.ends_with(";"):
		cleaned_text = cleaned_text.left(cleaned_text.length() - 1).strip_edges()
	effects_label.text = cleaned_text
	effects_label.visible = cleaned_text != ""
	if influence_icon != null:
		influence_icon.visible = has_influence_icon
	if contract_icon != null:
		contract_icon.visible = has_contract_icon
	if spy_icons != null:
		_render_token_icon_row(spy_icons, int(parsed_spy.get("count", 0)), SPY_ICON_PATH)
	if recall_agent_icons != null:
		_render_token_icon_row(
			recall_agent_icons,
			int(parsed_recall_agent.get("count", 0)),
			RECALL_AGENT_ICON_PATH,
			Vector2(43, 43)
		)
	if get_agent_icons != null:
		_render_token_icon_row(
			get_agent_icons,
			int(parsed_get_agent.get("count", 0)),
			GET_AGENT_ICON_PATH,
			Vector2(43, 43)
		)
	if draw_cards_icons != null:
		_render_token_icon_row(draw_cards_icons, int(parsed_draw_cards.get("count", 0)), DRAW_CARD_ICON_PATH)
	if intrigue_icons != null:
		_render_token_icon_row(intrigue_icons, int(parsed_intrigue.get("count", 0)), INTRIGUE_ICON_PATH)
	if trash_card_icons != null:
		_render_token_icon_row(trash_card_icons, int(parsed_trash.get("count", 0)), TRASH_CARD_ICON_PATH)
	if maker_hooks_icons != null:
		_render_token_icon_row(maker_hooks_icons, int(parsed_maker_hooks.get("count", 0)), MAKER_HOOKS_ICON_PATH)
	if spice_refinery_trade_box != null:
		spice_refinery_trade_box.visible = has_spice_refinery_trade
	if gather_support_trade_box != null:
		gather_support_trade_box.visible = has_gather_support_trade
	if maker_worm_choice_box != null:
		var has_maker_worm_choice := bool(parsed_maker_worm_choice.get("has_choice", false))
		maker_worm_choice_box.visible = has_maker_worm_choice
		if has_maker_worm_choice:
			if maker_worm_icons != null:
				_render_token_icon_row(
					maker_worm_icons,
					int(parsed_maker_worm_choice.get("worm_amount", 0)),
					"res://data/icons/sand_worm.png"
				)
		else:
			if maker_worm_icons != null:
				_render_token_icon_row(maker_worm_icons, 0, "res://data/icons/sand_worm.png")
	if sietch_tabr_second_option_box != null:
		var has_sietch_tabr_second := bool(parsed_sietch_tabr_second.get("has_option", false))
		sietch_tabr_second_option_box.visible = has_sietch_tabr_second
		if has_sietch_tabr_second:
			if sietch_tabr_water_value != null:
				sietch_tabr_water_value.text = str(int(parsed_sietch_tabr_second.get("water_amount", 0)))
			if sietch_tabr_worm_icons != null:
				_render_token_icon_row(
					sietch_tabr_worm_icons,
					int(parsed_sietch_tabr_second.get("shield_wall_amount", 0)),
					"res://data/icons/shield_wall.png"
				)
		else:
			if sietch_tabr_water_value != null:
				sietch_tabr_water_value.text = ""
			if sietch_tabr_worm_icons != null:
				_render_token_icon_row(sietch_tabr_worm_icons, 0, "res://data/icons/shield_wall.png")
	if high_council_first_row != null:
		high_council_first_row.visible = has_high_council_first
	if high_council_second_prefix != null:
		high_council_second_prefix.visible = repeat_dim
	if effect_icons_row != null:
		if repeat_dim:
			effect_icons_row.modulate = Color(0.62, 0.64, 0.68, 1)
		elif repeat_bright:
			effect_icons_row.modulate = Color(1.12, 1.14, 1.2, 1)
		else:
			effect_icons_row.modulate = Color(1, 1, 1, 1)
	if solari_badge != null and solari_badge_value != null:
		var has_solari_badge := bool(parsed_solari.get("has_badge", false))
		solari_badge.visible = has_solari_badge
		if has_solari_badge:
			solari_badge_value.text = str(int(parsed_solari.get("amount", 0)))
		else:
			solari_badge_value.text = ""
	if persuasion_badge != null and persuasion_badge_value != null:
		var has_persuasion_badge := bool(parsed_persuasion.get("has_badge", false))
		persuasion_badge.visible = has_persuasion_badge
		if has_persuasion_badge:
			persuasion_badge_value.text = str(int(parsed_persuasion.get("amount", 0)))
		else:
			persuasion_badge_value.text = ""
	if spice_badge != null and spice_badge_value != null:
		var has_spice_badge := bool(parsed_spice.get("has_badge", false))
		spice_badge.visible = has_spice_badge
		if has_spice_badge:
			spice_badge_value.text = str(int(parsed_spice.get("amount", 0)))
		else:
			spice_badge_value.text = ""
	if water_badge != null and water_badge_value != null:
		var has_water_badge := bool(parsed_water.get("has_badge", false))
		water_badge.visible = has_water_badge
		if has_water_badge:
			water_badge_value.text = str(int(parsed_water.get("amount", 0)))
		else:
			water_badge_value.text = ""
	if troops_badge != null and troops_badge_value != null:
		var has_troops_badge := bool(parsed_troops.get("has_badge", false))
		troops_badge.visible = has_troops_badge
		if has_troops_badge:
			troops_badge_value.text = str(int(parsed_troops.get("amount", 0)))
		else:
			troops_badge_value.text = ""

func set_required_icons(new_required_icons: Array) -> void:
	required_icons = []
	for icon_id in new_required_icons:
		required_icons.append(str(icon_id))
	_refresh_required_icons()

func set_cost_items(cost_items: Array) -> void:
	if cost_icons_row == null:
		return

	var solari_cost := 0
	var spice_cost := 0
	var water_cost := 0

	for cost_item in cost_items:
		if typeof(cost_item) != TYPE_DICTIONARY:
			continue
		if str(cost_item.get("type", "")) != "resource":
			continue
		var amount := int(cost_item.get("amount", 0))
		var resource_id := str(cost_item.get("resource", ""))
		match resource_id:
			"solari":
				solari_cost += amount
			"spice":
				spice_cost += amount
			"water":
				water_cost += amount

	_set_cost_badge(cost_solari_badge, cost_solari_value, solari_cost)
	_set_cost_badge(cost_spice_badge, cost_spice_value, spice_cost)
	_set_cost_badge(cost_water_badge, cost_water_value, water_cost)
	cost_icons_row.visible = solari_cost > 0 or spice_cost > 0 or water_cost > 0

func _humanize_space_id(space_id: String) -> String:
	return space_id.replace("_", " ").capitalize()

func _update_area_label() -> void:
	if area_label == null:
		return
	area_label.visible = false

func _refresh_visual_state() -> void:
	if root_frame == null:
		return
	if highlighted:
		root_frame.modulate = highlight_modulate
		return
	if not occupant_ids.is_empty() or occupant_id != "":
		root_frame.modulate = occupied_modulate
		return
	root_frame.modulate = normal_modulate

func _setup_occupant_icons_row() -> void:
	if occupant_agent_icon == null:
		return
	var parent_node := occupant_agent_icon.get_parent()
	if parent_node == null:
		return
	occupant_icons_row = HBoxContainer.new()
	occupant_icons_row.name = "OccupantIconsRowRuntime"
	occupant_icons_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	occupant_icons_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	occupant_icons_row.add_theme_constant_override("separation", 2)
	parent_node.add_child(occupant_icons_row)
	parent_node.move_child(occupant_icons_row, occupant_agent_icon.get_index())
	occupant_agent_icon.visible = false

func _ensure_control_marker_sprite() -> void:
	if control_marker_sprite != null:
		return
	var tex := load(CONTROL_ICON_PATH) as Texture2D
	if tex == null:
		return
	control_marker_sprite = Sprite2D.new()
	control_marker_sprite.name = "ControlMarkerRuntime"
	control_marker_sprite.texture = tex
	control_marker_sprite.centered = true
	control_marker_sprite.position = CONTROL_MARKER_OFFSET
	var tex_size: Vector2 = tex.get_size()
	if tex_size.x > 0.0 and tex_size.y > 0.0:
		var target_scale := CONTROL_MARKER_TARGET_SIZE / maxf(tex_size.x, tex_size.y)
		control_marker_sprite.scale = Vector2.ONE * target_scale
	control_marker_sprite.visible = false
	add_child(control_marker_sprite)

func set_control_marker_visible(visible_value: bool) -> void:
	_ensure_control_marker_sprite()
	if control_marker_sprite != null:
		control_marker_sprite.visible = visible_value


func _ensure_conflict_space_icon_sprite() -> void:
	if conflict_space_icon_sprite != null:
		return
	var tex := load(CONFLICT_ICON_PATH) as Texture2D
	if tex == null:
		return
	conflict_space_icon_sprite = Sprite2D.new()
	conflict_space_icon_sprite.name = "ConflictSpaceIconRuntime"
	conflict_space_icon_sprite.texture = tex
	conflict_space_icon_sprite.centered = true
	conflict_space_icon_sprite.position = CONFLICT_ICON_OFFSET
	var tex_size: Vector2 = tex.get_size()
	if tex_size.x > 0.0 and tex_size.y > 0.0:
		var target_scale := CONFLICT_ICON_TARGET_SIZE / maxf(tex_size.x, tex_size.y)
		conflict_space_icon_sprite.scale = Vector2.ONE * target_scale
	conflict_space_icon_sprite.visible = false
	add_child(conflict_space_icon_sprite)


func set_conflict_space_marker_visible(visible_value: bool) -> void:
	_ensure_conflict_space_icon_sprite()
	if conflict_space_icon_sprite != null:
		conflict_space_icon_sprite.visible = visible_value

func set_control_marker_owner_color(owner_color: Color, has_owner: bool) -> void:
	_ensure_control_marker_sprite()
	if control_marker_sprite == null:
		return
	if has_owner:
		control_marker_sprite.modulate = owner_color
	else:
		control_marker_sprite.modulate = Color(1, 1, 1, 1)

func set_control_bonus(resource_id: String, amount: int, visible_value: bool) -> void:
	_ensure_control_bonus_badge()
	if control_bonus_badge == null or control_bonus_icon == null or control_bonus_value == null:
		return
	if not visible_value:
		control_bonus_badge.visible = false
		control_bonus_value.text = ""
		return
	var texture_path := ""
	if resource_id == "spice":
		texture_path = CONTROL_BONUS_SPICE_ICON_PATH
	elif resource_id == "solari":
		texture_path = CONTROL_BONUS_SOLARI_ICON_PATH
	if texture_path == "":
		control_bonus_badge.visible = false
		control_bonus_value.text = ""
		return
	control_bonus_icon.texture = load(texture_path) as Texture2D
	control_bonus_value.text = str(maxi(amount, 0))
	control_bonus_badge.visible = true

func _ensure_control_bonus_badge() -> void:
	if control_bonus_badge != null:
		return
	control_bonus_badge = Control.new()
	control_bonus_badge.name = "ControlBonusBadgeRuntime"
	control_bonus_badge.custom_minimum_size = CONTROL_BONUS_BADGE_SIZE
	control_bonus_badge.position = CONTROL_BONUS_BADGE_OFFSET
	control_bonus_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

	control_bonus_icon = TextureRect.new()
	control_bonus_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	control_bonus_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	control_bonus_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	control_bonus_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control_bonus_badge.add_child(control_bonus_icon)

	control_bonus_value = Label.new()
	control_bonus_value.set_anchors_preset(Control.PRESET_FULL_RECT)
	control_bonus_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	control_bonus_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	control_bonus_value.add_theme_font_size_override("font_size", 11)
	control_bonus_value.add_theme_color_override("font_color", Color(0.12, 0.12, 0.12, 1))
	control_bonus_badge.add_child(control_bonus_value)

	control_bonus_badge.visible = false
	add_child(control_bonus_badge)

func _refresh_occupant_icons() -> void:
	if occupant_icons_row == null:
		return
	for child in occupant_icons_row.get_children():
		child.queue_free()
	if occupant_ids.is_empty():
		occupant_icons_row.visible = false
		return
	var icon_texture: Texture2D = occupant_agent_icon.texture if occupant_agent_icon != null else null
	for i in range(occupant_ids.size()):
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(18, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = icon_texture
		if i < occupant_colors.size() and typeof(occupant_colors[i]) == TYPE_COLOR:
			icon.modulate = occupant_colors[i]
		else:
			icon.modulate = Color(1, 1, 1, 1)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		occupant_icons_row.add_child(icon)
	occupant_icons_row.visible = true

func _refresh_required_icons() -> void:
	if required_icons_row == null:
		return
	for child in required_icons_row.get_children():
		child.queue_free()

	for icon_id_raw in required_icons:
		var icon_id := _normalize_icon_id(icon_id_raw)
		var texture := _load_icon_texture(icon_id)
		if texture == null:
			continue
		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = icon_size
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.texture = texture
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		required_icons_row.add_child(icon_rect)

func _normalize_icon_id(icon_id: String) -> String:
	match icon_id:
		"guild":
			return "spacing_guild"
		"spice":
			return "spice_trade"
		"beneGesserit":
			return "bene_gesserit"
		_:
			return icon_id

func _load_icon_texture(icon_id: String) -> Texture2D:
	var png_path: String = icon_dir + icon_id + ".png"
	if ResourceLoader.exists(png_path):
		return load(png_path) as Texture2D

	var jpeg_path: String = icon_dir + icon_id + ".jpeg"
	if ResourceLoader.exists(jpeg_path):
		return load(jpeg_path) as Texture2D

	var jpg_path: String = icon_dir + icon_id + ".jpg"
	if ResourceLoader.exists(jpg_path):
		return load(jpg_path) as Texture2D

	return null

func _extract_solari_badge_value(text: String) -> Dictionary:
	return _extract_badge_value(text, SOLARI_BADGE_TOKEN_PREFIX)

func _extract_persuasion_badge_value(text: String) -> Dictionary:
	return _extract_badge_value(text, PERSUASION_BADGE_TOKEN_PREFIX)

func _extract_spice_badge_value(text: String) -> Dictionary:
	return _extract_badge_value(text, SPICE_BADGE_TOKEN_PREFIX)

func _extract_water_badge_value(text: String) -> Dictionary:
	return _extract_badge_value(text, WATER_BADGE_TOKEN_PREFIX)

func _extract_troops_badge_value(text: String) -> Dictionary:
	return _extract_badge_value(text, TROOPS_BADGE_TOKEN_PREFIX)

func _extract_maker_worm_choice(text: String) -> Dictionary:
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

func _extract_sietch_tabr_second_option(text: String) -> Dictionary:
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

func _extract_badge_value(text: String, token_prefix: String) -> Dictionary:
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

func _extract_token_count(text: String, token: String) -> Dictionary:
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

func _render_token_icon_row(
	container: HBoxContainer,
	amount: int,
	texture_path: String,
	token_icon_size: Vector2 = Vector2(34, 34)
) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	if amount <= 0:
		container.visible = false
		return
	var tex: Texture2D = load(texture_path) as Texture2D
	if tex == null:
		container.visible = false
		return
	for _i in range(amount):
		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = token_icon_size
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.texture = tex
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(icon_rect)
	container.visible = true

func _set_cost_badge(badge: Control, label: Label, amount: int) -> void:
	if badge == null or label == null:
		return
	badge.visible = amount > 0
	label.text = str(amount) if amount > 0 else ""
