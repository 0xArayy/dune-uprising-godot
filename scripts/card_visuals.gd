class_name CardVisuals
extends Control

@export var card_data: Dictionary : set = set_card_data

@onready var name_label: Label = $Panel/VBox/Header/Name
@onready var cost_label: Label = %CostValue
@onready var icons_label: Label = $Panel/VBox/Icons
@onready var purchase_bonus_row: HBoxContainer = %PurchaseBonusOverlayRow
@onready var agent_icons_column: VBoxContainer = %AgentIconsColumn
@onready var agent_effect_label: Label = $Panel/VBox/AgentRow/AgentEffectBlock/AgentEffectMargin/AgentEffectVBox/AgentEffectContent/AgentEffect
@onready var reveal_effect_label: Label = $Panel/VBox/RevealEffectBlock/RevealEffectMargin/RevealEffectVBox/RevealEffectContent/RevealEffect
@onready var agent_effect_tokens_row: HBoxContainer = %AgentEffectTokens
@onready var reveal_effect_tokens_row: HBoxContainer = %RevealEffectTokens
@onready var agent_persuasion_badge: Control = %AgentPersuasionBadge
@onready var reveal_persuasion_badge: Control = %RevealPersuasionBadge
@onready var agent_persuasion_value: Label = $Panel/VBox/AgentRow/AgentEffectBlock/AgentEffectMargin/AgentEffectVBox/AgentEffectContent/AgentPersuasionBadge/BadgeValue
@onready var reveal_persuasion_value: Label = $Panel/VBox/RevealEffectBlock/RevealEffectMargin/RevealEffectVBox/RevealEffectContent/RevealPersuasionBadge/BadgeValue
@onready var agent_sword_icons: HBoxContainer = %AgentSwordIcons
@onready var reveal_sword_icons: HBoxContainer = %RevealSwordIcons
@onready var agent_draw_icons: HBoxContainer = %AgentDrawIcons
@onready var agent_intrigue_icons: HBoxContainer = %AgentIntrigueIcons
@onready var agent_trash_icons: HBoxContainer = %AgentTrashIcons
@onready var reveal_draw_icons: HBoxContainer = %RevealDrawIcons
@onready var reveal_intrigue_icons: HBoxContainer = %RevealIntrigueIcons
@onready var reveal_trash_icons: HBoxContainer = %RevealTrashIcons
@onready var agent_troops_badge: Control = %AgentTroopsBadge
@onready var agent_troops_value: Label = $Panel/VBox/AgentRow/AgentEffectBlock/AgentEffectMargin/AgentEffectVBox/AgentEffectContent/AgentTroopsBadge/BadgeValue
@onready var reveal_troops_badge: Control = %RevealTroopsBadge
@onready var reveal_troops_value: Label = $Panel/VBox/RevealEffectBlock/RevealEffectMargin/RevealEffectVBox/RevealEffectContent/RevealTroopsBadge/BadgeValue
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
const EFFECT_TOKEN_SCALE := 1.0
const EFFECT_MAX_REPEAT_ICONS := 1
const EFFECT_CONTENT_SCALE_STEPS := [0.72, 0.64, 0.56, 0.50]
const EFFECT_STRIP_INNER_HEIGHT_AGENT := 24.0
const EFFECT_STRIP_INNER_HEIGHT_REVEAL := 28.0
const EffectTextTokensScript = preload("res://scripts/domain/effect_text_tokens.gd")
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
	icon_size: Vector2
) -> void:
	var text_without_icons := _effects_to_text(effects, true, true, true, true, true, true, true, true, true, true, true, true, true, true)
	var strip_inner_height := EFFECT_STRIP_INNER_HEIGHT_AGENT if icon_size.y <= EFFECT_ICON_SIZE_AGENT.y else EFFECT_STRIP_INNER_HEIGHT_REVEAL
	var content_scale := _resolve_effect_content_scale(effects, text_without_icons, strip_inner_height)
	var render_icon_size: Vector2 = _scaled_icon_size(icon_size, content_scale)
	var max_repeat_icons := EFFECT_MAX_REPEAT_ICONS
	var token_scale := EFFECT_TOKEN_SCALE * content_scale

	var persuasion_amount := _extract_effect_amount(effects, "gain_persuasion")
	if persuasion_amount > 0:
		badge.visible = true
		badge_value.text = str(persuasion_amount)
	else:
		badge.visible = false
		badge_value.text = ""

	var troops_amount := _extract_effect_amount(effects, "recruit_troops")
	if troops_amount > 0:
		troops_badge.visible = true
		troops_value.text = str(troops_amount)
	else:
		troops_badge.visible = false
		troops_value.text = ""

	var sword_amount := _extract_effect_amount(effects, "gain_sword")
	var icons_overflowed := _render_sword_icons(sword_container, sword_amount, render_icon_size, max_repeat_icons, content_scale)
	var draw_cards_amount := _extract_effect_amount(effects, "draw_cards")
	icons_overflowed = _render_repeat_texture_icons(draw_cards_container, draw_cards_amount, render_icon_size, DRAW_CARD_ICON_PATH, max_repeat_icons, content_scale) or icons_overflowed
	var intrigue_amount := _extract_effect_amount(effects, "draw_intrigue")
	icons_overflowed = _render_repeat_texture_icons(intrigue_icons_container, intrigue_amount, render_icon_size, INTRIGUE_ICON_PATH, max_repeat_icons, content_scale) or icons_overflowed
	var trash_amount := _extract_effect_amount(effects, "trash_card")
	icons_overflowed = _render_repeat_texture_icons(trash_icons_container, trash_amount, render_icon_size, TRASH_CARD_ICON_PATH, max_repeat_icons, content_scale) or icons_overflowed
	var numeric_render_result := _render_numeric_effect_badges(resource_badges_container, effects, render_icon_size, badge_value, max_repeat_icons)
	var numeric_icons_rendered := bool(numeric_render_result.get("rendered", false))
	icons_overflowed = bool(numeric_render_result.get("overflowed", false)) or icons_overflowed

	var has_any_icons := (
		persuasion_amount > 0
		or troops_amount > 0
		or sword_amount > 0
		or draw_cards_amount > 0
		or intrigue_amount > 0
		or trash_amount > 0
		or numeric_icons_rendered
	)
	var should_use_text_fallback := icons_overflowed and text_without_icons.length() > 0
	if should_use_text_fallback:
		if text_tokens_row != null:
			# Keep token rendering active in fallback mode so badges/cost trades
			# (e.g. spice payment -> reward) render as icons, not raw token text.
			EffectsTokenRow.populate(text_tokens_row, _compact_effect_text(_effects_to_text(effects)), token_scale)
			text_tokens_row.visible = true
		text_label.visible = false
		text_label.text = ""
		return

	if text_tokens_row != null:
		var tokens_or_text := text_without_icons
		if tokens_or_text == "" and not has_any_icons:
			tokens_or_text = _compact_effect_text(_effects_to_text(effects))
		EffectsTokenRow.populate(text_tokens_row, tokens_or_text, token_scale)
		text_tokens_row.visible = tokens_or_text != ""

	if text_without_icons == "" and has_any_icons:
		text_label.visible = false
		text_label.text = ""

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

