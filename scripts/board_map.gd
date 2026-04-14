extends Node2D
class_name BoardMap

signal highlighted_space_selected(space_id: String)
signal highlighted_spy_post_selected(post_id: String)
const FactionProgressionServiceScript = preload("res://scripts/faction_progression_service.gd")
const PlacementRulesServiceScript = preload("res://scripts/application/services/placement_rules_service.gd")
const EffectResolverScript = preload("res://scripts/effect_resolver.gd")
const ContractServiceScript = preload("res://scripts/contract_service.gd")
const EffectDslScript = preload("res://scripts/domain/effect_dsl.gd")
const EffectPipelineScript = preload("res://scripts/domain/effect_pipeline.gd")
const BoardEffectsServiceScript = preload("res://scripts/domain/services/board_effects_service.gd")
const ControlMarkersServiceScript = preload("res://scripts/domain/services/control_markers_service.gd")
const BoardRulesAdapterScript = preload("res://scripts/domain/services/board_rules_adapter.gd")
const BoardVisualSyncScript = preload("res://scripts/presentation/board_visual_sync.gd")
const SpyPostVisualSubsystemScript = preload("res://scripts/presentation/spy_post_visual_subsystem.gd")
const EffectTextTokensScript = preload("res://scripts/domain/effect_text_tokens.gd")

const BOARD_SLOT_HEIGHT := 110.0
const BOARD_SLOT_VERTICAL_GAP := 12.0
const FACTION_AREAS := {
	"emperor": true,
	"guild": true,
	"beneGesserit": true,
	"fremen": true
}
const PLAYER_TOKEN_COLORS: Array[Color] = [
	Color(0.95, 0.78, 0.33, 1.0),
	Color(0.44, 0.74, 0.97, 1.0),
	Color(0.85, 0.48, 0.86, 1.0),
	Color(0.58, 0.9, 0.57, 1.0)
]
const CONFLICT_TROOPS_ICON_PATH := "res://data/icons/troops.png"
const CONFLICT_SANDWORM_ICON_PATH := "res://data/icons/sand_worm.png"
const SPY_POSTS_DB_PATH := "res://data/spy_posts_uprising.json"
const SPY_ICON_PATH := "res://data/icons/spy.png"
const SPY_POST_RADIUS := 13.0
const SPY_POST_ICON_SIZE := 16.0
const SPY_POST_LINE_WIDTH := 2.0
const SPY_FACTION_POST_RIGHT_OFFSET := 124.0
const SPY_GEOMETRIC_MEDIAN_ITERATIONS := 24
const SPY_GEOMETRIC_MEDIAN_EPSILON := 0.001
const SHIELD_WALL_START_TEXTURE := preload("res://data/icons/shield_wall_start.png")
const SHIELD_WALL_DESTROYED_TEXTURE := preload("res://data/icons/shield_wall_destroyed.png")
const BATTLE_ICON_TEXTURE_PATHS := {
	"crysknife": "res://data/icons/Crysknife.png",
	"desert_mouse": "res://data/icons/desert_mouse.png",
	"ornithopter": "res://data/icons/ornithopter.png"
}
const BOARD_SPACE_HALF_SIZE := Vector2(110.0, 55.0)
const BOARD_SPACE_LINE_PADDING := 2.0
const CONTROL_MARKER_SPACE_IDS: Array[String] = ["arrakeen", "spice_refinery", "imperial_basin"]
const CONTROL_BONUS_BY_SPACE := {
	"imperial_basin": {"resource": "spice", "amount": 1},
	"arrakeen": {"resource": "solari", "amount": 1},
	"spice_refinery": {"resource": "solari", "amount": 1}
}

# Map `boardSpaceId -> occupyingPlayerId/agentId/null` (see `data-model.md`).
var initial_board_occupancy = {}
var board_spaces_by_id = {}
var highlighted_space_ids: Dictionary = {}
var highlighted_spy_post_ids: Dictionary = {}
var _spy_post_connections_by_id: Dictionary = {}
var _spy_posts_occupancy: Dictionary = {}
var _spy_space_positions: Dictionary = {}
var _spy_post_centers: Dictionary = {}
var _spy_icon_texture: Texture2D = null
var _spy_draw_game_state: Dictionary = {}
var faction_progression_service := FactionProgressionServiceScript.new()
var placement_rules_service := PlacementRulesServiceScript.new()
var effect_pipeline := EffectPipelineScript.new()
var board_effects_service := BoardEffectsServiceScript.new()
var control_markers_service := ControlMarkersServiceScript.new()
var board_rules_adapter: BoardRulesAdapter
var board_visual_sync: BoardVisualSync
var spy_post_visual_subsystem: SpyPostVisualSubsystem
var effect_resolver
@onready var conflict_title_label: Label = %ConflictTitle
@onready var conflict_index_label: Label = %ConflictIndexLabel
@onready var conflict_p1_label: Label = %P1TroopsValue
@onready var conflict_p2_label: Label = %P2TroopsValue
@onready var conflict_p3_label: Label = %P3TroopsValue
@onready var conflict_p4_label: Label = %P4TroopsValue
@onready var garrison_p1_icon: TextureRect = $ConflictZone/CornerTopLeft/CornerTopLeftMargin/P1GarrisonLabel/TroopsBadge/BadgeIcon
@onready var garrison_p2_icon: TextureRect = $ConflictZone/CornerTopRight/CornerTopRightMargin/P2GarrisonLabel/TroopsBadge/BadgeIcon
@onready var garrison_p3_icon: TextureRect = $ConflictZone/CornerBottomLeft/CornerBottomLeftMargin/P3GarrisonLabel/TroopsBadge/BadgeIcon
@onready var garrison_p4_icon: TextureRect = $ConflictZone/CornerBottomRight/CornerBottomRightMargin/P4GarrisonLabel/TroopsBadge/BadgeIcon
@onready var first_reward_slot: ConflictRewardSlot = %FirstRewardSlot
@onready var second_reward_slot: ConflictRewardSlot = %SecondRewardSlot
@onready var third_reward_slot: ConflictRewardSlot = %ThirdRewardSlot
@onready var conflict_rewards_panel: PanelContainer = $ConflictZone/RewardsPanel
@onready var conflict_battle_icon: TextureRect = %ConflictBattleIcon

## Default (Siege / shield-wall–blocked conflicts): ochre-mustard like the physical card, not alarm red.
var _rewards_panel_style_default: StyleBoxFlat
var _rewards_panel_style_shield_wall: StyleBoxFlat
var _conflict_reward_slot_style_default: StyleBoxFlat
var _conflict_reward_slot_style_shield_wall: StyleBoxFlat
var _battle_icon_texture_cache: Dictionary = {}

const CONFLICT_TITLE_COLOR_DEFAULT := Color(1, 1, 1, 1)
const CONFLICT_INDEX_COLOR_DEFAULT := Color(0.78, 0.83, 0.92, 0.95)
const CONFLICT_TITLE_COLOR_SHIELD_WALL := Color(0.14, 0.11, 0.08, 1)
const CONFLICT_INDEX_COLOR_SHIELD_WALL := Color(0.34, 0.28, 0.18, 0.92)
const CONFLICT_RANK_LABEL_COLOR_DEFAULT := Color(0.97, 0.9, 0.9, 1)
const CONFLICT_RANK_LABEL_COLOR_SHIELD_WALL := Color(0.2, 0.16, 0.11, 1)
@onready var conflict_troops_icons_p1: HBoxContainer = %P1ConflictTroopsIcons
@onready var conflict_troops_icons_p2: HBoxContainer = %P2ConflictTroopsIcons
@onready var conflict_troops_icons_p3: HBoxContainer = %P3ConflictTroopsIcons
@onready var conflict_troops_icons_p4: HBoxContainer = %P4ConflictTroopsIcons
@onready var emperor_tracker: FactionInfluenceTracker = $InfluenceTrackers/EmperorTracker
@onready var guild_tracker: FactionInfluenceTracker = $InfluenceTrackers/GuildTracker
@onready var bene_gesserit_tracker: FactionInfluenceTracker = $InfluenceTrackers/BeneGesseritTracker
@onready var fremen_tracker: FactionInfluenceTracker = $InfluenceTrackers/FremenTracker
@onready var vp_tracker: VpTracker = $VpTracker
@onready var shield_wall_start_sprite: Sprite2D = $ShieldWallStart

func _ensure_db_loaded():
	if typeof(board_spaces_by_id) != TYPE_DICTIONARY or board_spaces_by_id.is_empty():
		board_spaces_by_id = BoardSpacesDb.load_spaces_by_id()


func _init_conflict_zone_visual_themes() -> void:
	if conflict_rewards_panel != null:
		var psb: Variant = conflict_rewards_panel.get_theme_stylebox("panel")
		if psb is StyleBoxFlat:
			_rewards_panel_style_default = (psb as StyleBoxFlat).duplicate() as StyleBoxFlat
			_rewards_panel_style_shield_wall = _rewards_panel_style_default.duplicate() as StyleBoxFlat
			# Muted mustard / ochre panel (Dune: Imperium siege-style conflict strip).
			_rewards_panel_style_shield_wall.bg_color = Color(0.62, 0.48, 0.16, 0.96)
			_rewards_panel_style_shield_wall.border_color = Color(0.42, 0.31, 0.1, 0.95)
	if first_reward_slot != null:
		var ssb: Variant = first_reward_slot.get_theme_stylebox("panel")
		if ssb is StyleBoxFlat:
			_conflict_reward_slot_style_default = (ssb as StyleBoxFlat).duplicate() as StyleBoxFlat
			_conflict_reward_slot_style_shield_wall = _conflict_reward_slot_style_default.duplicate() as StyleBoxFlat
			_conflict_reward_slot_style_shield_wall.bg_color = Color(0.78, 0.64, 0.28, 0.97)
			_conflict_reward_slot_style_shield_wall.border_color = Color(0.5, 0.38, 0.14, 0.96)


func _apply_conflict_zone_theme_for_sandworm_policy(conflict_card_def: Dictionary) -> void:
	var use_shield_wall_palette := str(conflict_card_def.get("sandwormPolicy", "")) == "blocked_by_shield_wall"
	if conflict_rewards_panel != null and _rewards_panel_style_default != null and _rewards_panel_style_shield_wall != null:
		conflict_rewards_panel.add_theme_stylebox_override(
			"panel",
			_rewards_panel_style_shield_wall if use_shield_wall_palette else _rewards_panel_style_default
		)
	if conflict_title_label != null:
		conflict_title_label.add_theme_color_override(
			"font_color",
			CONFLICT_TITLE_COLOR_SHIELD_WALL if use_shield_wall_palette else CONFLICT_TITLE_COLOR_DEFAULT
		)
	if conflict_index_label != null:
		conflict_index_label.add_theme_color_override(
			"font_color",
			CONFLICT_INDEX_COLOR_SHIELD_WALL if use_shield_wall_palette else CONFLICT_INDEX_COLOR_DEFAULT
		)
	var slot_style: StyleBoxFlat = (
		_conflict_reward_slot_style_shield_wall
		if use_shield_wall_palette
		else _conflict_reward_slot_style_default
	)
	var rank_color: Color = (
		CONFLICT_RANK_LABEL_COLOR_SHIELD_WALL
		if use_shield_wall_palette
		else CONFLICT_RANK_LABEL_COLOR_DEFAULT
	)
	for slot in [first_reward_slot, second_reward_slot, third_reward_slot]:
		if slot == null or slot_style == null:
			continue
		slot.apply_reward_slot_panel_style(slot_style)
		slot.apply_rank_label_color(rank_color)

func _ready():
	board_spaces_by_id = BoardSpacesDb.load_spaces_by_id()
	effect_resolver = EffectResolverScript.new(faction_progression_service)
	board_rules_adapter = BoardRulesAdapterScript.new(placement_rules_service, board_effects_service)
	board_visual_sync = BoardVisualSyncScript.new(
		Callable(self, "_sync_markers"),
		Callable(self, "_update_conflict_zone_labels"),
		Callable(self, "_update_shield_wall_visuals")
	)
	spy_post_visual_subsystem = SpyPostVisualSubsystemScript.new(
		Callable(self, "_draw_spy_posts"),
		Callable(self, "_load_spy_post_connections")
	)
	_spy_icon_texture = load(SPY_ICON_PATH) as Texture2D
	_spy_post_connections_by_id = spy_post_visual_subsystem.load_connections()
	_apply_faction_vertical_spacing()
	_init_conflict_zone_visual_themes()
	_update_shield_wall_visuals({})
	board_visual_sync.sync_all(initial_board_occupancy, {})

func _draw() -> void:
	if spy_post_visual_subsystem != null:
		spy_post_visual_subsystem.draw()
		return
	_draw_spy_posts()

