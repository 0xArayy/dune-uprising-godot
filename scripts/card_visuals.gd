class_name CardVisuals
extends Control

@export var card_data: Dictionary : set = set_card_data

@onready var name_label: Label = %Name
@onready var cost_label: Label = %CostValue
@onready var icons_label: Label = $Panel/MainMargin/VBox/Icons
@onready var purchase_bonus_row: HBoxContainer = %PurchaseBonusOverlayRow
@onready var agent_icons_column: VBoxContainer = %AgentIconsColumn
@onready var agent_effect_label: Label = %AgentEffect
@onready var reveal_effect_label: Label = %RevealEffect
@onready var agent_effect_tokens_row: HBoxContainer = %AgentEffectTokens
@onready var reveal_effect_tokens_row: HBoxContainer = %RevealEffectTokens
@onready var agent_persuasion_badge: Control = %AgentPersuasionBadge
@onready var reveal_persuasion_badge: Control = %RevealPersuasionBadge
@onready var agent_persuasion_value: Label = %AgentPersuasionBadge/BadgeValue
@onready var reveal_persuasion_value: Label = %RevealPersuasionBadge/BadgeValue
@onready var agent_sword_icons: HBoxContainer = %AgentSwordIcons
@onready var reveal_sword_icons: HBoxContainer = %RevealSwordIcons
@onready var agent_draw_icons: HBoxContainer = %AgentDrawIcons
@onready var agent_intrigue_icons: HBoxContainer = %AgentIntrigueIcons
@onready var agent_trash_icons: HBoxContainer = %AgentTrashIcons
@onready var reveal_draw_icons: HBoxContainer = %RevealDrawIcons
@onready var reveal_intrigue_icons: HBoxContainer = %RevealIntrigueIcons
@onready var reveal_trash_icons: HBoxContainer = %RevealTrashIcons
@onready var agent_troops_badge: Control = %AgentTroopsBadge
@onready var agent_troops_value: Label = %AgentTroopsBadge/BadgeValue
@onready var reveal_troops_badge: Control = %RevealTroopsBadge
@onready var reveal_troops_value: Label = %RevealTroopsBadge/BadgeValue
@onready var agent_resource_badges: HBoxContainer = %AgentResourceBadges
@onready var reveal_resource_badges: HBoxContainer = %RevealResourceBadges

const ICON_DIR := "res://data/icons/"
const ICON_SIZE := Vector2(14, 14)
const SWORD_ICON_PATH := "res://data/icons/sword.png"
const DRAW_CARD_ICON_PATH := "res://data/icons/draw_card.png"
const INTRIGUE_ICON_PATH := "res://data/icons/intrigue.png"
const TRASH_CARD_ICON_PATH := "res://data/icons/trash_card.png"
const MAKER_ICON_PATH := "res://data/icons/maker.png"
const RESOURCE_SOLARI_ICON_PATH := "res://data/icons/solari.png"
const RESOURCE_SPICE_ICON_PATH := "res://data/icons/resource_spice.png"
const RESOURCE_WATER_ICON_PATH := "res://data/icons/water.png"
const FACTION_EMPEROR_ICON_PATH := "res://data/icons/emperor.png"
const FACTION_GUILD_ICON_PATH := "res://data/icons/spacing_guild.png"
const FACTION_BENE_GESSERIT_ICON_PATH := "res://data/icons/bene_gesserit.png"
const FACTION_FREMEN_ICON_PATH := "res://data/icons/fremen.png"
const SPY_ICON_PATH := "res://data/icons/spy.png"
const CONTRACT_ICON_PATH := "res://data/icons/contract.png"
const SAND_WORM_ICON_PATH := "res://data/icons/sand_worm.png"
const VP_ICON_PATH := "res://data/icons/vp.png"
const MIN_NAME_FONT_SIZE := 11
const EFFECT_ICON_SIZE_AGENT := Vector2(22, 22)
const EFFECT_ICON_SIZE_REVEAL := Vector2(22, 22)
const MIN_AGENT_ICON_SIZE := 12.0
const MAX_AGENT_ICON_SIZE := 22.4
const EFFECT_TOKEN_SCALE := 1.0
const EFFECT_MAX_REPEAT_ICONS := 1
const EFFECT_CONTENT_SCALE_STEPS := [0.72, 0.64, 0.56, 0.50]
const EFFECT_STRIP_INNER_HEIGHT_AGENT := 24.0
const EFFECT_STRIP_INNER_HEIGHT_REVEAL := 28.0
const EffectTextTokensScript = preload("res://scripts/domain/effect_text_tokens.gd")
const CardEffectPresentationScript = preload("res://scripts/domain/card_effect_presentation.gd")
static var _texture_cache: Dictionary = {}