func _compact_effect_text(text: String) -> String:
	var normalized := text.strip_edges()
	if normalized == "":
		return ""
	normalized = normalized.replace("  ", " ")
	normalized = normalized.replace("; ;", ";")
	return normalized

func _render_numeric_effect_badges(
	container: HBoxContainer,
	effects: Variant,
	icon_size: Vector2,
	reference_value_label: Label,
	max_repeat_icons: int
) -> Dictionary:
	_clear_container(container)
	var rendered := false
	var overflowed := false

	var amounts := _extract_resource_amounts(effects)
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

	var influence_amounts := _extract_influence_amounts(effects)
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

	var vp_amount := _extract_effect_amount(effects, "vp")
	if vp_amount != 0 and _add_numeric_icon_badge(container, VP_ICON_PATH, vp_amount, icon_size, reference_value_label):
		rendered = true
	if _render_maker_space_conditional_badges(container, effects, icon_size, reference_value_label):
		rendered = true
	var contract_amount := _extract_effect_amount(effects, "get_contract")
	if contract_amount > 0 and _add_icon_only_badges(container, CONTRACT_ICON_PATH, contract_amount, icon_size, max_repeat_icons):
		rendered = true
		if contract_amount > max_repeat_icons:
			overflowed = true
	var spy_amount := _extract_effect_amount(effects, "place_spy")
	if spy_amount > 0 and _add_icon_only_badges(container, SPY_ICON_PATH, spy_amount, icon_size, max_repeat_icons):
		rendered = true
		if spy_amount > max_repeat_icons:
			overflowed = true
	var sand_worm_amount := _extract_effect_amount(effects, "summon_sandworm")
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

	for icon_raw in icons:
		var icon_id := _normalize_icon_id(str(icon_raw))
		var texture := _load_icon_texture(icon_id)
		if texture == null:
			continue
		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = ICON_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.texture = texture
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		agent_icons_column.add_child(icon_rect)

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
		child.queue_free()

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

func _load_cached_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if _texture_cache.has(path):
		return _texture_cache[path] as Texture2D
	var tex := load(path) as Texture2D
	if tex != null:
		_texture_cache[path] = tex
	return tex