func _draw_spy_posts() -> void:
	if _spy_post_connections_by_id.is_empty() or _spy_post_centers.is_empty():
		return
	for post_id_variant in _spy_post_connections_by_id.keys():
		var post_id := str(post_id_variant)
		if not _spy_post_centers.has(post_id):
			continue
		var center: Vector2 = _spy_post_centers[post_id]
		var connected_spaces: Variant = _spy_post_connections_by_id.get(post_id, [])
		if typeof(connected_spaces) != TYPE_ARRAY:
			continue

		var owner_id := ""
		if _spy_posts_occupancy.has(post_id) and _spy_posts_occupancy[post_id] != null:
			var post_entry: Variant = _spy_posts_occupancy[post_id]
			if typeof(post_entry) == TYPE_ARRAY:
				var owners: Array = post_entry
				if not owners.is_empty():
					owner_id = str(owners[owners.size() - 1])
			else:
				owner_id = str(post_entry)
		var owner_color := Color(0.92, 0.92, 0.95, 0.95)
		var owner_index := _get_player_index_by_id(_spy_draw_game_state, owner_id)
		if owner_index >= 0:
			owner_color = PLAYER_TOKEN_COLORS[owner_index % PLAYER_TOKEN_COLORS.size()]
		var is_highlighted := highlighted_spy_post_ids.has(post_id)

		for space_id_variant in connected_spaces:
			var space_id := str(space_id_variant)
			if not _spy_space_positions.has(space_id):
				continue
			var to_pos: Vector2 = _spy_space_positions[space_id]
			_draw_spy_post_connection(center, to_pos, owner_color)

		draw_circle(center, SPY_POST_RADIUS, Color(0.1, 0.1, 0.12, 0.9))
		draw_circle(center, SPY_POST_RADIUS, Color(owner_color.r, owner_color.g, owner_color.b, 0.95), false, 2.0)
		if is_highlighted:
			draw_circle(center, SPY_POST_RADIUS + 3.0, Color(0.99, 0.9, 0.45, 0.98), false, 2.5)
		if _spy_icon_texture != null:
			var half := SPY_POST_ICON_SIZE * 0.5
			var rect := Rect2(center - Vector2(half, half), Vector2(SPY_POST_ICON_SIZE, SPY_POST_ICON_SIZE))
			draw_texture_rect(_spy_icon_texture, rect, false, owner_color)


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	var mouse_pos := get_global_mouse_position()
	if not highlighted_space_ids.is_empty():
		var markers = get_tree().get_nodes_in_group("board_space_markers")
		for marker in markers:
			if not marker.has_method("contains_global_point"):
				continue
			var space_id = str(marker.board_space_id)
			if not highlighted_space_ids.has(space_id):
				continue
			if bool(marker.contains_global_point(mouse_pos)):
				highlighted_space_selected.emit(space_id)
				get_viewport().set_input_as_handled()
				return

	if highlighted_spy_post_ids.is_empty():
		return
	var mouse_local := to_local(mouse_pos)
	var selected_post_id := _find_spy_post_at_local_point(mouse_local)
	if selected_post_id == "":
		return
	if not highlighted_spy_post_ids.has(selected_post_id):
		return
	highlighted_spy_post_selected.emit(selected_post_id)
	get_viewport().set_input_as_handled()

func apply_board_occupancy(board_occupancy):
	_sync_markers(board_occupancy, null)

func set_highlighted_spaces(space_ids: Array) -> void:
	highlighted_space_ids = {}
	for space_id in space_ids:
		highlighted_space_ids[str(space_id)] = true
	_sync_marker_highlights()

func clear_highlighted_spaces() -> void:
	highlighted_space_ids = {}
	_sync_marker_highlights()

func set_highlighted_spy_posts(post_ids: Array) -> void:
	highlighted_spy_post_ids = {}
	for post_id in post_ids:
		var key := str(post_id)
		if key == "":
			continue
		highlighted_spy_post_ids[key] = true
	queue_redraw()

func clear_highlighted_spy_posts() -> void:
	highlighted_spy_post_ids = {}
	queue_redraw()

func get_available_spy_post_ids(game_state: Dictionary) -> Array:
	SpySystem.ensure_spy_state(game_state)
	return SpySystem.get_unoccupied_spy_post_ids(game_state)

func get_owned_spy_post_ids(game_state: Dictionary, player_id: String) -> Array:
	SpySystem.ensure_spy_state(game_state)
	return SpySystem.get_player_spy_post_ids(game_state, player_id)

func _find_spy_post_at_local_point(local_point: Vector2) -> String:
	for post_id_variant in _spy_post_centers.keys():
		var post_id := str(post_id_variant)
		var center: Vector2 = _spy_post_centers[post_id]
		if center.distance_to(local_point) <= (SPY_POST_RADIUS + 6.0):
			return post_id
	return ""

func get_board_space(space_id):
	_ensure_db_loaded()
	if board_spaces_by_id.has(space_id):
		return board_spaces_by_id[space_id]
	return null

func can_place_agent(space_id, player_state, board_occupancy = {}, played_card = {}, game_state = {}):
	if board_rules_adapter == null:
		return {"ok": false, "reason": "board_rules_adapter_missing"}
	return board_rules_adapter.can_place_agent(
		str(space_id),
		player_state if typeof(player_state) == TYPE_DICTIONARY else {},
		board_occupancy if typeof(board_occupancy) == TYPE_DICTIONARY else {},
		played_card if typeof(played_card) == TYPE_DICTIONARY else {},
		game_state if typeof(game_state) == TYPE_DICTIONARY else {},
		Callable(self, "get_board_space"),
		Callable(self, "_check_card_access"),
		Callable(self, "_check_requirements"),
		Callable(self, "_check_cost"),
		Callable(self, "_is_occupied"),
		Callable(self, "_has_spy_access")
	)

func place_agent(space_id, player_state, board_occupancy, agent_id = null, played_card = {}, game_state = {}):
	var validation = can_place_agent(space_id, player_state, board_occupancy, played_card, game_state)
	if not validation.get("ok", false):
		return validation

	var agents_available = int(player_state.get("agentsAvailable", 0))
	if agents_available <= 0:
		return {"ok": false, "reason": "no_agents_available"}

	var occupant = agent_id
	if occupant == null:
		occupant = str(player_state.get("id", "player")) + "_agent_" + str(agents_available)

	var spy_recalled_for_occupied := false
	var recalled_spy_post_id := ""
	if _is_occupied(space_id, board_occupancy):
		var player_id := str(player_state.get("id", ""))
		var connected_posts: Array = SpySystem.get_player_spy_post_ids_connected_to_space(game_state, player_id, str(space_id))
		if connected_posts.is_empty():
			return {"ok": false, "reason": "spy_required_for_occupied"}
		recalled_spy_post_id = str(connected_posts[0])
		var recall_result: Dictionary = SpySystem.recall_spy(game_state, player_id, recalled_spy_post_id)
		if not bool(recall_result.get("ok", false)):
			return {"ok": false, "reason": recall_result.get("reason", "spy_recall_failed")}
		spy_recalled_for_occupied = true

	var current_occupancy: Variant = board_occupancy.get(space_id, null)
	if current_occupancy == null:
		board_occupancy[space_id] = occupant
	elif typeof(current_occupancy) == TYPE_ARRAY:
		var occupancy_list: Array = current_occupancy
		occupancy_list.append(occupant)
		board_occupancy[space_id] = occupancy_list
	else:
		board_occupancy[space_id] = [str(current_occupancy), occupant]
	if typeof(game_state) == TYPE_DICTIONARY:
		_sync_markers(board_occupancy, game_state)
	else:
		_sync_markers(board_occupancy)

	player_state["agentsAvailable"] = agents_available - 1

	var agents_on_board = player_state.get("agentsOnBoard", [])
	if typeof(agents_on_board) != TYPE_ARRAY:
		agents_on_board = []
	agents_on_board.append(space_id)
	player_state["agentsOnBoard"] = agents_on_board

	var space_def = get_board_space(space_id)
	return {
		"ok": true,
		"spaceId": space_id,
		"occupantId": occupant,
		"cardId": str(played_card.get("id", "")),
		"effects": _duplicate_effects(space_def.get("effects", [])),
		"cost": _duplicate_effects(space_def.get("cost", [])),
		"isConflictSpace": bool(space_def.get("isConflictSpace", false)),
		"spyRecalledForOccupied": spy_recalled_for_occupied,
		"recalledSpyPostId": recalled_spy_post_id
	}

func take_agent_turn(space_id, player_state, game_state, context = {}):
	var board_occupancy = game_state.get("boardOccupancy", {})
	var agent_id = context.get("agent_id", null)
	var played_card = context.get("played_card", {})
	var player_id = str(player_state.get("id", "unknown_player"))

	var placed = place_agent(space_id, player_state, board_occupancy, agent_id, played_card, game_state)
	if not placed.get("ok", false):
		_append_game_log(game_state, {
			"type": "agent_turn_failed",
			"playerId": player_id,
			"spaceId": space_id,
			"reason": placed.get("reason", "unknown")
		})
		return placed

	game_state["boardOccupancy"] = board_occupancy
	_append_game_log(game_state, {
		"type": "agent_placed",
		"playerId": player_id,
		"spaceId": placed.get("spaceId", space_id),
		"occupantId": placed.get("occupantId", ""),
		"cardId": placed.get("cardId", "")
	})
	_apply_control_space_bonus(str(placed.get("spaceId", space_id)), player_id, game_state)
	if bool(placed.get("spyRecalledForOccupied", false)):
		_append_game_log(game_state, {
			"type": "spy_recalled_for_occupied_placement",
			"playerId": player_id,
			"spaceId": placed.get("spaceId", space_id),
			"postId": str(placed.get("recalledSpyPostId", ""))
		})

	# Mandatory space cost is paid before resolving effects.
	_apply_cost_items(placed.get("cost", []), player_state)
	_append_game_log(game_state, {
		"type": "space_cost_paid",
		"playerId": player_id,
		"spaceId": placed.get("spaceId", space_id),
		"cost": _duplicate_effects(placed.get("cost", []))
	})

	var pending_conflict: Dictionary = {}
	if bool(placed.get("isConflictSpace", false)):
		var garrison_before_effects: int = int(player_state.get("garrisonTroops", 0))
		pending_conflict = {
			"from_effect": 0,
			"from_garrison_max": garrison_before_effects if garrison_before_effects < 2 else 2
		}

	var resolved = resolve_space_effects(
		placed.get("effects", []),
		player_state,
		game_state,
		{
			"context": "agent",
			"space_id": space_id,
			"is_conflict_space": bool(placed.get("isConflictSpace", false)),
			"pending_conflict": pending_conflict,
			"played_card": context.get("played_card", {}),
			"agent_id": context.get("agent_id", null),
			"choice_indexes": context.get("choice_indexes", {})
		}
	)
	if bool(placed.get("isConflictSpace", false)):
		_prepare_conflict_deploy_choice(player_state, pending_conflict)
	_append_game_log(game_state, {
		"type": "space_effects_resolved",
		"playerId": player_id,
		"spaceId": placed.get("spaceId", space_id),
		"resolvedEffects": _duplicate_effects(resolved.get("resolvedEffects", []))
	})

	return {
		"ok": true,
		"spaceId": placed.get("spaceId", space_id),
		"occupantId": placed.get("occupantId", ""),
		"cardId": placed.get("cardId", ""),
		"isConflictSpace": placed.get("isConflictSpace", false),
		"spyRecalledForOccupied": bool(placed.get("spyRecalledForOccupied", false)),
		"paidCost": placed.get("cost", []),
		"resolvedEffects": resolved.get("resolvedEffects", []),
		"playerState": player_state,
		"gameState": game_state
	}

func _apply_control_space_bonus(space_id: String, acting_player_id: String, game_state: Dictionary) -> void:
	control_markers_service.apply_control_bonus_for_space(
		space_id,
		acting_player_id,
		game_state,
		CONTROL_BONUS_BY_SPACE,
		Callable(self, "_get_player_by_id"),
		Callable(self, "_change_resource"),
		Callable(self, "_append_game_log")
	)

func resolve_space_effects(effects, player_state, game_state = {}, context = {}):
	var normalized = _normalize_effects_with_aliases(_duplicate_effects(effects))
	if board_rules_adapter == null:
		return {"ok": false, "reason": "board_rules_adapter_missing"}
	return board_rules_adapter.resolve_space_effects(
		normalized,
		player_state if typeof(player_state) == TYPE_DICTIONARY else {},
		game_state if typeof(game_state) == TYPE_DICTIONARY else {},
		context if typeof(context) == TYPE_DICTIONARY else {},
		Callable(self, "_choice_option_is_choosable"),
		Callable(self, "_is_requirement_met"),
		Callable(self, "_apply_single_effect"),
		Callable(self, "_contains_effect_type"),
		Callable(self, "_update_shield_wall_visuals")
	)

func resolve_contract_completions_for_space(player_state: Dictionary, game_state: Dictionary, space_id: String) -> Dictionary:
	if player_state.is_empty() or space_id == "":
		return {"completedCount": 0, "completedContractIds": []}
	return ContractServiceScript.resolve_mandatory_completions_for_space(
		game_state,
		player_state,
		space_id,
		func(reward_effects: Array) -> void:
			resolve_space_effects(reward_effects, player_state, game_state, {
				"context": "contract_completion",
				"space_id": space_id
			}),
		func(entry: Dictionary) -> void:
			_append_game_log(game_state, entry)
	)

func get_pending_space_choice_context(space_id: String, player_state: Dictionary = {}, game_state: Dictionary = {}) -> Dictionary:
	_ensure_db_loaded()
	var space_def = get_board_space(space_id)
	if space_def == null:
		return {}

	var effects = _normalize_effects_with_aliases(space_def.get("effects", []))
	if typeof(effects) != TYPE_ARRAY:
		return {}

	var area_id := str(space_def.get("area", ""))
	var gs: Dictionary = game_state if typeof(game_state) == TYPE_DICTIONARY else {}
	var should_filter_choices: bool = typeof(player_state) == TYPE_DICTIONARY and not player_state.is_empty()

	var choice_slot := 0

	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		if str(effect.get("type", "")) != "choice":
			continue

		var options = effect.get("options", [])
		if typeof(options) != TYPE_ARRAY or options.is_empty():
			continue
		if options.size() <= 1:
			choice_slot += 1
			continue

		var effect_texts: PackedStringArray = []
		var original_indices: Array[int] = []
		for opt_idx in range(options.size()):
			var option = options[opt_idx]
			if typeof(option) != TYPE_DICTIONARY:
				continue
			if should_filter_choices and not _choice_option_is_choosable(option, player_state, gs):
				continue
			effect_texts.append(_choice_option_effects_tokens(option, effect, area_id, str(space_id), gs))
			original_indices.append(opt_idx)

		if effect_texts.is_empty():
			return {"noValidOptions": true, "slot": choice_slot, "spaceId": str(space_id), "title": str(space_def.get("name", space_id))}

		if effect_texts.size() == 1:
			return {
				"slot": choice_slot,
				"spaceId": str(space_id),
				"title": str(space_def.get("name", space_id)),
				"autoSelectOriginalIndex": original_indices[0]
			}

		return {
			"slot": choice_slot,
			"spaceId": str(space_id),
			"title": str(space_def.get("name", space_id)),
			"optionEffectsTexts": effect_texts,
			"optionOriginalIndices": original_indices
		}

	return {}