func set_card_data(value: Dictionary) -> void:
	card_data = value
	if not is_node_ready():
		await ready
	_render()

func _render() -> void:
	var card_name := str(card_data.get("name", card_data.get("id", "Unknown")))
	var card_cost := int(card_data.get("cost", 0))
	var icons: Variant = card_data.get("agentIcons", [])
	var agent_effects: Variant = card_data.get("agentEffect", [])
	var reveal_effects: Variant = card_data.get("revealEffect", [])
	var purchase_bonus: Variant = card_data.get("purchaseBonus", [])

	name_label.text = card_name
	_fit_name_font_size()
	cost_label.text = str(card_cost)
	icons_label.text = ""
	icons_label.visible = false
	_render_agent_icons(icons)
	_render_purchase_bonus(purchase_bonus)
	_render_effect_block(
		agent_effects,
		str(card_data.get("agentEffectRenderMode", "")),
		str(card_data.get("agentEffectTextOverride", "")),
		agent_persuasion_badge,
		agent_persuasion_value,
		agent_troops_badge,
		agent_troops_value,
		agent_sword_icons,
		agent_draw_icons,
		agent_intrigue_icons,
		agent_trash_icons,
		agent_resource_badges,
		agent_effect_label,
		agent_effect_tokens_row,
		EFFECT_ICON_SIZE_AGENT
	)
	_render_effect_block(
		reveal_effects,
		str(card_data.get("revealEffectRenderMode", "")),
		str(card_data.get("revealEffectTextOverride", "")),
		reveal_persuasion_badge,
		reveal_persuasion_value,
		reveal_troops_badge,
		reveal_troops_value,
		reveal_sword_icons,
		reveal_draw_icons,
		reveal_intrigue_icons,
		reveal_trash_icons,
		reveal_resource_badges,
		reveal_effect_label,
		reveal_effect_tokens_row,
		EFFECT_ICON_SIZE_REVEAL
	)

func _render_purchase_bonus(effects: Variant) -> void:
	if purchase_bonus_row == null:
		return
	_clear_container(purchase_bonus_row)
	if typeof(effects) != TYPE_ARRAY or (effects as Array).is_empty():
		purchase_bonus_row.visible = false
		return
	var tokens_text := _effects_to_text(effects)
	if tokens_text.strip_edges() == "":
		purchase_bonus_row.visible = false
		return
	purchase_bonus_row.visible = true
	EffectsTokenRow.populate(purchase_bonus_row, tokens_text, 1.0)

func _fit_name_font_size() -> void:
	var default_font_size := name_label.get_theme_font_size("font_size")
	if default_font_size <= 0:
		default_font_size = 16
	var available_width := name_label.size.x
	if available_width <= 0.0:
		available_width = 132.0
	var target_font_size := default_font_size
	var font := name_label.get_theme_font("font")
	if font != null:
		for font_size_candidate in range(default_font_size, MIN_NAME_FONT_SIZE - 1, -1):
			var measured := font.get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size_candidate)
			if measured.x <= available_width:
				target_font_size = font_size_candidate
				break
		if target_font_size == default_font_size:
			var measured_default := font.get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, default_font_size)
			if measured_default.x > available_width:
				target_font_size = MIN_NAME_FONT_SIZE
	else:
		if name_label.text.length() > 20:
			target_font_size = MIN_NAME_FONT_SIZE
		elif name_label.text.length() > 16:
			target_font_size = maxi(default_font_size - 2, MIN_NAME_FONT_SIZE)
	name_label.add_theme_font_size_override("font_size", target_font_size)

