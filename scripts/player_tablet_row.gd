extends PanelContainer
class_name PlayerTabletRow
static var _portrait_cache: Dictionary = {}
const ROW_BG_DEFAULT := Color(0, 0, 0, 0.36)
const ROW_BG_ACTIVE := Color(0.17, 0.22, 0.32, 0.72)
const ROW_BORDER_ACTIVE := Color(0.8, 0.9, 1.0, 0.95)
const ROW_TEXT_DEFAULT := Color(1, 1, 1, 1)
const ROW_TEXT_ACTIVE := Color(0.95, 0.98, 1.0, 1.0)

@onready var portrait_rect: TextureRect = %PortraitRect
@onready var name_label: Label = %LeaderNameLabel
@onready var first_player_badge: TextureRect = %FirstPlayerBadge
@onready var high_council_badge: TextureRect = %HighCouncilBadge
@onready var spice_label: Label = %SpiceValueLabel
@onready var solari_label: Label = %SolariValueLabel
@onready var water_label: Label = %WaterValueLabel
@onready var persuasion_label: Label = %PersuasionValueLabel
@onready var intrigue_label: Label = %IntrigueValueLabel
@onready var agents_label: Label = %AgentsValueLabel
@onready var hand_label: Label = %HandValueLabel
@onready var contracts_label: Label = %ContractsValueLabel
@onready var alliance_box: HBoxContainer = %AllianceBox
@onready var emperor_alliance_icon: TextureRect = %EmperorAllianceIcon
@onready var guild_alliance_icon: TextureRect = %GuildAllianceIcon
@onready var bene_gesserit_alliance_icon: TextureRect = %BeneGesseritAllianceIcon
@onready var fremen_alliance_icon: TextureRect = %FremenAllianceIcon
var _default_panel_style: StyleBoxFlat
var _active_panel_style: StyleBoxFlat

func _ready() -> void:
	_init_row_styles()

func bind_player(player_state: Dictionary, is_current_turn: bool = false, is_first_player: bool = false) -> void:
	var resources: Variant = player_state.get("resources", {})
	if typeof(resources) != TYPE_DICTIONARY:
		resources = {}

	var leader_name := str(player_state.get("leaderName", ""))
	if leader_name == "":
		leader_name = str(player_state.get("name", player_state.get("id", "Player")))
	name_label.text = leader_name

	spice_label.text = str(int(resources.get("spice", 0)))
	solari_label.text = str(int(resources.get("solari", 0)))
	water_label.text = str(int(resources.get("water", 0)))
	persuasion_label.text = str(int(player_state.get("persuasion", 0)))

	var intrigue_count := int(player_state.get("intrigueCount", 0))
	var intrigue_cards: Variant = player_state.get("intrigue", [])
	if typeof(intrigue_cards) == TYPE_ARRAY:
		intrigue_count = intrigue_cards.size()
	intrigue_label.text = str(intrigue_count)

	agents_label.text = "%d/%d" % [int(player_state.get("agentsAvailable", 0)), int(player_state.get("agentsTotal", 2))]

	var hand_count := 0
	var hand_cards: Variant = player_state.get("hand", [])
	if typeof(hand_cards) == TYPE_ARRAY:
		hand_count = hand_cards.size()
	else:
		hand_count = int(player_state.get("handCount", 0))
	hand_label.text = str(hand_count)
	var completed_contracts := int(player_state.get("completedContracts", 0))
	var active_contracts := 0
	var owned_contracts: Variant = player_state.get("contractsOwned", [])
	if typeof(owned_contracts) == TYPE_ARRAY:
		active_contracts = (owned_contracts as Array).size()
	contracts_label.text = "%d/%d" % [completed_contracts, active_contracts]

	var portrait_path := str(player_state.get("leaderPortrait", ""))
	if portrait_path == "":
		portrait_rect.texture = null
	else:
		var portrait := _load_cached_texture(portrait_path)
		if portrait is Texture2D:
			portrait_rect.texture = portrait
		else:
			portrait_rect.texture = null

	_bind_alliance_icons(player_state)
	_apply_turn_highlight(is_current_turn)
	if first_player_badge != null:
		first_player_badge.visible = is_first_player
	if high_council_badge != null:
		var flags: Dictionary = player_state.get("flags", {}) if typeof(player_state.get("flags", {})) == TYPE_DICTIONARY else {}
		var has_high_council_seat := bool(flags.get("has_high_council_seat", false))
		# Fallback for older state shape where the flag may be at top-level.
		if not has_high_council_seat:
			has_high_council_seat = bool(player_state.get("has_high_council_seat", false))
		high_council_badge.visible = has_high_council_seat

func _init_row_styles() -> void:
	var panel_style: Variant = get_theme_stylebox("panel")
	if panel_style is StyleBoxFlat:
		_default_panel_style = (panel_style as StyleBoxFlat).duplicate() as StyleBoxFlat
	else:
		_default_panel_style = StyleBoxFlat.new()
		_default_panel_style.bg_color = ROW_BG_DEFAULT
		_default_panel_style.corner_radius_top_left = 8
		_default_panel_style.corner_radius_top_right = 8
		_default_panel_style.corner_radius_bottom_left = 8
		_default_panel_style.corner_radius_bottom_right = 8
	_default_panel_style.bg_color = ROW_BG_DEFAULT
	_active_panel_style = _default_panel_style.duplicate() as StyleBoxFlat
	_active_panel_style.bg_color = ROW_BG_ACTIVE
	_active_panel_style.border_color = ROW_BORDER_ACTIVE
	_active_panel_style.set_border_width_all(2)

func _apply_turn_highlight(is_current_turn: bool) -> void:
	if _default_panel_style == null or _active_panel_style == null:
		_init_row_styles()
	if is_current_turn:
		add_theme_stylebox_override("panel", _active_panel_style)
	else:
		add_theme_stylebox_override("panel", _default_panel_style)
	name_label.add_theme_color_override("font_color", ROW_TEXT_ACTIVE if is_current_turn else ROW_TEXT_DEFAULT)

func _bind_alliance_icons(player_state: Dictionary) -> void:
	var alliances: Dictionary = {}
	var raw_alliances: Variant = player_state.get("alliances", {})
	if typeof(raw_alliances) == TYPE_DICTIONARY:
		alliances = raw_alliances

	var emperor_owned := bool(alliances.get("emperor", false))
	var guild_owned := bool(alliances.get("guild", false))
	var bene_owned := bool(alliances.get("beneGesserit", false))
	var fremen_owned := bool(alliances.get("fremen", false))

	if emperor_alliance_icon != null:
		emperor_alliance_icon.visible = emperor_owned
	if guild_alliance_icon != null:
		guild_alliance_icon.visible = guild_owned
	if bene_gesserit_alliance_icon != null:
		bene_gesserit_alliance_icon.visible = bene_owned
	if fremen_alliance_icon != null:
		fremen_alliance_icon.visible = fremen_owned
	if alliance_box != null:
		alliance_box.visible = emperor_owned or guild_owned or bene_owned or fremen_owned

func _load_cached_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if _portrait_cache.has(path):
		return _portrait_cache[path] as Texture2D
	var tex := load(path) as Texture2D
	if tex != null:
		_portrait_cache[path] = tex
	return tex