func get_pending_effect_choice_context(
	effects: Variant,
	player_state: Dictionary = {},
	game_state: Dictionary = {},
	context: Dictionary = {}
) -> Dictionary:
	if typeof(effects) != TYPE_ARRAY:
		return {}
	var pending: Array = _normalize_effects_with_aliases(_duplicate_effects(effects))
	var choice_indexes_raw: Variant = context.get("choice_indexes", {})
	var choice_indexes: Dictionary = choice_indexes_raw if typeof(choice_indexes_raw) == TYPE_DICTIONARY else {}
	var choice_title := str(context.get("choice_title", "Card effect"))
	var choice_area_id := str(context.get("choice_area_id", ""))
	var space_id := str(context.get("space_id", ""))
	var choice_slot := 0

	while pending.size() > 0:
		var effect: Variant = pending.pop_front()
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		var effect_dict: Dictionary = effect
		var effect_type := str(effect_dict.get("type", ""))
		if effect_type == "if":
			var requirement = effect_dict.get("requirement", {})
			var then_effects = effect_dict.get("then", [])
			var else_effects = effect_dict.get("else", [])
			var is_met: bool = bool(_is_requirement_met(requirement, player_state, context, game_state))
			var branch = then_effects if is_met else else_effects
			if typeof(branch) == TYPE_ARRAY:
				for i in range(branch.size() - 1, -1, -1):
					pending.push_front(branch[i])
			continue
		if effect_type != "choice":
			continue
		var options_raw: Variant = effect_dict.get("options", [])
		if typeof(options_raw) != TYPE_ARRAY:
			choice_slot += 1
			continue
		var options: Array = options_raw
		var executable_indices: Array[int] = []
		for opt_idx in range(options.size()):
			var option = options[opt_idx]
			if typeof(option) != TYPE_DICTIONARY:
				continue
			if _choice_option_is_choosable(option, player_state, game_state):
				executable_indices.append(opt_idx)
		if executable_indices.is_empty():
			choice_slot += 1
			continue
		var slot_key := str(choice_slot)
		var has_selected := choice_indexes.has(slot_key)
		if has_selected:
			var selected_idx := int(choice_indexes.get(slot_key, -1))
			if executable_indices.has(selected_idx) and selected_idx >= 0 and selected_idx < options.size():
				var selected_option: Dictionary = options[selected_idx]
				var selected_effects = selected_option.get("effects", [])
				if typeof(selected_effects) == TYPE_ARRAY:
					for i in range(selected_effects.size() - 1, -1, -1):
						pending.push_front(selected_effects[i])
			choice_slot += 1
			continue
		if executable_indices.size() == 1:
			var auto_selected: Dictionary = options[executable_indices[0]]
			var auto_effects = auto_selected.get("effects", [])
			if typeof(auto_effects) == TYPE_ARRAY:
				for i in range(auto_effects.size() - 1, -1, -1):
					pending.push_front(auto_effects[i])
			choice_slot += 1
			continue
		var option_effects_texts: PackedStringArray = []
		var option_original_indices: Array[int] = []
		for executable_idx in executable_indices:
			var option_dict: Dictionary = options[executable_idx]
			option_effects_texts.append(_choice_option_effects_tokens(option_dict, effect_dict, choice_area_id, space_id, game_state))
			option_original_indices.append(executable_idx)
		return {
			"slot": choice_slot,
			"title": choice_title,
			"optionEffectsTexts": option_effects_texts,
			"optionOriginalIndices": option_original_indices
		}
	return {}

func _choice_option_is_choosable(option: Dictionary, player_state: Dictionary, game_state: Dictionary) -> bool:
	var effects = option.get("effects", [])
	if typeof(effects) != TYPE_ARRAY:
		return false
	var sim_resources: Dictionary = _snapshot_player_resources(player_state)
	return _choice_option_effects_are_executable(effects, player_state, game_state, sim_resources)

func _snapshot_player_resources(player_state: Dictionary) -> Dictionary:
	var resources = player_state.get("resources", {})
	if typeof(resources) != TYPE_DICTIONARY:
		return {}
	return resources.duplicate(true)

func _choice_option_effects_are_executable(
	effects: Array,
	player_state: Dictionary,
	game_state: Dictionary,
	sim_resources: Dictionary
) -> bool:
	var contributed := false
	var normalized_effects := _normalize_effects_with_aliases(effects)
	for eff in normalized_effects:
		if typeof(eff) != TYPE_DICTIONARY:
			continue
		var effect_type := str(eff.get("type", ""))
		if effect_type == "if":
			var requirement = eff.get("requirement", {})
			var then_effects = eff.get("then", [])
			var else_effects = eff.get("else", [])
			if typeof(then_effects) != TYPE_ARRAY:
				then_effects = []
			if typeof(else_effects) != TYPE_ARRAY:
				else_effects = []
			if _is_requirement_met(requirement, player_state, {}, game_state):
				if _choice_option_effects_are_executable(then_effects, player_state, game_state, sim_resources):
					contributed = true
			else:
				if not else_effects.is_empty() and _choice_option_effects_are_executable(else_effects, player_state, game_state, sim_resources):
					contributed = true
			continue
		if effect_type == "spend_resource":
			var resource_id := str(eff.get("resource", ""))
			var amount := int(eff.get("amount", 0))
			var current := int(sim_resources.get(resource_id, 0))
			if current < amount:
				return false
			sim_resources[resource_id] = current - amount
			contributed = true
			continue
		if effect_type != "":
			contributed = true
	return contributed

func _choice_option_effects_tokens(
	option: Dictionary,
	parent_choice: Dictionary,
	space_area_id: String,
	space_id: String = "",
	game_state: Dictionary = {}
) -> String:
	var effs = option.get("effects", [])
	if _is_influence_choice(parent_choice):
		if typeof(effs) == TYPE_ARRAY and effs.size() == 1:
			var e = effs[0]
			if typeof(e) == TYPE_DICTIONARY and str(e.get("type", "")) == "gain_influence":
				var fac := str(e.get("faction", ""))
				if fac != "":
					return "[faction_icon:%s]" % fac
	# Same visual tokens as the board cell for maker-space spice vs sandworm (e.g. deep_desert, hagga_basin).
	var maker_worm_tokens := _maker_spice_worm_choice_option_tokens(option, parent_choice, space_id, game_state)
	if maker_worm_tokens != "":
		return maker_worm_tokens
	var sietch_choice := _extract_sietch_tabr_choice(parent_choice)
	if bool(sietch_choice.get("ok", false)):
		if typeof(effs) == TYPE_ARRAY and effs.size() == 2:
			return "[sietch_tabr_second_option:%d:%d]" % [
				int(sietch_choice.get("second_water", 0)),
				int(sietch_choice.get("second_shield_wall", 0))
			]
		return str(sietch_choice.get("first_tokens", ""))
	if _is_spice_refinery_trade_choice(parent_choice):
		if typeof(effs) == TYPE_ARRAY and effs.size() == 1:
			return "[spice_refinery_row0]"
		return "[spice_refinery_row1]"
	if _is_gather_support_trade_choice(parent_choice):
		if typeof(effs) == TYPE_ARRAY and effs.size() == 1:
			return "[gather_support_row0]"
		return "[gather_support_row1]"
	return _effects_to_text(effs, space_area_id)

func _get_collect_maker_spice_bonus_for_space(game_state: Dictionary, board_space_id: String) -> int:
	if typeof(game_state) != TYPE_DICTIONARY or board_space_id == "":
		return 0
	var maker: Variant = game_state.get("makerSpice", {})
	if typeof(maker) != TYPE_DICTIONARY:
		return 0
	return maxi(0, int(maker.get(board_space_id, 0)))

## When the parent is the two-option maker choice (spice vs conditional sandworm), match cell rendering: spice badge + sandworm icons.
## First option also includes collect_maker_spice pool for this space (same as the maker row on the cell).
func _maker_spice_worm_choice_option_tokens(
	option: Dictionary,
	parent_choice: Dictionary,
	space_id: String,
	game_state: Dictionary
) -> String:
	if not bool(_extract_maker_worm_choice(parent_choice).get("ok", false)):
		return ""
	var effs: Variant = option.get("effects", [])
	if typeof(effs) != TYPE_ARRAY or effs.is_empty():
		return ""
	if effs.size() != 1:
		return ""
	var e0: Variant = effs[0]
	if typeof(e0) != TYPE_DICTIONARY:
		return ""
	if str(e0.get("type", "")) == "gain_resource" and str(e0.get("resource", "")) == "spice":
		var option_spice := int(e0.get("amount", 0))
		var collect_bonus := _get_collect_maker_spice_bonus_for_space(game_state, space_id)
		if collect_bonus > 0:
			return "[maker_collect_spice_badge:%d] [spice_badge:%d]" % [collect_bonus, option_spice]
		return "[spice_badge:%d]" % option_spice
	if str(e0.get("type", "")) == "if":
		var then_arr: Variant = e0.get("then", [])
		if typeof(then_arr) == TYPE_ARRAY and then_arr.size() == 1:
			var te: Variant = then_arr[0]
			if typeof(te) == TYPE_DICTIONARY and str(te.get("type", "")) == "summon_sandworm":
				var w := int(te.get("amount", 0))
				return _repeat_token("[sand_worm_icon]", maxi(w, 1))
	return ""

func apply_game_state(game_state: Dictionary) -> void:
	var occupancy = game_state.get("boardOccupancy", {})
	if typeof(occupancy) != TYPE_DICTIONARY:
		occupancy = {}
	_sync_markers(occupancy, game_state)
	_update_shield_wall_visuals(game_state)
	_update_conflict_zone_labels(game_state)
	_update_influence_trackers(game_state)
	_update_vp_tracker(game_state)


func _update_shield_wall_visuals(game_state: Dictionary) -> void:
	if shield_wall_start_sprite == null:
		return
	var wall_intact := true
	if typeof(game_state) == TYPE_DICTIONARY:
		wall_intact = bool(game_state.get("shieldWallIntact", true))
	shield_wall_start_sprite.texture = (
		SHIELD_WALL_START_TEXTURE if wall_intact else SHIELD_WALL_DESTROYED_TEXTURE
	)

func _update_influence_trackers(game_state: Dictionary) -> void:
	var players = game_state.get("players", [])
	if typeof(players) != TYPE_ARRAY:
		players = []

	var emperor_values: Array[int] = []
	var guild_values: Array[int] = []
	var bene_gesserit_values: Array[int] = []
	var fremen_values: Array[int] = []

	for player in players:
		if typeof(player) != TYPE_DICTIONARY:
			continue
		var influence = player.get("influence", {})
		if typeof(influence) != TYPE_DICTIONARY:
			influence = {}
		emperor_values.append(int(influence.get("emperor", 0)))
		guild_values.append(int(influence.get("guild", 0)))
		bene_gesserit_values.append(int(influence.get("beneGesserit", 0)))
		fremen_values.append(int(influence.get("fremen", 0)))

	if emperor_tracker != null:
		emperor_tracker.set_player_values(emperor_values)
	if guild_tracker != null:
		guild_tracker.set_player_values(guild_values)
	if bene_gesserit_tracker != null:
		bene_gesserit_tracker.set_player_values(bene_gesserit_values)
	if fremen_tracker != null:
		fremen_tracker.set_player_values(fremen_values)

func _update_vp_tracker(game_state: Dictionary) -> void:
	if vp_tracker == null:
		return
	var players = game_state.get("players", [])
	if typeof(players) != TYPE_ARRAY:
		players = []
	var vp_values: Array[int] = []
	for player in players:
		if typeof(player) != TYPE_DICTIONARY:
			continue
		vp_values.append(int(player.get("vp", 0)))
	vp_tracker.set_player_values(vp_values)

func apply_maker_phase(game_state):
	_ensure_db_loaded()

	var board_occupancy = game_state.get("boardOccupancy", {})
	if typeof(board_occupancy) != TYPE_DICTIONARY:
		board_occupancy = {}
		game_state["boardOccupancy"] = board_occupancy

	# Ensure makerSpice structure exists.
	if typeof(game_state.get("makerSpice", null)) != TYPE_DICTIONARY:
		game_state["makerSpice"] = {}

	var maker_spice: Dictionary = game_state["makerSpice"]

	var maker_spaces_count := 0
	for space_id in board_spaces_by_id.keys():
		var space_def = board_spaces_by_id[space_id]
		if typeof(space_def) != TYPE_DICTIONARY:
			continue
		if not bool(space_def.get("makerSpace", false)):
			continue

		# Maker gains +1 bonus spice if no Agent is present on that board space.
		if not _is_occupied(space_id, board_occupancy):
			var current := int(maker_spice.get(space_id, 0))
			maker_spice[space_id] = current + 1
			maker_spaces_count += 1

	game_state["makerSpice"] = maker_spice
	_append_game_log(game_state, {
		"type": "maker_phase_resolved",
		"makerSpacesUpdated": maker_spaces_count
	})

	_sync_markers(board_occupancy, game_state)

	return maker_spice