func _render_effect_block(
	effects: Variant,
	render_mode: String,
	text_override: String,
	badge: Control,
	badge_value: Label,
	troops_badge: Control,
	troops_value: Label,
	sword_container: HBoxContainer,
	draw_cards_container: HBoxContainer,
	intrigue_icons_container: HBoxContainer,
	trash_icons_container: HBoxContainer,
	resource_badges_container: HBoxContainer,
	text_label: Label,
	text_tokens_row: HBoxContainer,
	_icon_size: Vector2
) -> void:
	_clear_container(sword_container)
	_clear_container(draw_cards_container)
	_clear_container(intrigue_icons_container)
	_clear_container(trash_icons_container)
	_clear_container(resource_badges_container)
	badge.visible = false
	badge_value.text = ""
	troops_badge.visible = false
	troops_value.text = ""
	if text_tokens_row != null:
		_clear_container(text_tokens_row)
		text_tokens_row.visible = false

	if render_mode == "text_only":
		text_label.text = text_override.strip_edges()
		text_label.visible = text_label.text != ""
		return

	var presentation: Dictionary = CardEffectPresentationScript.build(effects)
	var full_tokens := str(presentation.get("tokens_full", ""))
	text_label.text = _compact_effect_text(full_tokens)
	text_label.visible = text_label.text != ""

func _scaled_icon_size(base: Vector2, icon_scale: float) -> Vector2:
	return Vector2(maxf(14.0, base.x * icon_scale), maxf(14.0, base.y * icon_scale))

func _resolve_effect_content_scale(effects: Variant, text_without_icons: String, strip_inner_height: float) -> float:
	var score := 0
	if typeof(effects) == TYPE_ARRAY:
		score += (effects as Array).size() * 2
		score += _extract_effect_amount(effects, "gain_sword")
		score += _extract_effect_amount(effects, "draw_cards")
		score += _extract_effect_amount(effects, "draw_intrigue")
		score += _extract_effect_amount(effects, "trash_card")
		score += _extract_effect_amount(effects, "place_spy")
		score += _extract_effect_amount(effects, "get_contract")
		score += _extract_effect_amount(effects, "summon_sandworm")
		score += _extract_effect_amount(effects, "gain_influence")
		score += _extract_effect_amount(effects, "gain_resource")
		score += _extract_effect_amount(effects, "spend_resource")
	score += mini(int(floor(float(text_without_icons.length()) / 18.0)), 6)
	var base_icon_height := 22.0
	var max_scale_by_height := clampf(strip_inner_height / base_icon_height, 0.6, 1.0)
	if score >= 20:
		return minf(float(EFFECT_CONTENT_SCALE_STEPS[3]), max_scale_by_height)
	if score >= 15:
		return minf(float(EFFECT_CONTENT_SCALE_STEPS[2]), max_scale_by_height)
	if score >= 11:
		return minf(float(EFFECT_CONTENT_SCALE_STEPS[1]), max_scale_by_height)
	if score >= 7:
		return minf(float(EFFECT_CONTENT_SCALE_STEPS[0]), max_scale_by_height)
	return minf(float(EFFECT_CONTENT_SCALE_STEPS[0]), max_scale_by_height)

func _resolve_effect_content_scale_with_model(
	guaranteed: Dictionary,
	complexity: Dictionary,
	text_without_icons: String,
	strip_inner_height: float
) -> float:
	var score := 0
	score += int(guaranteed.get("sword", 0))
	score += int(guaranteed.get("draw_cards", 0))
	score += int(guaranteed.get("draw_intrigue", 0))
	score += int(guaranteed.get("trash_card", 0))
	score += int(guaranteed.get("place_spy", 0))
	score += int(guaranteed.get("get_contract", 0))
	score += int(guaranteed.get("summon_sandworm", 0))
	score += int(guaranteed.get("persuasion", 0))
	score += int(guaranteed.get("troops", 0))
	score += int(complexity.get("branch_nodes", 0)) * 2
	score += int(complexity.get("max_depth", 0))
	score += mini(int(floor(float(text_without_icons.length()) / 18.0)), 6)
	var base_icon_height := 22.0
	var max_scale_by_height := clampf(strip_inner_height / base_icon_height, 0.6, 1.0)
	if score >= 20:
		return minf(float(EFFECT_CONTENT_SCALE_STEPS[3]), max_scale_by_height)
	if score >= 15:
		return minf(float(EFFECT_CONTENT_SCALE_STEPS[2]), max_scale_by_height)
	if score >= 11:
		return minf(float(EFFECT_CONTENT_SCALE_STEPS[1]), max_scale_by_height)
	return minf(float(EFFECT_CONTENT_SCALE_STEPS[0]), max_scale_by_height)

func _compact_effect_text(text: String) -> String:
	var normalized := text.strip_edges()
	if normalized == "":
		return ""
	normalized = normalized.replace("  ", " ")
	normalized = normalized.replace("; ;", ";")
	return normalized

func _render_numeric_effect_badges(
	container: HBoxContainer,
	guaranteed: Dictionary,
	icon_size: Vector2,
	reference_value_label: Label,
	max_repeat_icons: int
) -> Dictionary:
	_clear_container(container)
	var rendered := false
	var overflowed := false

	var amounts: Dictionary = guaranteed.get("resources", {})
	for resource_id in ["solari", "spice", "water"]:
		var amount := int(amounts.get(resource_id, 0))
		if amount == 0:
			continue
		var icon_path := _resource_icon_path(resource_id)
		if icon_path == "":
			continue
		if not _add_numeric_icon_badge(container, icon_path, amount, icon_size, reference_value_label):
			continue
		rendered = true

	var influence_amounts: Dictionary = guaranteed.get("influence", {})
	for faction_id in ["emperor", "guild", "beneGesserit", "fremen"]:
		var amount := int(influence_amounts.get(faction_id, 0))
		if amount == 0:
			continue
		var faction_icon_path := _faction_icon_path(faction_id)
		if faction_icon_path == "":
			continue
		if _add_icon_only_badges(container, faction_icon_path, amount, icon_size, max_repeat_icons):
			rendered = true
			if amount > max_repeat_icons:
				overflowed = true

	var vp_amount := int(guaranteed.get("vp", 0))
	if vp_amount != 0 and _add_numeric_icon_badge(container, VP_ICON_PATH, vp_amount, icon_size, reference_value_label):
		rendered = true
	var contract_amount := int(guaranteed.get("get_contract", 0))
	if contract_amount > 0 and _add_icon_only_badges(container, CONTRACT_ICON_PATH, contract_amount, icon_size, max_repeat_icons):
		rendered = true
		if contract_amount > max_repeat_icons:
			overflowed = true
	var spy_amount := int(guaranteed.get("place_spy", 0))
	if spy_amount > 0 and _add_icon_only_badges(container, SPY_ICON_PATH, spy_amount, icon_size, max_repeat_icons):
		rendered = true
		if spy_amount > max_repeat_icons:
			overflowed = true
	var sand_worm_amount := int(guaranteed.get("summon_sandworm", 0))
	if sand_worm_amount > 0 and _add_icon_only_badges(container, SAND_WORM_ICON_PATH, sand_worm_amount, icon_size, max_repeat_icons):
		rendered = true
		if sand_worm_amount > max_repeat_icons:
			overflowed = true

	return {"rendered": rendered, "overflowed": overflowed}