func _sync_markers(board_occupancy, game_state = null):
	_ensure_db_loaded()
	var maker_spice: Dictionary = {}
	if game_state != null and typeof(game_state.get("makerSpice", null)) == TYPE_DICTIONARY:
		maker_spice = game_state["makerSpice"]
	var markers = get_tree().get_nodes_in_group("board_space_markers")
	for marker in markers:
		var marker_space_id = str(marker.board_space_id)
		var space_def = board_spaces_by_id.get(marker_space_id, {})
		if marker.has_method("set_display_name"):
			var display_name = str(space_def.get("name", marker_space_id.replace("_", " ").capitalize()))
			marker.set_display_name(display_name)
		if marker.has_method("set_cost_items"):
			var cost_items = space_def.get("cost", [])
			if typeof(cost_items) != TYPE_ARRAY:
				cost_items = []
			marker.set_cost_items(cost_items)
		if marker.has_method("set_effects_text"):
			marker.set_effects_text(_build_space_effects_text(space_def, game_state))
		if marker.has_method("set_control_marker_visible"):
			marker.set_control_marker_visible(CONTROL_MARKER_SPACE_IDS.has(marker_space_id))
		if marker.has_method("set_conflict_space_marker_visible"):
			marker.set_conflict_space_marker_visible(bool(space_def.get("isConflictSpace", false)))
		if marker.has_method("set_control_marker_owner_color"):
			var control_owner_id := ""
			if game_state != null:
				var raw_control_map: Variant = game_state.get("controlBySpace", {})
				if typeof(raw_control_map) == TYPE_DICTIONARY:
					control_owner_id = str(raw_control_map.get(marker_space_id, ""))
			var control_owner_index := _get_player_index_by_id(game_state, control_owner_id)
			var control_owner_color := Color(1, 1, 1, 1)
			if control_owner_index >= 0:
				control_owner_color = PLAYER_TOKEN_COLORS[control_owner_index % PLAYER_TOKEN_COLORS.size()]
			marker.set_control_marker_owner_color(control_owner_color, control_owner_id != "")
		if marker.has_method("set_control_bonus"):
			var bonus_visible := CONTROL_BONUS_BY_SPACE.has(marker_space_id)
			var bonus_resource := ""
			var bonus_amount := 0
			if bonus_visible:
				var bonus_def: Dictionary = CONTROL_BONUS_BY_SPACE[marker_space_id]
				bonus_resource = str(bonus_def.get("resource", ""))
				bonus_amount = int(bonus_def.get("amount", 0))
			marker.set_control_bonus(bonus_resource, bonus_amount, bonus_visible)
		if marker.has_method("set_required_icons"):
			var required_icons = space_def.get("requiredAgentIcons", [])
			if typeof(required_icons) != TYPE_ARRAY:
				required_icons = []
			marker.set_required_icons(required_icons)
		if marker.has_method("set_area"):
			marker.set_area(str(space_def.get("area", "")))
		if marker.has_method("set_occupant_id") and marker.has_method("clear_occupant"):
			var space_id = marker.board_space_id
			if board_occupancy.has(space_id):
				var occupants := _normalize_space_occupants(board_occupancy[space_id])
				if marker.has_method("set_occupants"):
					var occupant_colors: Array = []
					for occupant_id in occupants:
						var owner_player_id := _extract_player_id_from_occupant(str(occupant_id), game_state)
						var owner_index := _get_player_index_by_id(game_state, owner_player_id)
						var owner_color := Color(1, 1, 1, 1)
						if owner_index >= 0:
							owner_color = PLAYER_TOKEN_COLORS[owner_index % PLAYER_TOKEN_COLORS.size()]
						occupant_colors.append(owner_color)
					marker.set_occupants(occupants, occupant_colors)
				else:
					var occupant_id := str(occupants[0]) if not occupants.is_empty() else ""
					marker.set_occupant_id(occupant_id)
					if marker.has_method("set_occupant_player_color"):
						var owner_player_id := _extract_player_id_from_occupant(occupant_id, game_state)
						var owner_index := _get_player_index_by_id(game_state, owner_player_id)
						var owner_color := Color(1, 1, 1, 1)
						if owner_index >= 0:
							owner_color = PLAYER_TOKEN_COLORS[owner_index % PLAYER_TOKEN_COLORS.size()]
						marker.set_occupant_player_color(owner_color, owner_player_id != "")
			else:
				marker.clear_occupant()
		if marker.has_method("set_highlighted"):
			marker.set_highlighted(highlighted_space_ids.has(str(marker.board_space_id)))
		if marker.has_method("set_maker_spice_state"):
			var is_maker_space := bool(space_def.get("makerSpace", false))
			var base_spice := int(space_def.get("makerBaseSpice", 0))
			var accumulated := int(maker_spice.get(marker_space_id, 0))
			marker.set_maker_spice_state(is_maker_space, base_spice, accumulated)
	_refresh_spy_posts_visuals(game_state)

func _refresh_spy_posts_visuals(game_state: Variant = null) -> void:
	var board_spaces_root := get_node_or_null("BoardSpaces")
	if board_spaces_root == null:
		return

	_spy_space_positions.clear()
	for child in board_spaces_root.get_children():
		if not (child is Node2D):
			continue
		var marker := child as Node2D
		_spy_space_positions[str(marker.name)] = marker.position

	var has_game_state := typeof(game_state) == TYPE_DICTIONARY
	if has_game_state:
		_spy_draw_game_state = game_state
		SpySystem.ensure_spy_state(game_state)
		var gs_connections: Variant = game_state.get("spyPostConnections", {})
		if typeof(gs_connections) == TYPE_DICTIONARY and not gs_connections.is_empty():
			_spy_post_connections_by_id = gs_connections
		var gs_occupancy: Variant = game_state.get("spyPostsOccupancy", {})
		if typeof(gs_occupancy) == TYPE_DICTIONARY:
			_spy_posts_occupancy = gs_occupancy
		else:
			_spy_posts_occupancy = {}
	else:
		_spy_draw_game_state = {}
		_spy_posts_occupancy = {}

	_spy_post_centers.clear()
	for post_id in _spy_post_connections_by_id.keys():
		var center := _compute_spy_post_center(_spy_post_connections_by_id.get(post_id, []))
		if center != Vector2.INF:
			_spy_post_centers[str(post_id)] = center
	queue_redraw()

func _compute_spy_post_center(connected_spaces: Variant) -> Vector2:
	if typeof(connected_spaces) != TYPE_ARRAY:
		return Vector2.INF
	var points: Array[Vector2] = []
	for space_id_variant in connected_spaces:
		var space_id := str(space_id_variant)
		if _spy_space_positions.has(space_id):
			points.append(_spy_space_positions[space_id])
	if points.is_empty():
		return Vector2.INF
	if _is_faction_pair_spy_post(connected_spaces):
		var top := points[0]
		var bottom := points[0]
		for point in points:
			if point.y < top.y:
				top = point
			if point.y > bottom.y:
				bottom = point
		var mid_y := (top.y + bottom.y) * 0.5
		var right_x := maxf(top.x, bottom.x) + SPY_FACTION_POST_RIGHT_OFFSET
		return Vector2(right_x, mid_y)
	if points.size() == 1:
		return points[0] + Vector2(0, -88)
	if points.size() == 2:
		if _is_vertical_pair_points(points):
			var p0 := points[0]
			var p1 := points[1]
			var mid_y := (p0.y + p1.y) * 0.5
			var right_x := maxf(p0.x, p1.x) + SPY_FACTION_POST_RIGHT_OFFSET
			return Vector2(right_x, mid_y)
		return (points[0] + points[1]) * 0.5
	if points.size() == 3 and _is_orthogonal_triplet_points(points):
		return _bounding_box_center(points)
	return _compute_geometric_median(points)

func _is_vertical_pair_points(points: Array[Vector2]) -> bool:
	if points.size() != 2:
		return false
	var p0 := points[0]
	var p1 := points[1]
	var dx := absf(p0.x - p1.x)
	var dy := absf(p0.y - p1.y)
	return dy > dx

func _is_orthogonal_triplet_points(points: Array[Vector2]) -> bool:
	if points.size() != 3:
		return false
	var unique_x: Array[float] = []
	var unique_y: Array[float] = []
	for point in points:
		var has_x := false
		for x in unique_x:
			if absf(x - point.x) <= 0.5:
				has_x = true
				break
		if not has_x:
			unique_x.append(point.x)

		var has_y := false
		for y in unique_y:
			if absf(y - point.y) <= 0.5:
				has_y = true
				break
		if not has_y:
			unique_y.append(point.y)
	return unique_x.size() == 2 and unique_y.size() == 2

func _bounding_box_center(points: Array[Vector2]) -> Vector2:
	if points.is_empty():
		return Vector2.INF
	var min_x := points[0].x
	var max_x := points[0].x
	var min_y := points[0].y
	var max_y := points[0].y
	for point in points:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_y = minf(min_y, point.y)
		max_y = maxf(max_y, point.y)
	return Vector2((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)

func _compute_geometric_median(points: Array[Vector2]) -> Vector2:
	if points.is_empty():
		return Vector2.INF
	if points.size() == 1:
		return points[0]
	var current := Vector2.ZERO
	for point in points:
		current += point
	current /= float(points.size())

	for _i in range(SPY_GEOMETRIC_MEDIAN_ITERATIONS):
		var weighted_sum := Vector2.ZERO
		var weight_total := 0.0
		var snapped_to_existing := false
		for point in points:
			var dist := current.distance_to(point)
			if dist <= SPY_GEOMETRIC_MEDIAN_EPSILON:
				current = point
				snapped_to_existing = true
				break
			var weight := 1.0 / dist
			weighted_sum += point * weight
			weight_total += weight
		if snapped_to_existing:
			break
		if weight_total <= 0.0:
			break
		var next := weighted_sum / weight_total
		if current.distance_to(next) <= SPY_GEOMETRIC_MEDIAN_EPSILON:
			current = next
			break
		current = next
	return current

func _is_faction_pair_spy_post(connected_spaces: Variant) -> bool:
	if typeof(connected_spaces) != TYPE_ARRAY or connected_spaces.size() != 2:
		return false
	var first_space_id := str(connected_spaces[0])
	var second_space_id := str(connected_spaces[1])
	if not board_spaces_by_id.has(first_space_id) or not board_spaces_by_id.has(second_space_id):
		return false
	var first_def: Variant = board_spaces_by_id[first_space_id]
	var second_def: Variant = board_spaces_by_id[second_space_id]
	if typeof(first_def) != TYPE_DICTIONARY or typeof(second_def) != TYPE_DICTIONARY:
		return false
	var first_area := str(first_def.get("area", ""))
	var second_area := str(second_def.get("area", ""))
	if first_area == "" or second_area == "":
		return false
	return first_area == second_area and FACTION_AREAS.has(first_area)

func _draw_spy_post_connection(center: Vector2, to_pos: Vector2, owner_color: Color) -> void:
	var line_color := Color(owner_color.r, owner_color.g, owner_color.b, 0.62)
	var dx := absf(center.x - to_pos.x)
	var dy := absf(center.y - to_pos.y)
	var corner := Vector2(center.x, to_pos.y) if dx >= dy else Vector2(to_pos.x, center.y)
	var start := _space_border_anchor(to_pos, corner)
	draw_polyline(PackedVector2Array([start, corner, center]), line_color, SPY_POST_LINE_WIDTH)

func _space_border_anchor(space_center: Vector2, toward: Vector2) -> Vector2:
	var dir := toward - space_center
	if dir.length_squared() <= 0.0001:
		return space_center
	var half := BOARD_SPACE_HALF_SIZE + Vector2.ONE * BOARD_SPACE_LINE_PADDING
	var tx := INF
	var ty := INF
	if absf(dir.x) > 0.0001:
		tx = half.x / absf(dir.x)
	if absf(dir.y) > 0.0001:
		ty = half.y / absf(dir.y)
	var t := minf(tx, ty)
	if not is_finite(t):
		return space_center
	return space_center + dir * t

func _load_spy_post_connections(path: String = SPY_POSTS_DB_PATH) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		return {}
	var by_post := {}
	for item in parsed:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var post_id := str(item.get("id", ""))
		if post_id == "":
			continue
		var spaces = item.get("connectedSpaces", [])
		if typeof(spaces) != TYPE_ARRAY:
			spaces = []
		by_post[post_id] = spaces
	return by_post

func _sync_marker_highlights() -> void:
	var markers = get_tree().get_nodes_in_group("board_space_markers")
	for marker in markers:
		if marker.has_method("set_highlighted"):
			marker.set_highlighted(highlighted_space_ids.has(str(marker.board_space_id)))

func _apply_faction_vertical_spacing() -> void:
	_ensure_db_loaded()
	var faction_markers: Array[Node2D] = []
	var markers = get_tree().get_nodes_in_group("board_space_markers")
	for marker_variant in markers:
		var marker := marker_variant as Node2D
		if marker == null:
			continue
		var space_id := str(marker.get("board_space_id"))
		var space_def = board_spaces_by_id.get(space_id, {})
		if typeof(space_def) != TYPE_DICTIONARY:
			continue
		var area_id := str(space_def.get("area", ""))
		if not FACTION_AREAS.has(area_id):
			continue
		faction_markers.append(marker)

	if faction_markers.size() <= 1:
		return

	faction_markers.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.position.y < b.position.y
	)

	var min_center_distance: float = BOARD_SLOT_HEIGHT + BOARD_SLOT_VERTICAL_GAP
	var prev_y: float = faction_markers[0].position.y
	for i in range(1, faction_markers.size()):
		var marker: Node2D = faction_markers[i]
		var target_y: float = prev_y + min_center_distance
		if marker.position.y < target_y:
			marker.position = Vector2(marker.position.x, target_y)
		prev_y = marker.position.y

func _is_occupied(space_id, board_occupancy):
	if board_occupancy.has(space_id):
		var value: Variant = board_occupancy[space_id]
		if value == null:
			return false
		if typeof(value) == TYPE_ARRAY:
			return not (value as Array).is_empty()
		return str(value) != ""
	return false

func _normalize_space_occupants(occupancy_entry: Variant) -> Array:
	var occupants: Array = []
	if occupancy_entry == null:
		return occupants
	if typeof(occupancy_entry) == TYPE_ARRAY:
		for item in occupancy_entry:
			var occupant_id := str(item)
			if occupant_id != "":
				occupants.append(occupant_id)
		return occupants
	var single_id := str(occupancy_entry)
	if single_id != "":
		occupants.append(single_id)
	return occupants