func _render_maker_space_conditional_badges(
	container: HBoxContainer,
	effects: Variant,
	icon_size: Vector2,
	reference_value_label: Label
) -> bool:
	if typeof(effects) != TYPE_ARRAY:
		return false
	var rendered := false
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		if str(effect.get("type", "")) != "if":
			continue
		var req_raw: Variant = effect.get("requirement", {})
		var req: Dictionary = req_raw if typeof(req_raw) == TYPE_DICTIONARY else {}
		if str(req.get("type", "")) != "sent_agent_to_maker_space_this_turn":
			continue
		if not _add_icon_only_badges(container, MAKER_ICON_PATH, 1, icon_size):
			continue
		var then_raw: Variant = effect.get("then", [])
		if typeof(then_raw) != TYPE_ARRAY:
			rendered = true
			continue
		for then_effect in then_raw:
			if typeof(then_effect) != TYPE_DICTIONARY:
				continue
			if str(then_effect.get("type", "")) != "gain_resource":
				continue
			var resource_id := str(then_effect.get("resource", ""))
			var amount := int(then_effect.get("amount", 0))
			var icon_path := _resource_icon_path(resource_id)
			if icon_path == "":
				continue
			if amount <= 0:
				continue
			if _add_numeric_icon_badge(container, icon_path, amount, icon_size, reference_value_label):
				rendered = true
		rendered = true
	return rendered

func _extract_resource_amounts(effects: Variant) -> Dictionary:
	var totals := {"solari": 0, "spice": 0, "water": 0}
	if typeof(effects) != TYPE_ARRAY:
		return totals
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		var effect_type := str(effect.get("type", ""))
		if effect_type != "gain_resource" and effect_type != "spend_resource":
			continue
		var resource_id := str(effect.get("resource", ""))
		if not totals.has(resource_id):
			continue
		var amount := int(effect.get("amount", 0))
		if effect_type == "spend_resource":
			amount = -amount
		totals[resource_id] = int(totals.get(resource_id, 0)) + amount
	return totals

func _extract_influence_amounts(effects: Variant) -> Dictionary:
	var totals := {"emperor": 0, "guild": 0, "beneGesserit": 0, "fremen": 0}
	if typeof(effects) != TYPE_ARRAY:
		return totals
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		if str(effect.get("type", "")) != "gain_influence":
			continue
		var faction_id := str(effect.get("faction", ""))
		if not totals.has(faction_id):
			continue
		var amount := int(effect.get("amount", 0))
		totals[faction_id] = int(totals.get(faction_id, 0)) + amount
	return totals

func _resource_icon_path(resource_id: String) -> String:
	match resource_id:
		"solari":
			return RESOURCE_SOLARI_ICON_PATH
		"spice":
			return RESOURCE_SPICE_ICON_PATH
		"water":
			return RESOURCE_WATER_ICON_PATH
		_:
			return ""

func _faction_icon_path(faction_id: String) -> String:
	match faction_id:
		"emperor":
			return FACTION_EMPEROR_ICON_PATH
		"guild":
			return FACTION_GUILD_ICON_PATH
		"beneGesserit":
			return FACTION_BENE_GESSERIT_ICON_PATH
		"fremen":
			return FACTION_FREMEN_ICON_PATH
		_:
			return ""