func _check_requirements(space_def, player_state, played_card: Dictionary = {}):
	if not space_def.has("requirements"):
		return {"ok": true}

	var played_card_id := str(played_card.get("id", ""))
	for requirement in space_def["requirements"]:
		# Undercover Asset ignores Influence requirements for the placement made with this card.
		if played_card_id == "imperium_undercover_asset" and typeof(requirement) == TYPE_DICTIONARY and str(requirement.get("type", "")) == "min_influence":
			continue
		if not _is_requirement_met(requirement, player_state):
			return {
				"ok": false,
				"reason": "requirement_not_met",
				"requirement": requirement
			}
	return {"ok": true}

func _is_requirement_met(requirement, player_state, context: Dictionary = {}, game_state: Dictionary = {}):
	if typeof(requirement) != TYPE_DICTIONARY or not requirement.has("type"):
		return true

	var req_type = str(requirement["type"])
	if req_type == "min_influence":
		var faction = str(requirement.get("faction", ""))
		var value = int(requirement.get("value", 0))
		var influence = int(player_state.get("influence", {}).get(faction, 0))
		return influence >= value

	if req_type == "has_maker_hooks":
		var expected = bool(requirement.get("value", true))
		var has_hooks = bool(player_state.get("hasMakerHooks", false))
		return has_hooks == expected

	if req_type == "has_alliance":
		var alliance_faction := str(requirement.get("faction", ""))
		var expected_alliance := bool(requirement.get("value", true))
		var alliances = player_state.get("alliances", {})
		var has_alliance := false
		if typeof(alliances) == TYPE_DICTIONARY:
			has_alliance = bool(alliances.get(alliance_faction, false))
		return has_alliance == expected_alliance

	if req_type == "flag":
		var key = str(requirement.get("key", ""))
		var expected_flag = requirement.get("value", true)
		var flags = player_state.get("flags", {})
		return flags.get(key, false) == expected_flag

	if req_type == "sent_agent_to_maker_space_this_turn":
		var expected_sent = bool(requirement.get("value", true))
		var sent_maker = bool(context.get("sent_agent_to_maker_space_this_turn", false))
		if not sent_maker:
			var turn_flags_raw = player_state.get("turnFlags", {})
			var turn_flags: Dictionary = turn_flags_raw if typeof(turn_flags_raw) == TYPE_DICTIONARY else {}
			sent_maker = bool(turn_flags.get("sent_agent_to_maker_space_this_turn", false))
		return sent_maker == expected_sent

	if req_type == "recalled_spy_this_turn":
		var expected_recalled = bool(requirement.get("value", true))
		var recalled_now = bool(context.get("recalled_spy_this_turn", false))
		if not recalled_now:
			var turn_flags_raw = player_state.get("turnFlags", {})
			var turn_flags: Dictionary = turn_flags_raw if typeof(turn_flags_raw) == TYPE_DICTIONARY else {}
			recalled_now = bool(turn_flags.get("recalled_spy_this_turn", false))
		return recalled_now == expected_recalled

	if req_type == "spying_on_maker_space":
		var expected_spying = bool(requirement.get("value", true))
		var spy_connected_raw = player_state.get("spyConnectedSpaces", [])
		var spy_connected: Array = spy_connected_raw if typeof(spy_connected_raw) == TYPE_ARRAY else []
		var has_maker_spy := false
		for sid_variant in spy_connected:
			var sid := str(sid_variant)
			var board_space: Variant = board_spaces_by_id.get(sid, {})
			if typeof(board_space) == TYPE_DICTIONARY and bool((board_space as Dictionary).get("makerSpace", false)):
				has_maker_spy = true
				break
		return has_maker_spy == expected_spying

	if req_type == "has_fremen_bond":
		var expected_bond = bool(requirement.get("value", true))
		var cards_by_id_raw = game_state.get("cardsById", {})
		var cards_by_id: Dictionary = cards_by_id_raw if typeof(cards_by_id_raw) == TYPE_DICTIONARY else {}
		var hand_raw = player_state.get("hand", [])
		var hand_cards: Array = hand_raw if typeof(hand_raw) == TYPE_ARRAY else []
		var in_play_raw = player_state.get("inPlay", [])
		var in_play_cards: Array = in_play_raw if typeof(in_play_raw) == TYPE_ARRAY else []
		var fremen_count := 0
		for cid_variant in hand_cards:
			var cid := str(cid_variant)
			var cdef: Variant = cards_by_id.get(cid, {})
			if typeof(cdef) != TYPE_DICTIONARY:
				continue
			var tags_raw = (cdef as Dictionary).get("tags", [])
			if typeof(tags_raw) != TYPE_ARRAY:
				continue
			if (tags_raw as Array).has("fremen"):
				fremen_count += 1
		for cid_variant in in_play_cards:
			var cid := str(cid_variant)
			var cdef: Variant = cards_by_id.get(cid, {})
			if typeof(cdef) != TYPE_DICTIONARY:
				continue
			var tags_raw = (cdef as Dictionary).get("tags", [])
			if typeof(tags_raw) != TYPE_ARRAY:
				continue
			if (tags_raw as Array).has("fremen"):
				fremen_count += 1
		var has_bond := fremen_count >= 2
		return has_bond == expected_bond

	if req_type == "has_another_card_in_play_tag":
		var tag = str(requirement.get("tag", ""))
		if tag == "":
			return false
		var expected_has = bool(requirement.get("value", true))
		var card_id = str(context.get("card_id", ""))
		var cards_by_id_raw = game_state.get("cardsById", {})
		var cards_by_id: Dictionary = cards_by_id_raw if typeof(cards_by_id_raw) == TYPE_DICTIONARY else {}
		var in_play_raw = player_state.get("inPlay", [])
		var in_play_cards: Array = in_play_raw if typeof(in_play_raw) == TYPE_ARRAY else []
		var has_other := false
		for cid_variant in in_play_cards:
			var cid := str(cid_variant)
			if cid == "" or cid == card_id:
				continue
			var cdef: Variant = cards_by_id.get(cid, {})
			if typeof(cdef) != TYPE_DICTIONARY:
				continue
			var tags_raw = (cdef as Dictionary).get("tags", [])
			if typeof(tags_raw) != TYPE_ARRAY:
				continue
			if (tags_raw as Array).has(tag):
				has_other = true
				break
		return has_other == expected_has

	if req_type == "discarded_card_has_tag":
		var expected_discarded = bool(requirement.get("value", true))
		var tag = str(requirement.get("tag", ""))
		var discarded_id = str(context.get("last_discarded_card_id", ""))
		var cards_by_id_raw = game_state.get("cardsById", {})
		var cards_by_id: Dictionary = cards_by_id_raw if typeof(cards_by_id_raw) == TYPE_DICTIONARY else {}
		var matches := false
		if discarded_id != "" and cards_by_id.has(discarded_id):
			var cdef: Variant = cards_by_id.get(discarded_id, {})
			if typeof(cdef) == TYPE_DICTIONARY:
				var tags_raw = (cdef as Dictionary).get("tags", [])
				if typeof(tags_raw) == TYPE_ARRAY and (tags_raw as Array).has(tag):
					matches = true
		return matches == expected_discarded

	if req_type == "completed_contracts_at_least":
		var threshold := int(requirement.get("value", 0))
		var completed := int(player_state.get("completedContracts", 0))
		return completed >= threshold
	if req_type == "has_spies_at_least":
		var min_spies := int(requirement.get("value", 0))
		var player_id := str(player_state.get("id", ""))
		var spy_posts: Array = SpySystem.get_player_spy_post_ids(game_state, player_id)
		return spy_posts.size() >= min_spies
	if req_type == "has_swordmaster":
		var expected_has_swordmaster := bool(requirement.get("value", true))
		var has_swordmaster := int(player_state.get("agentsTotal", 2)) >= 3
		return has_swordmaster == expected_has_swordmaster
	if req_type == "units_in_conflict_at_least":
		var threshold_units := int(requirement.get("value", 0))
		var troops := int(player_state.get("troopsInConflict", 0))
		var worms := int(player_state.get("sandwormsInConflict", 0))
		return (troops + worms) >= threshold_units

	return true

func _check_cost(space_def, player_state):
	if not space_def.has("cost"):
		return {"ok": true}

	var resources = player_state.get("resources", {})
	for cost_item in space_def["cost"]:
		if typeof(cost_item) != TYPE_DICTIONARY:
			continue
		if str(cost_item.get("type", "")) != "resource":
			continue

		var resource = str(cost_item.get("resource", ""))
		var amount = int(cost_item.get("amount", 0))
		var current_amount = int(resources.get(resource, 0))
		if current_amount < amount:
			return {
				"ok": false,
				"reason": "insufficient_resource",
				"resource": resource,
				"required": amount,
				"current": current_amount
			}

	return {"ok": true}

func _check_card_access(space_def, played_card, player_state, game_state, space_id):
	if typeof(played_card) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "missing_played_card"}
	if not played_card.has("agentIcons"):
		return {"ok": false, "reason": "played_card_has_no_agent_icons"}

	var space_icons = space_def.get("requiredAgentIcons", [])
	var card_icons = played_card.get("agentIcons", [])
	if typeof(space_icons) != TYPE_ARRAY or space_icons.is_empty():
		return {"ok": true}
	if typeof(card_icons) != TYPE_ARRAY or card_icons.is_empty():
		return {"ok": false, "reason": "card_icons_empty"}

	var normalized_space_icons: Array = []
	for icon in space_icons:
		normalized_space_icons.append(_normalize_icon_id(str(icon)))

	for icon in card_icons:
		var normalized_icon := _normalize_icon_id(str(icon))
		if normalized_space_icons.has(normalized_icon):
			return {"ok": true}

	# Spy icon can open access to connected spaces with your active spy.
	if card_icons.has("spy") or card_icons.has("infiltrate"):
		if _has_spy_access(space_id, player_state, game_state):
			return {"ok": true, "access": "spy"}
		return {"ok": false, "reason": "spy_access_missing"}

	return {
		"ok": false,
		"reason": "card_icon_mismatch",
		"requiredIcons": _duplicate_effects(space_icons),
		"cardIcons": _duplicate_effects(card_icons)
	}

func _normalize_icon_id(icon_id: String) -> String:
	match icon_id:
		"spacing_guild":
			return "guild"
		"bene_gesserit":
			return "beneGesserit"
		"spice_trade":
			return "spice"
		_:
			return icon_id

func _has_spy_access(space_id, player_state, game_state):
	var space_id_str = str(space_id)
	var player_id = str(player_state.get("id", ""))

	# Option A: per-player list in player state.
	var connected_spaces = player_state.get("spyConnectedSpaces", [])
	if typeof(connected_spaces) == TYPE_ARRAY and connected_spaces.has(space_id_str):
		return true

	# Option B: centralized map in game state, auto-rebuilt from spy posts.
	SpySystem.rebuild_access_by_player(game_state)
	var by_player = game_state.get("spyAccessByPlayer", {})
	if typeof(by_player) == TYPE_DICTIONARY and by_player.has(player_id):
		var list_for_player = by_player[player_id]
		if typeof(list_for_player) == TYPE_ARRAY and list_for_player.has(space_id_str):
			return true

	return false

func _duplicate_effects(effects):
	return EffectDslScript.duplicate_effects(effects)

func _apply_single_effect(effect, player_state, game_state, context):
	var out_of_scope_disabled := true
	var rules_config = game_state.get("rulesConfig", {})
	if typeof(rules_config) == TYPE_DICTIONARY:
		out_of_scope_disabled = not bool(rules_config.get("enableOutOfScopeSystems", false))

	if effect_resolver != null and effect_resolver.apply_single_effect(effect, player_state, game_state, context):
		return

	var effect_type = str(effect.get("type", ""))
	var amount = int(effect.get("amount", 0))
	# summon_sandworm / gain_maker_hooks are implemented below; do not skip when out-of-scope guard is on.
	if out_of_scope_disabled and (
		effect_type == "remove_shield_wall"
	):
		return

	if effect_type == "deploy_to_conflict":
		_commit_garrison_troops_to_conflict(player_state, game_state, amount)
		return
	if effect_type == "retreat_from_conflict":
		var retreat_amount: int = maxi(amount, 0)
		var in_conflict := int(player_state.get("troopsInConflict", 0))
		var actual_retreat: int = mini(in_conflict, retreat_amount)
		if actual_retreat <= 0:
			return
		player_state["troopsInConflict"] = in_conflict - actual_retreat
		player_state["garrisonTroops"] = int(player_state.get("garrisonTroops", 0)) + actual_retreat
		return


	if effect_type == "get_contract" or effect_type == "take_contract":
		var fallback_effects = effect.get("fallbackEffects", [])
		var effect_context := str(context.get("context", ""))
		var use_pending_choice := (
			effect_context == "agent"
			or effect_context == "reveal"
			or effect_context == "purchase"
			or effect_context == "conflict"
		)
		if use_pending_choice:
			ContractServiceScript.queue_contract_choice_for_player(
				game_state,
				player_state,
				maxi(amount, 1),
				fallback_effects,
				func(fallback_to_apply: Array) -> void:
					resolve_space_effects(fallback_to_apply, player_state, game_state, context),
				func(entry: Dictionary) -> void:
					_append_game_log(game_state, entry)
			)
		else:
			ContractServiceScript.resolve_get_contract_effect(
				game_state,
				player_state,
				maxi(amount, 1),
				fallback_effects,
				func(fallback_to_apply: Array) -> void:
					resolve_space_effects(fallback_to_apply, player_state, game_state, context),
				func(entry: Dictionary) -> void:
					_append_game_log(game_state, entry)
			)
		return

	if effect_type == "place_spy":
		var player_id = str(player_state.get("id", ""))
		var requested_post_id = str(context.get("spy_post_id", ""))
		var allow_shared_post := str(context.get("card_id", "")) == "imperium_double_agent"
		if requested_post_id != "":
			var place_result = SpySystem.place_spy(game_state, player_id, requested_post_id, allow_shared_post)
			if place_result.get("ok", false):
				_append_game_log(game_state, {
					"type": "spy_placed",
					"playerId": player_id,
					"postId": requested_post_id
				})
			else:
				player_state["pendingPlaceSpy"] = int(player_state.get("pendingPlaceSpy", 0)) + amount
		else:
			player_state["pendingPlaceSpy"] = int(player_state.get("pendingPlaceSpy", 0)) + amount
		return

	if effect_type == "recall_agent":
		_recall_agents_from_board(player_state, game_state, amount, bool(effect.get("excludeJustPlaced", false)), str(context.get("space_id", "")))
		return

	if effect_type == "gain_agent":
		if str(effect.get("which", "")) == "swordmaster":
			var gained: int = int(max(amount, 0))
			var new_total: int = int(max(int(player_state.get("agentsTotal", 2)) + gained, 0))
			player_state["agentsTotal"] = new_total
			player_state["agentsAvailable"] = min(int(player_state.get("agentsAvailable", 0)) + gained, new_total)
		return

	if effect_type == "gain_maker_hooks":
		player_state["hasMakerHooks"] = true
		return

	if effect_type == "collect_maker_spice":
		var maker = game_state.get("makerSpice", {})
		var board_space_id = str(effect.get("boardSpaceId", ""))
		var bonus = int(maker.get(board_space_id, 0))
		if bonus > 0:
			_change_resource(player_state, "spice", bonus)
			maker[board_space_id] = 0
			game_state["makerSpice"] = maker
		return

	if effect_type == "summon_sandworm":
		if amount <= 0:
			return
		var player_id := str(player_state.get("id", ""))
		if _is_sandworm_blocked_by_shield_wall(game_state):
			var blocked_reason := "shield_wall_protected_conflict"
			_append_game_log(game_state, {
				"type": "sandworm_summon_blocked",
				"playerId": player_id,
				"amount": amount,
				"reason": blocked_reason
			})
			game_state["lastConflictNotice"] = {
				"type": "sandworm_summon_blocked",
				"playerId": player_id,
				"reason": blocked_reason
			}
			return
		_add_sandworms_to_conflict(player_state, game_state, amount)
		_append_game_log(game_state, {
			"type": "sandworm_summoned_to_conflict",
			"playerId": player_id,
			"amount": amount,
			"sandwormsInConflictAfter": int(player_state.get("sandwormsInConflict", 0))
		})
		game_state["lastConflictNotice"] = {
			"type": "sandworm_summoned",
			"playerId": player_id,
			"amount": amount
		}
		return

	if effect_type == "remove_shield_wall":
		game_state["shieldWallIntact"] = false
		_update_shield_wall_visuals(game_state)
		return

	if effect_type == "set_flag":
		var flags = player_state.get("flags", {})
		flags[str(effect.get("key", ""))] = bool(effect.get("value", false))
		player_state["flags"] = flags
		return

	if effect_type == "gain_persuasion_per_completed_contract":
		var per_amount: int = maxi(amount, 0)
		var completed_contracts: int = maxi(int(player_state.get("completedContracts", 0)), 0)
		player_state["persuasion"] = int(player_state.get("persuasion", 0)) + (completed_contracts * per_amount)
		return

	if effect_type == "draw_cards_per_sandworm_in_conflict":
		var per_amount_draw: int = maxi(amount, 0)
		var worms_in_conflict: int = maxi(int(player_state.get("sandwormsInConflict", 0)), 0)
		player_state["pendingDrawCards"] = int(player_state.get("pendingDrawCards", 0)) + (worms_in_conflict * per_amount_draw)
		return

	if effect_type == "opponents_discard_card":
		var players_raw: Variant = game_state.get("players", [])
		if typeof(players_raw) != TYPE_ARRAY:
			return
		var current_player_id := str(player_state.get("id", ""))
		var discard_amount := maxi(amount, 1)
		for entry in players_raw:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var opponent: Dictionary = entry
			if str(opponent.get("id", "")) == current_player_id:
				continue
			var hand_raw: Variant = opponent.get("hand", [])
			var hand: Array = hand_raw if typeof(hand_raw) == TYPE_ARRAY else []
			var discard_raw: Variant = opponent.get("discard", [])
			var discard: Array = discard_raw if typeof(discard_raw) == TYPE_ARRAY else []
			for _i in range(discard_amount):
				if hand.is_empty():
					break
				var discarded_id := str(hand.pop_front())
				if discarded_id == "":
					continue
				discard.append(discarded_id)
				_apply_on_discard_effects_for_card(discarded_id, opponent, game_state, context)
			opponent["hand"] = hand
			opponent["discard"] = discard
		return

	if effect_type == "return_this_card_to_hand":
		context["return_this_card_to_hand"] = true
		return

	if effect_type == "gain_persuasion_per_in_play_tag":
		var tag := str(effect.get("tag", ""))
		if tag == "":
			return
		var cards_by_id_raw = game_state.get("cardsById", {})
		var cards_by_id: Dictionary = cards_by_id_raw if typeof(cards_by_id_raw) == TYPE_DICTIONARY else {}
		var in_play_raw = player_state.get("inPlay", [])
		var in_play_cards: Array = in_play_raw if typeof(in_play_raw) == TYPE_ARRAY else []
		var count := 0
		for cid_variant in in_play_cards:
			var cid := str(cid_variant)
			var cdef: Variant = cards_by_id.get(cid, {})
			if typeof(cdef) != TYPE_DICTIONARY:
				continue
			var tags_raw = (cdef as Dictionary).get("tags", [])
			if typeof(tags_raw) == TYPE_ARRAY and (tags_raw as Array).has(tag):
				count += 1
		player_state["persuasion"] = int(player_state.get("persuasion", 0)) + (count * max(amount, 0))
		return

	if effect_type == "gain_persuasion_per_revealed_tag":
		var tag_reveal_persuasion := str(effect.get("tag", ""))
		if tag_reveal_persuasion == "":
			return
		var reveal_count := _count_revealed_cards_with_tag(context, game_state, player_state, tag_reveal_persuasion, bool(effect.get("include_this_card", false)))
		player_state["persuasion"] = int(player_state.get("persuasion", 0)) + (reveal_count * max(amount, 0))
		return

	if effect_type == "gain_sword_per_revealed_tag":
		var tag := str(effect.get("tag", ""))
		if tag == "":
			return
		var count := _count_revealed_cards_with_tag(context, game_state, player_state, tag, bool(effect.get("include_this_card", false)))
		player_state["revealedSwordPower"] = int(player_state.get("revealedSwordPower", 0)) + (count * max(amount, 0))
		return

	if effect_type == "recall_spy_for_effect":
		var player_id_recall := str(player_state.get("id", ""))
		var recall_count := maxi(amount, 1)
		var available_recall: Array = SpySystem.get_player_spy_post_ids(game_state, player_id_recall)
		if available_recall.size() < recall_count:
			return
		player_state["pendingSpyRecallDrawCards"] = recall_count
		player_state["pendingSpyRecallDrawGrantCards"] = 0
		player_state["pendingSpyRecallDrawPostIds"] = available_recall
		player_state["pendingSpyRecallDrawSpaceId"] = "reveal_recall_spy_for_effect"
		var reward_effects_raw: Variant = effect.get("rewardEffects", [])
		player_state["pendingSpyRecallRewardEffects"] = reward_effects_raw if typeof(reward_effects_raw) == TYPE_ARRAY else []
		return

	if effect_type == "discard_card":
		var from_zone := str(effect.get("from", "hand"))
		var discard_count: int = maxi(amount, 0)
		var hand_raw = player_state.get(from_zone, [])
		var hand_cards: Array = hand_raw if typeof(hand_raw) == TYPE_ARRAY else []
		var discard_pile_raw = player_state.get("discard", [])
		var discard_pile: Array = discard_pile_raw if typeof(discard_pile_raw) == TYPE_ARRAY else []
		for _i in range(discard_count):
			if hand_cards.is_empty():
				break
			var moved_card = str(hand_cards.pop_front())
			if moved_card != "":
				discard_pile.append(moved_card)
				context["last_discarded_card_id"] = moved_card
				_apply_on_discard_effects_for_card(moved_card, player_state, game_state, context)
		player_state[from_zone] = hand_cards
		player_state["discard"] = discard_pile
		return

	if effect_type == "trash_intrigue":
		var intrigue_raw = player_state.get("intrigue", [])
		var intrigue_cards: Array = intrigue_raw if typeof(intrigue_raw) == TYPE_ARRAY else []
		for _i in range(max(amount, 0)):
			if intrigue_cards.is_empty():
				break
			var trashed_id := str(intrigue_cards.pop_front())
			if trashed_id != "":
				var d_raw: Variant = game_state.get("intrigueDiscard", [])
				var d: Array = d_raw if typeof(d_raw) == TYPE_ARRAY else []
				d.append(trashed_id)
				game_state["intrigueDiscard"] = d
		player_state["intrigue"] = intrigue_cards
		player_state["intrigueCount"] = intrigue_cards.size()
		return

	if effect_type == "lose_influence":
		var lose_faction := str(effect.get("faction", ""))
		if lose_faction == "anyone":
			var influence_raw = player_state.get("influence", {})
			var influence_map: Dictionary = influence_raw if typeof(influence_raw) == TYPE_DICTIONARY else {}
			var best_faction := ""
			var best_value := -1
			for candidate in ["emperor", "guild", "beneGesserit", "fremen"]:
				var v := int(influence_map.get(candidate, 0))
				if v > best_value:
					best_value = v
					best_faction = candidate
			if best_faction != "":
				_change_influence(game_state, player_state, best_faction, -max(amount, 0))
		else:
			_change_influence(game_state, player_state, lose_faction, -max(amount, 0))
		return

	if effect_type == "trash_this_card":
		var this_card_id := str(context.get("card_id", ""))
		if this_card_id == "":
			return
		for zone_name in ["hand", "inPlay", "discard"]:
			var zone_raw = player_state.get(zone_name, [])
			var zone_cards: Array = zone_raw if typeof(zone_raw) == TYPE_ARRAY else []
			var idx := zone_cards.find(this_card_id)
			if idx >= 0:
				zone_cards.remove_at(idx)
				player_state[zone_name] = zone_cards
				if this_card_id == "imperium_sardaukar_soldier":
					player_state["pendingDrawIntrigue"] = int(player_state.get("pendingDrawIntrigue", 0)) + 1
				break
		return

func _change_resource(player_state, resource, delta):
	var resources = player_state.get("resources", {})
	var current = int(resources.get(resource, 0))
	resources[resource] = max(current + delta, 0)
	player_state["resources"] = resources

func _count_revealed_cards_with_tag(
	context: Dictionary,
	game_state: Dictionary,
	player_state: Dictionary,
	tag: String,
	include_this_card: bool
) -> int:
	var cards_by_id_raw = game_state.get("cardsById", {})
	var cards_by_id: Dictionary = cards_by_id_raw if typeof(cards_by_id_raw) == TYPE_DICTIONARY else {}
	var count := 0
	var reveal_ids_raw: Variant = context.get("revealed_card_ids", [])
	if typeof(reveal_ids_raw) == TYPE_ARRAY:
		var reveal_ids: Array = reveal_ids_raw
		var current_card_id := str(context.get("card_id", ""))
		for cid_variant in reveal_ids:
			var cid := str(cid_variant)
			if cid == "":
				continue
			if not include_this_card and cid == current_card_id:
				continue
			var cdef_raw: Variant = cards_by_id.get(cid, {})
			if typeof(cdef_raw) != TYPE_DICTIONARY:
				continue
			var tags_raw = (cdef_raw as Dictionary).get("tags", [])
			if typeof(tags_raw) == TYPE_ARRAY and (tags_raw as Array).has(tag):
				count += 1
		return count
	var in_play_raw = player_state.get("inPlay", [])
	var in_play_cards: Array = in_play_raw if typeof(in_play_raw) == TYPE_ARRAY else []
	for cid_variant in in_play_cards:
		var cid := str(cid_variant)
		var cdef: Variant = cards_by_id.get(cid, {})
		if typeof(cdef) != TYPE_DICTIONARY:
			continue
		var tags_raw = (cdef as Dictionary).get("tags", [])
		if typeof(tags_raw) == TYPE_ARRAY and (tags_raw as Array).has(tag):
			count += 1
	if include_this_card:
		count += 1
	return count

func _apply_on_discard_effects_for_card(card_id: String, player_state: Dictionary, game_state: Dictionary, context: Dictionary) -> void:
	if card_id == "":
		return
	var cards_by_id_raw: Variant = game_state.get("cardsById", {})
	if typeof(cards_by_id_raw) != TYPE_DICTIONARY:
		return
	var cards_by_id: Dictionary = cards_by_id_raw
	var card_def_raw: Variant = cards_by_id.get(card_id, {})
	if typeof(card_def_raw) != TYPE_DICTIONARY:
		return
	var on_discard_effects_raw: Variant = (card_def_raw as Dictionary).get("onDiscardEffects", [])
	if typeof(on_discard_effects_raw) != TYPE_ARRAY:
		return
	var on_discard_effects: Array = on_discard_effects_raw
	if on_discard_effects.is_empty():
		return
	resolve_space_effects(on_discard_effects, player_state, game_state, context)

func _change_influence(game_state: Dictionary, player_state: Dictionary, faction: String, delta: int) -> void:
	if typeof(player_state) != TYPE_DICTIONARY:
		return
	faction_progression_service.apply_influence_delta(game_state, player_state, faction, delta)

func _apply_cost_items(cost_items, player_state):
	if typeof(cost_items) != TYPE_ARRAY:
		return

	for cost_item in cost_items:
		if typeof(cost_item) != TYPE_DICTIONARY:
			continue
		if str(cost_item.get("type", "")) != "resource":
			continue
		var resource = str(cost_item.get("resource", ""))
		var amount = int(cost_item.get("amount", 0))
		_change_resource(player_state, resource, -amount)

func _append_game_log(game_state, event_entry):
	var log_entries = game_state.get("log", [])
	if typeof(log_entries) != TYPE_ARRAY:
		log_entries = []
	log_entries.append(event_entry)
	game_state["log"] = log_entries