func _add_numeric_icon_badge(
	container: HBoxContainer,
	icon_path: String,
	amount: int,
	icon_size: Vector2,
	reference_value_label: Label
) -> bool:
	var tex := _load_cached_texture(icon_path)
	if tex == null:
		return false

	var badge := Control.new()
	badge.custom_minimum_size = icon_size
	var icon := TextureRect.new()
	icon.anchors_preset = Control.PRESET_FULL_RECT
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.grow_horizontal = Control.GROW_DIRECTION_BOTH
	icon.grow_vertical = Control.GROW_DIRECTION_BOTH
	icon.texture = tex
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(icon)

	var value := Label.new()
	value.anchors_preset = Control.PRESET_CENTER
	value.anchor_left = 0.5
	value.anchor_top = 0.5
	value.anchor_right = 0.5
	value.anchor_bottom = 0.5
	value.offset_left = -icon_size.x * 0.5
	value.offset_top = -icon_size.y * 0.5
	value.offset_right = icon_size.x * 0.5
	value.offset_bottom = icon_size.y * 0.5
	value.grow_horizontal = Control.GROW_DIRECTION_BOTH
	value.grow_vertical = Control.GROW_DIRECTION_BOTH
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Single-stack effects are shown as plain icons without numeric overlay.
	if absi(amount) == 1:
		value.text = ""
	else:
		value.text = str(amount)
	var ref_font_size := reference_value_label.get_theme_font_size("font_size")
	if ref_font_size <= 0:
		ref_font_size = maxi(int(icon_size.y * 0.58), 11)
	value.add_theme_font_size_override("font_size", ref_font_size)
	var ref_font_color := reference_value_label.get_theme_color("font_color")
	if icon_path == RESOURCE_SOLARI_ICON_PATH:
		ref_font_color = Color(0.0, 0.0, 0.0, 1.0)
	value.add_theme_color_override("font_color", ref_font_color)
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(value)

	container.add_child(badge)
	return true

func _add_icon_only_badges(
	container: HBoxContainer,
	icon_path: String,
	count: int,
	icon_size: Vector2,
	max_icons: int = -1
) -> bool:
	if count <= 0:
		return false
	var tex := _load_cached_texture(icon_path)
	if tex == null:
		return false
	var icons_to_render := count
	if max_icons >= 0:
		icons_to_render = mini(count, max_icons)
	for _i in range(icons_to_render):
		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = icon_size
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.texture = tex
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(icon_rect)
	if icons_to_render < count:
		_add_compact_count_label(container, count, 1.0)
	return true

func _render_agent_icons(icons: Variant) -> void:
	_clear_container(agent_icons_column)
	if typeof(icons) != TYPE_ARRAY or icons.is_empty():
		return

	var icons_array: Array = icons
	var icon_side := _resolve_agent_icon_side(icons_array.size())
	for icon_raw in icons:
		var icon_id := _normalize_icon_id(str(icon_raw))
		var texture := _load_icon_texture(icon_id)
		if texture == null:
			continue
		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(icon_side, icon_side)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.texture = texture
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		agent_icons_column.add_child(icon_rect)

func _resolve_agent_icon_side(icon_count: int) -> float:
	if icon_count <= 0:
		return MAX_AGENT_ICON_SIZE
	var available_height := agent_icons_column.size.y
	if available_height <= 0.0:
		available_height = agent_icons_column.get_parent_control().size.y if agent_icons_column.get_parent_control() != null else 88.0
	if available_height <= 0.0:
		available_height = 88.0
	var spacing := float(agent_icons_column.get_theme_constant("separation"))
	var total_spacing := maxf(float(icon_count - 1) * spacing, 0.0)
	var side := (available_height - total_spacing) / float(icon_count)
	return clampf(side, MIN_AGENT_ICON_SIZE, MAX_AGENT_ICON_SIZE)

func _load_icon_texture(icon_id: String) -> Texture2D:
	var png_path := ICON_DIR + icon_id + ".png"
	if ResourceLoader.exists(png_path):
		return _load_cached_texture(png_path)

	var jpeg_path := ICON_DIR + icon_id + ".jpeg"
	if ResourceLoader.exists(jpeg_path):
		return _load_cached_texture(jpeg_path)

	var jpg_path := ICON_DIR + icon_id + ".jpg"
	if ResourceLoader.exists(jpg_path):
		return _load_cached_texture(jpg_path)
	return null

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