func commit_conflict_deploy_choice(player_state, game_state, amount: int, max_from_effect: int, max_from_garrison: int) -> void:
	if amount <= 0:
		return
	var deploy_from_effect: int = amount if amount < max_from_effect else max_from_effect
	var remaining: int = amount - deploy_from_effect
	var deploy_from_garrison: int = remaining if remaining < max_from_garrison else max_from_garrison
	_commit_garrison_troops_to_conflict(player_state, game_state, deploy_from_effect + deploy_from_garrison)

func _prepare_conflict_deploy_choice(player_state, pending_conflict: Dictionary) -> void:
	var from_effect: int = int(pending_conflict.get("from_effect", 0))
	var from_garrison: int = int(pending_conflict.get("from_garrison_max", 0))
	var max_to_commit: int = from_effect + from_garrison
	player_state["pendingConflictDeployMax"] = max_to_commit
	player_state["pendingConflictDeployFromEffect"] = from_effect
	player_state["pendingConflictDeployFromGarrison"] = from_garrison

func _commit_garrison_troops_to_conflict(player_state, game_state, max_amount: int) -> void:
	if max_amount <= 0:
		return
	var player_id := str(player_state.get("id", ""))
	if player_id == "":
		return

	var garrison: int = int(player_state.get("garrisonTroops", 0))
	var moved: int = garrison if garrison < max_amount else max_amount
	if moved <= 0:
		return

	player_state["garrisonTroops"] = garrison - moved
	_gain_troops_to_conflict(player_state, game_state, moved)
	_append_game_log(game_state, {
		"type": "troops_committed_from_garrison",
		"playerId": player_id,
		"amount": moved,
		"garrisonAfter": int(player_state.get("garrisonTroops", 0)),
		"troopsInConflictAfter": int(player_state.get("troopsInConflict", 0))
	})

func _gain_troops_to_conflict(player_state, game_state, amount: int) -> void:
	if amount <= 0:
		return
	var player_id := str(player_state.get("id", ""))
	if player_id == "":
		return

	player_state["troopsInConflict"] = int(player_state.get("troopsInConflict", 0)) + amount

	var conflict_zone = game_state.get("conflictZone", {})
	if typeof(conflict_zone) != TYPE_DICTIONARY:
		conflict_zone = {}
	if not conflict_zone.has(player_id) or typeof(conflict_zone[player_id]) != TYPE_DICTIONARY:
		conflict_zone[player_id] = {
			"troops": 0,
			"sandworms": 0,
			"revealedSwordPower": 0,
			"totalPower": 0
		}

	var zone_entry: Dictionary = conflict_zone[player_id]
	zone_entry["troops"] = int(zone_entry.get("troops", 0)) + amount
	zone_entry["revealedSwordPower"] = int(player_state.get("revealedSwordPower", 0))
	zone_entry["totalPower"] = int(zone_entry.get("troops", 0)) * 2 + int(zone_entry.get("sandworms", 0)) * 3 + int(zone_entry.get("revealedSwordPower", 0))
	conflict_zone[player_id] = zone_entry
	game_state["conflictZone"] = conflict_zone

	_append_game_log(game_state, {
		"type": "troops_added_to_conflict",
		"playerId": player_id,
		"amount": amount,
		"garrisonAfter": int(player_state.get("garrisonTroops", 0)),
		"troopsInConflictAfter": int(player_state.get("troopsInConflict", 0))
	})

func _add_sandworms_to_conflict(player_state: Dictionary, game_state: Dictionary, amount: int) -> void:
	if amount <= 0:
		return
	var player_id := str(player_state.get("id", ""))
	if player_id == "":
		return

	player_state["sandwormsInConflict"] = int(player_state.get("sandwormsInConflict", 0)) + amount

	var conflict_zone = game_state.get("conflictZone", {})
	if typeof(conflict_zone) != TYPE_DICTIONARY:
		conflict_zone = {}
	if not conflict_zone.has(player_id) or typeof(conflict_zone[player_id]) != TYPE_DICTIONARY:
		conflict_zone[player_id] = {
			"troops": 0,
			"sandworms": 0,
			"revealedSwordPower": 0,
			"totalPower": 0
		}
	var zone_entry: Dictionary = conflict_zone[player_id]
	zone_entry["sandworms"] = int(zone_entry.get("sandworms", 0)) + amount
	zone_entry["revealedSwordPower"] = int(player_state.get("revealedSwordPower", 0))
	zone_entry["totalPower"] = int(zone_entry.get("troops", 0)) * 2 + int(zone_entry.get("sandworms", 0)) * 3 + int(zone_entry.get("revealedSwordPower", 0))
	conflict_zone[player_id] = zone_entry
	game_state["conflictZone"] = conflict_zone

func _is_sandworm_blocked_by_shield_wall(game_state: Dictionary) -> bool:
	if not bool(game_state.get("shieldWallIntact", true)):
		return false
	var conflict_def := _get_active_conflict_def(game_state)
	if conflict_def.is_empty():
		return false
	var policy := str(conflict_def.get("sandwormPolicy", "always_allowed"))
	if policy == "blocked_by_shield_wall" or policy == "blocked_until_wall_broken":
		return true
	return bool(conflict_def.get("shieldWallProtected", false))

func _get_active_conflict_def(game_state: Dictionary) -> Dictionary:
	var active_conflict = game_state.get("activeConflictCardDef", null)
	if typeof(active_conflict) == TYPE_DICTIONARY:
		return active_conflict
	var defs = game_state.get("conflictCardsById", {})
	var card_id := str(game_state.get("activeConflictCardId", ""))
	if typeof(defs) == TYPE_DICTIONARY and card_id != "" and defs.has(card_id) and typeof(defs[card_id]) == TYPE_DICTIONARY:
		return defs[card_id]
	return {}

func _recall_agents_from_board(player_state, game_state, amount: int, exclude_just_placed: bool, just_placed_space_id: String) -> void:
	if amount <= 0:
		return

	var agents_on_board = player_state.get("agentsOnBoard", [])
	if typeof(agents_on_board) != TYPE_ARRAY:
		agents_on_board = []

	var board_occupancy = game_state.get("boardOccupancy", {})
	if typeof(board_occupancy) != TYPE_DICTIONARY:
		board_occupancy = {}

	var recalled := 0
	var player_id := str(player_state.get("id", ""))
	for i in range(agents_on_board.size() - 1, -1, -1):
		if recalled >= amount:
			break
		var space_id := str(agents_on_board[i])
		if exclude_just_placed and just_placed_space_id != "" and space_id == just_placed_space_id:
			continue
		var removed := _remove_player_occupant_from_space(board_occupancy, space_id, player_id, game_state)
		if not removed:
			continue
		agents_on_board.remove_at(i)
		recalled += 1

	if recalled <= 0:
		return

	player_state["agentsOnBoard"] = agents_on_board
	var max_agents := int(player_state.get("agentsTotal", 2))
	player_state["agentsAvailable"] = min(int(player_state.get("agentsAvailable", 0)) + recalled, max_agents)
	game_state["boardOccupancy"] = board_occupancy
	_sync_markers(board_occupancy, game_state)

func _remove_player_occupant_from_space(board_occupancy: Dictionary, space_id: String, player_id: String, game_state: Variant) -> bool:
	if not board_occupancy.has(space_id):
		return false
	var entry: Variant = board_occupancy[space_id]
	if typeof(entry) == TYPE_ARRAY:
		var occupants: Array = entry
		for idx in range(occupants.size() - 1, -1, -1):
			var occupant_id := str(occupants[idx])
			if _extract_player_id_from_occupant(occupant_id, game_state) == player_id:
				occupants.remove_at(idx)
				if occupants.is_empty():
					board_occupancy.erase(space_id)
				else:
					board_occupancy[space_id] = occupants
				return true
		return false
	var single_id := str(entry)
	if _extract_player_id_from_occupant(single_id, game_state) != player_id:
		return false
	board_occupancy.erase(space_id)
	return true

func _update_conflict_zone_labels(game_state: Dictionary) -> void:
	if conflict_title_label == null and conflict_index_label == null and conflict_p1_label == null and conflict_p2_label == null and conflict_p3_label == null and conflict_p4_label == null:
		return

	var conflict_card_id := str(game_state.get("activeConflictCardId", ""))
	var conflict_card_def: Dictionary = {}
	var active_conflict_raw = game_state.get("activeConflictCardDef", null)
	if typeof(active_conflict_raw) == TYPE_DICTIONARY:
		conflict_card_def = active_conflict_raw
	elif conflict_card_id != "":
		var defs = game_state.get("conflictCardsById", {})
		if typeof(defs) == TYPE_DICTIONARY and defs.has(conflict_card_id) and typeof(defs[conflict_card_id]) == TYPE_DICTIONARY:
			conflict_card_def = defs[conflict_card_id]

	if conflict_title_label != null:
		if conflict_card_id == "":
			conflict_title_label.text = "Conflict zone"
		else:
			var display_name := str(conflict_card_def.get("name", conflict_card_id))
			conflict_title_label.text = display_name
	if conflict_index_label != null:
		conflict_index_label.text = _build_conflict_index_text(game_state, conflict_card_id)

	_apply_conflict_zone_theme_for_sandworm_policy(conflict_card_def)
	_update_conflict_reward_slots(conflict_card_def)
	_update_conflict_battle_icon(conflict_card_def)

	var players = game_state.get("players", [])
	if typeof(players) != TYPE_ARRAY:
		players = []

	var labels: Array[Label] = [
		conflict_p1_label,
		conflict_p2_label,
		conflict_p3_label,
		conflict_p4_label
	]
	for i in range(labels.size()):
		var value_label := labels[i]
		if value_label == null:
			continue
		var garrison := 0
		if i < players.size():
			var p = players[i]
			if typeof(p) == TYPE_DICTIONARY:
				garrison = int(p.get("garrisonTroops", 0))
		value_label.text = str(garrison)
	_update_garrison_badge_colors(players)
	_update_garrison_maker_hooks_icons(players)
	_update_conflict_zone_troop_icons(players)

const GARRISON_MAKER_HOOKS_ICON_PATH := "res://data/icons/maker_hooks.png"

func _update_garrison_maker_hooks_icons(players: Variant) -> void:
	var rows: Array[Node] = [
		garrison_p1_icon.get_parent().get_parent() if garrison_p1_icon != null else null,
		garrison_p2_icon.get_parent().get_parent() if garrison_p2_icon != null else null,
		garrison_p3_icon.get_parent().get_parent() if garrison_p3_icon != null else null,
		garrison_p4_icon.get_parent().get_parent() if garrison_p4_icon != null else null
	]
	for i in range(rows.size()):
		var row: Node = rows[i]
		if row == null:
			continue
		var hooks_icon := row.get_node_or_null("GarrisonMakerHooksIcon") as TextureRect
		if hooks_icon == null:
			hooks_icon = TextureRect.new()
			hooks_icon.name = "GarrisonMakerHooksIcon"
			hooks_icon.custom_minimum_size = Vector2(30, 30)
			hooks_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			hooks_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var tex := load(GARRISON_MAKER_HOOKS_ICON_PATH) as Texture2D
			if tex != null:
				hooks_icon.texture = tex
			row.add_child(hooks_icon)
		var has_hooks := false
		if typeof(players) == TYPE_ARRAY and i < players.size() and typeof(players[i]) == TYPE_DICTIONARY:
			has_hooks = bool(players[i].get("hasMakerHooks", false))
		hooks_icon.visible = has_hooks

func _build_conflict_index_text(game_state: Dictionary, conflict_card_id: String) -> String:
	var total_conflicts := int(game_state.get("conflictDeckTotal", 0))
	if total_conflicts <= 0:
		return "-"
	var remaining_deck = game_state.get("conflictDeck", [])
	var remaining_count := 0
	if typeof(remaining_deck) == TYPE_ARRAY:
		remaining_count = remaining_deck.size()
	if conflict_card_id == "":
		var next_index := total_conflicts - remaining_count + 1
		if next_index < 1:
			next_index = 1
		if next_index > total_conflicts:
			next_index = total_conflicts
		return "%d of %d" % [next_index, total_conflicts]
	var current_index := total_conflicts - remaining_count
	if current_index < 1:
		current_index = 1
	if current_index > total_conflicts:
		current_index = total_conflicts
	return "%d of %d" % [current_index, total_conflicts]

func _update_garrison_badge_colors(players: Variant) -> void:
	var icon_nodes: Array[TextureRect] = [
		garrison_p1_icon,
		garrison_p2_icon,
		garrison_p3_icon,
		garrison_p4_icon
	]
	for i in range(icon_nodes.size()):
		var icon := icon_nodes[i]
		if icon == null:
			continue
		var has_player: bool = typeof(players) == TYPE_ARRAY and i < players.size() and typeof(players[i]) == TYPE_DICTIONARY
		icon.modulate = PLAYER_TOKEN_COLORS[i % PLAYER_TOKEN_COLORS.size()] if has_player else Color(1, 1, 1, 1)

func _update_conflict_zone_troop_icons(players: Variant) -> void:
	var icon_rows: Array[HBoxContainer] = [
		conflict_troops_icons_p1,
		conflict_troops_icons_p2,
		conflict_troops_icons_p3,
		conflict_troops_icons_p4
	]
	var troops_texture: Texture2D = load(CONFLICT_TROOPS_ICON_PATH) as Texture2D
	var sandworm_texture: Texture2D = load(CONFLICT_SANDWORM_ICON_PATH) as Texture2D
	const BADGE_SIZE := Vector2(48, 48)

	for i in range(icon_rows.size()):
		var row := icon_rows[i]
		if row == null:
			continue
		for child in row.get_children():
			child.queue_free()

		var committed_troops := 0
		var committed_sandworms := 0
		if typeof(players) == TYPE_ARRAY and i < players.size() and typeof(players[i]) == TYPE_DICTIONARY:
			committed_troops = int(players[i].get("troopsInConflict", 0))
			committed_sandworms = int(players[i].get("sandwormsInConflict", 0))

		if committed_troops <= 0 and committed_sandworms <= 0:
			row.visible = false
			continue

		var tint := PLAYER_TOKEN_COLORS[i % PLAYER_TOKEN_COLORS.size()]
		if committed_troops > 0 and troops_texture != null:
			row.add_child(_build_conflict_unit_badge(troops_texture, committed_troops, tint, BADGE_SIZE))
		if committed_sandworms > 0 and sandworm_texture != null:
			row.add_child(_build_conflict_unit_badge(sandworm_texture, committed_sandworms, tint, BADGE_SIZE))
		row.visible = true

func _build_conflict_unit_badge(texture: Texture2D, amount: int, tint: Color, badge_size: Vector2) -> Control:
	var badge := Control.new()
	badge.custom_minimum_size = badge_size

	var tex := TextureRect.new()
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.texture = texture
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.modulate = tint
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(tex)

	var val := Label.new()
	val.set_anchors_preset(Control.PRESET_FULL_RECT)
	val.text = str(amount)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val.add_theme_font_size_override("font_size", 16)
	val.add_theme_color_override("font_color", Color(0.12, 0.12, 0.12, 1))
	val.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(val)
	return badge

func _update_conflict_reward_slots(conflict_card_def: Dictionary) -> void:
	var reward_slots: Array[ConflictRewardSlot] = [first_reward_slot, second_reward_slot, third_reward_slot]
	var rank_names: Array[String] = ["1st", "2nd", "3rd"]
	var rewards_by_place: Array = [
		conflict_card_def.get("firstReward", []),
		conflict_card_def.get("secondReward", []),
		conflict_card_def.get("thirdReward", [])
	]

	for i in range(reward_slots.size()):
		var slot := reward_slots[i]
		if slot == null:
			continue
		slot.set_rank_text(rank_names[i])
		var reward_text := _reward_list_to_tokens(
			rewards_by_place[i] if i < rewards_by_place.size() else [],
			i == 0
		)
		slot.set_reward_tokens(reward_text)

func _reward_list_to_tokens(reward_list: Variant, split_cost_to_second_line: bool = false) -> String:
	if typeof(reward_list) != TYPE_ARRAY or reward_list.is_empty():
		return "-"

	var first_line_tokens: Array[String] = []
	var second_line_tokens: Array[String] = []
	for reward in reward_list:
		var token := _reward_to_token(reward)
		if token == "":
			continue
		var reward_type := ""
		if typeof(reward) == TYPE_DICTIONARY:
			reward_type = str(reward.get("type", ""))
			if reward_type == "control":
				reward_type = "gain_control"
		if split_cost_to_second_line and reward_type == "cost":
			second_line_tokens.append(token)
		else:
			first_line_tokens.append(token)
	if first_line_tokens.is_empty() and second_line_tokens.is_empty():
		return "-"
	if second_line_tokens.is_empty():
		return "; ".join(first_line_tokens)
	if first_line_tokens.is_empty():
		return "\n" + "; ".join(second_line_tokens)
	return "; ".join(first_line_tokens) + "\n" + "; ".join(second_line_tokens)

func _update_conflict_battle_icon(conflict_card_def: Dictionary) -> void:
	if conflict_battle_icon == null:
		return
	var battle_icons_raw: Variant = conflict_card_def.get("battleIcons", [])
	if typeof(battle_icons_raw) != TYPE_ARRAY or (battle_icons_raw as Array).is_empty():
		_hide_conflict_battle_icon()
		return
	var icon_id := str((battle_icons_raw as Array)[0]).strip_edges()
	if icon_id == "":
		_hide_conflict_battle_icon()
		return
	var icon_path := str(BATTLE_ICON_TEXTURE_PATHS.get(icon_id, "")).strip_edges()
	if icon_path == "":
		_hide_conflict_battle_icon()
		return
	var tex := _load_cached_battle_icon(icon_path)
	if tex == null:
		_hide_conflict_battle_icon()
		return
	conflict_battle_icon.texture = tex
	conflict_battle_icon.visible = true

func _hide_conflict_battle_icon() -> void:
	if conflict_battle_icon == null:
		return
	conflict_battle_icon.visible = false
	conflict_battle_icon.texture = null

func _load_cached_battle_icon(path: String) -> Texture2D:
	if path == "":
		return null
	if _battle_icon_texture_cache.has(path):
		return _battle_icon_texture_cache[path] as Texture2D
	var tex := load(path) as Texture2D
	if tex != null:
		_battle_icon_texture_cache[path] = tex
	return tex

func _reward_to_token(reward: Variant) -> String:
	if typeof(reward) != TYPE_DICTIONARY:
		return ""
	var reward_type := str(reward.get("type", ""))
	if reward_type == "control":
		reward_type = "gain_control"
	var amount := int(reward.get("amount", 0))
	match reward_type:
		"gain_resource", "resource":
			var resource_id := str(reward.get("resource", ""))
			if resource_id == "solari":
				return "[solari_badge:%d]" % amount
			if resource_id == "spice":
				return "[spice_badge:%d]" % amount
			if resource_id == "water":
				return "[water_badge:%d]" % amount
			return "%d %s" % [amount, resource_id]
		"recruit_troops":
			return "[troops_badge:%d]" % amount
		"vp":
			return _repeat_token("[vp_icon]", max(amount, 1))
		"gain_influence":
			var faction := str(reward.get("faction", ""))
			if faction == "spacing_guild":
				faction = "guild"
			elif faction == "bene_gesserit":
				faction = "beneGesserit"
			elif faction == "anyone":
				faction = "anyone"
			elif faction == "choose_two":
				var raw_options = reward.get("factions", [])
				var choices: Array[String] = []
				if typeof(raw_options) == TYPE_ARRAY:
					for raw in raw_options:
						var option := str(raw)
						if option == "spacing_guild":
							option = "guild"
						elif option == "bene_gesserit":
							option = "beneGesserit"
						if option == "" or choices.has(option):
							continue
						choices.append(option)
				if choices.is_empty():
					return "Choose two:"
				return "Choose two:\n[influence_choice_set:%s]" % ",".join(choices)
			if faction == "":
				return "+%d influence" % amount
			if faction == "anyone":
				if amount <= 1:
					return "[influence_icon]"
				return "[influence_icon] +%d" % amount
			if amount == 1:
				return "[faction_icon:%s]" % faction
			return "[faction_icon:%s] +%d" % [faction, amount]
		"draw_intrigue", "intrigue":
			return _repeat_token("[intrigue_icon]", max(amount, 1))
		"get_contract", "contract":
			return _repeat_token("[contract_icon]", max(amount, 1))
		"place_spy":
			return _repeat_token("[spy_icon]", max(amount, 1))
		"trash_card":
			return _repeat_token("[trash_card_icon]", max(amount, 1))
		"cost":
			var resource := str(reward.get("resource", ""))
			var cost_amount := int(reward.get("amount", 0))
			var nested: Variant = reward.get("effect", {})
			if typeof(nested) == TYPE_DICTIONARY:
				var nested_type := str(nested.get("type", ""))
				if nested_type == "vp":
					return "[cost_trade:%s:%d:vp:%d]" % [resource, cost_amount, int(nested.get("amount", 0))]
				if nested_type == "resource":
					return "[cost_trade:%s:%d:%s:%d]" % [
						resource,
						cost_amount,
						str(nested.get("resource", "")),
						int(nested.get("amount", 0))
					]
			return "pay %d %s" % [cost_amount, resource]
		"gain_control":
			var board_space_id := str(reward.get("boardSpaceId", ""))
			if board_space_id == "":
				return "[control_icon]"
			return "[control_icon:%s]" % board_space_id
		_:
			return reward_type

func _get_player_by_id(game_state: Dictionary, player_id: String) -> Dictionary:
	var players = game_state.get("players", [])
	if typeof(players) != TYPE_ARRAY:
		return {}
	for p in players:
		if typeof(p) == TYPE_DICTIONARY and str(p.get("id", "")) == player_id:
			return p
	return {}

func _get_player_index_by_id(game_state: Variant, player_id: String) -> int:
	if player_id == "" or typeof(game_state) != TYPE_DICTIONARY:
		return -1
	var players = game_state.get("players", [])
	if typeof(players) != TYPE_ARRAY:
		return -1
	for i in range(players.size()):
		var p = players[i]
		if typeof(p) == TYPE_DICTIONARY and str(p.get("id", "")) == player_id:
			return i
	return -1

func _extract_player_id_from_occupant(occupant_id: String, game_state: Variant) -> String:
	if occupant_id == "":
		return ""
	if occupant_id.find("_agent_") > 0:
		return occupant_id.split("_agent_", false, 1)[0]
	if typeof(game_state) != TYPE_DICTIONARY:
		return ""
	var players = game_state.get("players", [])
	if typeof(players) != TYPE_ARRAY:
		return ""
	for p in players:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var pid := str(p.get("id", ""))
		if pid == occupant_id:
			return pid
	return ""


func _get_high_council_else_effects_text(space_def: Dictionary, area_id: String) -> String:
	var effects = space_def.get("effects", [])
	if typeof(effects) != TYPE_ARRAY:
		return ""
	for e in effects:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		if str(e.get("type", "")) == "if":
			var else_effects = e.get("else", [])
			if typeof(else_effects) == TYPE_ARRAY:
				return _effects_to_text(else_effects, area_id)
	return ""


func _build_high_council_marker_text(space_def: Dictionary, game_state: Variant) -> String:
	var area_id := str(space_def.get("area", ""))
	var else_text := _get_high_council_else_effects_text(space_def, area_id)
	var first_visit_block := "[high_council_1st]"
	if else_text != "":
		first_visit_block = "[high_council_1st]\n[hc_repeat_dim]" + else_text

	if game_state == null or typeof(game_state) != TYPE_DICTIONARY:
		return first_visit_block
	var pid := str(game_state.get("currentPlayerId", ""))
	if pid == "":
		return first_visit_block
	var player := _get_player_by_id(game_state, pid)
	if player.is_empty():
		return first_visit_block
	var flags = player.get("flags", {})
	if typeof(flags) != TYPE_DICTIONARY:
		flags = {}
	if not bool(flags.get("has_high_council_seat", false)):
		return first_visit_block
	if else_text != "":
		return "[hc_repeat_bright]" + else_text
	return ""


func _build_space_effects_text(space_def: Dictionary, game_state: Variant = null) -> String:
	if typeof(space_def) != TYPE_DICTIONARY or space_def.is_empty():
		return ""

	if str(space_def.get("id", "")) == "high_council":
		return _build_high_council_marker_text(space_def, game_state)

	var lines: Array[String] = []
	var effects = space_def.get("effects", [])
	var area_id := str(space_def.get("area", ""))

	var effects_text := _effects_to_text(effects, area_id)
	if bool(space_def.get("makerSpace", false)):
		var base_spice := int(space_def.get("makerBaseSpice", 0))
		if base_spice > 0:
			effects_text = _strip_one_spice_badge_token(effects_text, base_spice)
	effects_text = effects_text.strip_edges()
	effects_text = effects_text.replace("; ;", ";")
	effects_text = effects_text.replace(";;", ";")
	if effects_text.begins_with(";"):
		effects_text = effects_text.substr(1).strip_edges()
	if effects_text.ends_with(";"):
		effects_text = effects_text.left(effects_text.length() - 1).strip_edges()
	if effects_text != "":
		lines.append(effects_text)
	return "\n".join(lines)

func _strip_one_spice_badge_token(text: String, amount: int) -> String:
	var token := "[spice_badge:%d]" % amount
	var pos := text.find(token)
	if pos < 0:
		return text
	return text.substr(0, pos) + text.substr(pos + token.length())

func _effects_to_text(effects: Variant, space_area_id: String = "") -> String:
	return EffectTextTokensScript.effects_to_text_board(effects, space_area_id)

func _normalize_effects_with_aliases(effects: Variant) -> Array:
	return effect_pipeline.normalize(effects)


func _contains_effect_type(effects: Variant, target_type: String) -> bool:
	if typeof(effects) != TYPE_ARRAY:
		return false
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		var effect_type := str(effect.get("type", ""))
		if effect_type == target_type:
			return true
		if effect_type == "choice":
			var options: Variant = effect.get("options", [])
			if typeof(options) == TYPE_ARRAY:
				for option in options:
					if typeof(option) != TYPE_DICTIONARY:
						continue
					if _contains_effect_type(option.get("effects", []), target_type):
						return true
		if effect_type == "if":
			if _contains_effect_type(effect.get("then", []), target_type):
				return true
			if _contains_effect_type(effect.get("else", []), target_type):
				return true
	return false

func _effect_to_text(effect: Variant, space_area_id: String = "") -> String:
	return EffectTextTokensScript.effect_to_text_board(effect, space_area_id)

func _repeat_token(token: String, amount: int) -> String:
	return EffectTextTokensScript.repeat_token(token, amount)

func _choice_to_text(effect: Dictionary, space_area_id: String = "") -> String:
	return EffectTextTokensScript.choice_to_text_board(effect, space_area_id)

func _if_to_text(effect: Dictionary, space_area_id: String = "") -> String:
	return EffectTextTokensScript.if_to_text_board(effect, space_area_id)

func _is_faction_area(area_id: String) -> bool:
	return EffectTextTokensScript.is_faction_area(area_id)

func _requirement_to_text(requirement: Variant) -> String:
	return EffectTextTokensScript.requirement_to_text_board(requirement)

func _is_influence_choice(effect: Dictionary) -> bool:
	return EffectTextTokensScript.is_influence_choice(effect)

func _is_spice_refinery_trade_choice(effect: Dictionary) -> bool:
	return EffectTextTokensScript.is_spice_refinery_trade_choice(effect)

func _is_gather_support_trade_choice(effect: Dictionary) -> bool:
	return EffectTextTokensScript.is_gather_support_trade_choice(effect)

func _extract_maker_worm_choice(effect: Dictionary) -> Dictionary:
	return EffectTextTokensScript.extract_maker_worm_choice(effect)

func _extract_sietch_tabr_choice(effect: Dictionary) -> Dictionary:
	return EffectTextTokensScript.extract_sietch_tabr_choice(effect)