func _clear_container(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.free()

func _effects_to_text(
	effects: Variant,
	skip_persuasion: bool = false,
	skip_sword: bool = false,
	skip_draw_cards: bool = false,
	skip_recruit_troops: bool = false,
	skip_draw_intrigue: bool = false,
	skip_trash_card: bool = false,
	skip_gain_resource: bool = false,
	skip_spend_resource: bool = false,
	skip_gain_influence: bool = false,
	skip_vp: bool = false,
	skip_get_contract: bool = false,
	skip_summon_sandworm: bool = false,
	skip_maker_space_conditional_if: bool = false,
	skip_place_spy: bool = false
) -> String:
	return EffectTextTokensScript.effects_to_text_card_with_skips(
		effects,
		skip_persuasion,
		skip_sword,
		skip_draw_cards,
		skip_recruit_troops,
		skip_draw_intrigue,
		skip_trash_card,
		skip_gain_resource,
		skip_spend_resource,
		skip_gain_influence,
		skip_vp,
		skip_get_contract,
		skip_summon_sandworm,
		skip_maker_space_conditional_if,
		skip_place_spy
	)

func _extract_effect_amount(effects: Variant, effect_type: String) -> int:
	if typeof(effects) != TYPE_ARRAY:
		return 0
	var total := 0
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		if str(effect.get("type", "")) != effect_type:
			continue
		total += int(effect.get("amount", 0))
	return total

func _render_sword_icons(container: HBoxContainer, amount: int, icon_size: Vector2, max_icons: int, content_scale: float) -> bool:
	_clear_container(container)
	if amount <= 0:
		return false
	var sword_texture := _load_cached_texture(SWORD_ICON_PATH)
	if sword_texture == null:
		return false
	var icons_to_render := amount
	if max_icons >= 0:
		icons_to_render = mini(amount, max_icons)
	for _i in range(icons_to_render):
		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = icon_size
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.texture = sword_texture
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(icon_rect)
	if icons_to_render < amount:
		_add_compact_count_label(container, amount, content_scale)
		return true
	return false

func _render_repeat_texture_icons(
	container: HBoxContainer,
	amount: int,
	icon_size: Vector2,
	texture_path: String,
	max_icons: int,
	content_scale: float
) -> bool:
	_clear_container(container)
	if amount <= 0:
		return false
	var tex := _load_cached_texture(texture_path)
	if tex == null:
		return false
	var icons_to_render := amount
	if max_icons >= 0:
		icons_to_render = mini(amount, max_icons)
	for _i in range(icons_to_render):
		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = icon_size
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.texture = tex
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(icon_rect)
	if icons_to_render < amount:
		_add_compact_count_label(container, amount, content_scale)
		return true
	return false

func _add_compact_count_label(container: HBoxContainer, count: int, content_scale: float) -> void:
	var label := Label.new()
	label.text = "x%d" % count
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", maxi(int(round(10.0 * content_scale)), 8))
	container.add_child(label)

func _resolve_strip_budget_width(container: HBoxContainer) -> float:
	if container == null:
		return 96.0
	var width := container.size.x
	if width <= 0.0 and container.get_parent_control() != null:
		width = container.get_parent_control().size.x
	if width <= 0.0:
		width = 96.0
	return width

func _trim_container_to_width(container: HBoxContainer, max_width: float) -> void:
	if container == null:
		return
	var budget := maxf(max_width, 42.0)
	while _measure_container_width(container) > budget and container.get_child_count() > 0:
		var last := container.get_child(container.get_child_count() - 1)
		container.remove_child(last)
		last.free()

func _measure_container_width(container: HBoxContainer) -> float:
	var total := 0.0
	var sep := float(container.get_theme_constant("separation"))
	for idx in range(container.get_child_count()):
		var child := container.get_child(idx)
		total += _measure_node_width(child)
		if idx < container.get_child_count() - 1:
			total += sep
	return total

func _measure_node_width(node: Node) -> float:
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

func _load_cached_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if _texture_cache.has(path):
		return _texture_cache[path] as Texture2D
	var tex := load(path) as Texture2D
	if tex != null:
		_texture_cache[path] = tex
	return tex
