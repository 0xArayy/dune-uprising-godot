extends CanvasLayer
class_name GameUi

const PLAYER_TABLET_ROW_SCENE := preload("res://scenes/player_tablet_row.tscn")
const MARKET_CARD_UI_SCENE := preload("res://scenes/card_ui.tscn")
const BoardSpacesRepositoryScript := preload("res://scripts/infrastructure/board_spaces_repository.gd")
const IntrigueEffectTextScript = preload("res://scripts/intrigue_effect_text.gd")
const MARKET_ROW_MAX_CARDS := 5
const MARKET_CARD_WIDTH := 180.0
const MARKET_CARD_HEIGHT := 252.0
const MARKET_ROW_SEPARATION := 8.0

@onready var round_label: Label = %RoundLabel
@onready var player_label: Label = %CurrentPlayerLabel
@onready var choam_face_up_label: Label = %ChoamFaceUpLabel
@onready var choam_details_button: Button = %ChoamDetailsButton
@onready var persuasion_label: Label = %PersuasionLabel
@onready var hand_dock: HandDock = %HandDock
@onready var hand: Hand = %Hand
@onready var cancel_selection_button: Button = %CancelSelectionButton
@onready var reveal_button: Button = %RevealButton
@onready var market_list: VBoxContainer = %MarketList
@onready var reserve_list: VBoxContainer = %ReserveList
@onready var deck_button: Button = %DeckButton
@onready var discard_button: Button = %DiscardButton
@onready var contracts_button: Button = %ContractsButton
@onready var market_button: Button = %MarketButton
@onready var market_panel: PanelContainer = %MarketPanel
@onready var market_close_button: Button = %MarketCloseButton
@onready var deck_view_popup: PanelContainer = %DeckViewPopup
@onready var deck_view_title: Label = %DeckViewTitle
@onready var deck_view_list: VBoxContainer = %DeckViewList
@onready var deck_view_close_button: Button = %DeckViewCloseButton
@onready var pending_trash_popup: PanelContainer = %PendingTrashPopup
@onready var pending_trash_count_label: Label = %PendingTrashCountLabel
@onready var pending_hand_list: ItemList = %PendingHandList
@onready var pending_discard_list: ItemList = %PendingDiscardList
@onready var pending_in_play_list: ItemList = %PendingInPlayList
@onready var pending_trash_confirm_button: Button = %PendingTrashConfirmButton
@onready var pending_conflict_popup: PanelContainer = %PendingConflictPopup
@onready var pending_conflict_label: Label = %PendingConflictLabel
@onready var pending_conflict_spinbox: SpinBox = %PendingConflictSpinBox
@onready var pending_conflict_confirm_button: Button = %PendingConflictConfirmButton
@onready var space_choice_backdrop: ColorRect = %SpaceChoiceBackdrop
@onready var space_choice_popup: PanelContainer = %SpaceChoicePopup
@onready var space_choice_title: Label = %SpaceChoiceTitle
@onready var space_choice_scroll: ScrollContainer = %SpaceChoiceScroll
@onready var space_choice_buttons_vbox: VBoxContainer = %SpaceChoiceButtonsVBox
@onready var space_choice_cancel_button: Button = %SpaceChoiceCancelButton
@onready var choam_popup: PanelContainer = %ChoamPopup
@onready var choam_popup_close_button: Button = %ChoamPopupCloseButton
@onready var choam_popup_list: VBoxContainer = %ChoamPopupList
@onready var top_panel: Control = $TopPanel
@onready var left_players_panel: Control = $LeftPlayersPanel
@onready var players_table_rows: VBoxContainer = %PlayersTableRows
@onready var card_inspector_popup: CardInspectorPopup = %CardInspectorPopup

var _last_bound_state: Dictionary = {}
var _pending_hand_cards: Array = []
var _pending_discard_cards: Array = []
var _pending_in_play_cards: Array = []
var _pending_zone_selected := ""
var _pending_card_selected := ""
var _space_choice_slot: int = -1
var _player_rows_by_id: Dictionary = {}
var _market_dirty := true
var _market_snapshot_key := ""
var _space_choice_option_normal_style: StyleBoxFlat
var _space_choice_option_hover_style: StyleBoxFlat
var _space_choice_option_pressed_style: StyleBoxFlat
var _intrigue_controls_panel: PanelContainer
var _intrigue_bar: HBoxContainer
var _intrigue_view_button: Button
var _combat_intrigue_option: OptionButton
var _plot_intrigue_option: OptionButton
var _endgame_intrigue_option: OptionButton
var _board_spaces_repo: BoardSpacesRepository = BoardSpacesRepositoryScript.new()

func _ready():
	cancel_selection_button.pressed.connect(_on_cancel_selection_pressed)
	reveal_button.pressed.connect(_on_reveal_pressed)
	deck_button.pressed.connect(_on_deck_button_pressed)
	discard_button.pressed.connect(_on_discard_button_pressed)
	contracts_button.pressed.connect(_on_contracts_button_pressed)
	market_button.pressed.connect(_on_market_button_pressed)
	market_close_button.pressed.connect(_on_market_close_button_pressed)
	deck_view_close_button.pressed.connect(_on_deck_view_close_pressed)
	pending_hand_list.item_selected.connect(_on_pending_hand_item_selected)
	pending_discard_list.item_selected.connect(_on_pending_discard_item_selected)
	pending_in_play_list.item_selected.connect(_on_pending_in_play_item_selected)
	pending_trash_confirm_button.pressed.connect(_on_pending_trash_confirm_pressed)
	pending_conflict_confirm_button.pressed.connect(_on_pending_conflict_confirm_pressed)
	space_choice_cancel_button.pressed.connect(_on_space_choice_cancel_pressed)
	choam_details_button.pressed.connect(_on_choam_details_pressed)
	choam_popup_close_button.pressed.connect(_on_choam_popup_close_pressed)
	hand.card_play_requested.connect(_on_hand_card_play_requested)
	hand.card_inspect_requested.connect(_on_card_inspect_requested)
	_setup_space_choice_visuals()
	_setup_intrigue_view_button()
	_setup_intrigue_controls_row()

func bind_state(game_state: Dictionary) -> void:
	_last_bound_state = game_state
	_update_labels(game_state)
	_update_hand(game_state)
	_update_market_if_needed(game_state, false)
	_update_pending_trash_popup(game_state)
	_update_pending_conflict_popup(game_state)
	_update_intrigue_controls_row(game_state)

func set_reveal_enabled(value: bool) -> void:
	reveal_button.disabled = not value

func set_cancel_selection_visible(value: bool) -> void:
	cancel_selection_button.visible = value
	cancel_selection_button.disabled = not value

func set_hand_interactable(value: bool) -> void:
	if hand == null:
		return
	hand.set_cards_interactable(value)

func show_space_choice(title: String, option_effects_texts: Variant, slot: int, option_original_indices: Variant = null) -> void:
	_space_choice_slot = slot
	if space_choice_buttons_vbox != null:
		_clear_children(space_choice_buttons_vbox)
	var plain_texts: Array[String] = []
	var rich_entries_by_index: Array = []
	if typeof(option_effects_texts) == TYPE_PACKED_STRING_ARRAY:
		var psa := option_effects_texts as PackedStringArray
		for i in range(psa.size()):
			plain_texts.append(str(psa[i]))
	elif typeof(option_effects_texts) == TYPE_ARRAY:
		for item in option_effects_texts:
			if typeof(item) == TYPE_DICTIONARY:
				rich_entries_by_index.append(item)
				plain_texts.append(str((item as Dictionary).get("name", "")))
			else:
				rich_entries_by_index.append({})
				plain_texts.append(str(item))
	var option_height := _resolve_space_choice_option_height(plain_texts.size())
	for i in range(plain_texts.size()):
		var emitted_index := i
		if typeof(option_original_indices) == TYPE_ARRAY and i < option_original_indices.size():
			emitted_index = int(option_original_indices[i])
		var rich_entry: Dictionary = {}
		if i < rich_entries_by_index.size() and typeof(rich_entries_by_index[i]) == TYPE_DICTIONARY:
			rich_entry = rich_entries_by_index[i]
		space_choice_buttons_vbox.add_child(_build_space_choice_option_button(plain_texts[i], rich_entry, i + 1, emitted_index, option_height))
	if space_choice_title != null:
		space_choice_title.text = "Choose one option - %s" % title
	_set_space_choice_backdrop_visible(true)
	if space_choice_popup != null:
		space_choice_popup.visible = true

func hide_space_choice() -> void:
	_space_choice_slot = -1
	_set_space_choice_backdrop_visible(false)
	if space_choice_buttons_vbox != null:
		_clear_children(space_choice_buttons_vbox)
	if space_choice_popup != null:
		space_choice_popup.visible = false

func is_space_choice_open() -> bool:
	return space_choice_popup != null and space_choice_popup.visible

func _on_space_choice_option_pressed(option_index: int) -> void:
	if _space_choice_slot < 0:
		return
	var slot := _space_choice_slot
	hide_space_choice()
	GameEvents.ui_intent_space_choice.emit(slot, option_index)

func _on_space_choice_cancel_pressed() -> void:
	hide_space_choice()
	GameEvents.ui_intent_space_choice_cancel.emit()

func _setup_space_choice_visuals() -> void:
	if space_choice_backdrop != null:
		space_choice_backdrop.visible = false
		space_choice_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	if space_choice_title != null:
		space_choice_title.add_theme_font_size_override("font_size", 21)
	if space_choice_cancel_button != null:
		space_choice_cancel_button.visible = true
	_space_choice_option_normal_style = _make_option_style(
		Color(0.09, 0.1, 0.13, 0.9),
		Color(0.46, 0.5, 0.6, 0.72)
	)
	_space_choice_option_hover_style = _make_option_style(
		Color(0.12, 0.14, 0.18, 0.96),
		Color(0.74, 0.8, 0.94, 0.95)
	)
	_space_choice_option_pressed_style = _make_option_style(
		Color(0.15, 0.17, 0.21, 0.98),
		Color(0.92, 0.94, 0.98, 1.0)
	)

func _make_option_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _build_space_choice_option_button(
	option_text: String,
	rich_entry: Dictionary,
	visible_index: int,
	emitted_index: int,
	option_height: int
) -> Button:
	var btn := Button.new()
	btn.flat = false
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, option_height)
	if _space_choice_option_normal_style != null:
		btn.add_theme_stylebox_override("normal", _space_choice_option_normal_style)
	if _space_choice_option_hover_style != null:
		btn.add_theme_stylebox_override("hover", _space_choice_option_hover_style)
	if _space_choice_option_pressed_style != null:
		btn.add_theme_stylebox_override("pressed", _space_choice_option_pressed_style)
	btn.add_theme_color_override("font_color", Color(0.95, 0.95, 0.97, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))

	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)

	var header := Label.new()
	header.text = "Option %d" % visible_index
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", Color(0.78, 0.82, 0.9, 0.95))
	body.add_child(header)

	var has_rich_entry := not rich_entry.is_empty()
	if has_rich_entry:
		var name_label := Label.new()
		name_label.text = str(rich_entry.get("name", option_text))
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.add_theme_font_size_override("font_size", 15)
		body.add_child(name_label)

		var trigger_row := HBoxContainer.new()
		trigger_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		trigger_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var trigger_text := str(rich_entry.get("triggerText", "")).strip_edges()
		var trigger_space_id := str(rich_entry.get("triggerSpaceId", "")).strip_edges()
		if trigger_space_id != "":
			trigger_text = "agent on %s" % _resolve_board_space_name(trigger_space_id)
		if trigger_text != "":
			EffectsTokenRow.populate(trigger_row, "[get_agent_icon] %s" % trigger_text, 1.25)
		body.add_child(trigger_row)

		var rewards_row := HBoxContainer.new()
		rewards_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rewards_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		EffectsTokenRow.populate(rewards_row, str(rich_entry.get("rewardTokens", option_text)), 1.35)
		body.add_child(rewards_row)
	else:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		EffectsTokenRow.populate(row, option_text, 1.7)
		body.add_child(row)

	btn.add_child(body)
	btn.pressed.connect(_on_space_choice_option_pressed.bind(emitted_index))
	return btn

func _resolve_space_choice_option_height(options_count: int) -> int:
	if options_count <= 0:
		return 72
	var popup_height := int(space_choice_popup.size.y) if space_choice_popup != null else 460
	if space_choice_scroll != null and space_choice_scroll.size.y > 0:
		popup_height = int(space_choice_scroll.size.y) + 120
	if popup_height <= 0:
		popup_height = 460
	var title_block := 62
	var cancel_block := 48
	var padding := 32
	var usable_height := popup_height - title_block - cancel_block - padding
	if usable_height < 180:
		usable_height = 180
	var per_option := int(float(usable_height) / float(options_count))
	return clampi(per_option, 96, 256)

func _set_space_choice_backdrop_visible(value: bool) -> void:
	if space_choice_backdrop == null:
		return
	space_choice_backdrop.visible = value

func _update_labels(game_state: Dictionary) -> void:
	var round_number := int(game_state.get("round", 0))
	var current_player_id := str(game_state.get("currentPlayerId", ""))
	var phase := str(game_state.get("phase", ""))
	var current_player := _get_current_player(game_state)
	var persuasion := int(current_player.get("persuasion", 0)) if not current_player.is_empty() else 0
	var deck_size := int(current_player.get("deck", []).size()) if not current_player.is_empty() and typeof(current_player.get("deck", [])) == TYPE_ARRAY else 0
	var discard_size := int(current_player.get("discard", []).size()) if not current_player.is_empty() and typeof(current_player.get("discard", [])) == TYPE_ARRAY else 0
	var active_contracts := int(current_player.get("contractsOwned", []).size()) if not current_player.is_empty() and typeof(current_player.get("contractsOwned", [])) == TYPE_ARRAY else 0

	round_label.text = "Round: %d" % round_number
	player_label.text = "Current: %s | Phase: %s" % [current_player_id, phase]
	choam_face_up_label.text = _build_choam_face_up_text(game_state)
	var conflict_notice := _build_conflict_notice_text(game_state, current_player_id)
	if conflict_notice != "":
		player_label.text = "%s | %s" % [player_label.text, conflict_notice]
	persuasion_label.text = "Persuasion: %d" % persuasion
	deck_button.text = "Deck: %d" % deck_size
	discard_button.text = "Discard: %d" % discard_size
	contracts_button.text = "Contracts: %d" % active_contracts
	var intrigue_n := 0
	if not current_player.is_empty():
		var ir_raw: Variant = current_player.get("intrigue", [])
		if typeof(ir_raw) == TYPE_ARRAY:
			intrigue_n = (ir_raw as Array).size()
	if _intrigue_view_button != null:
		_intrigue_view_button.disabled = intrigue_n <= 0
		_intrigue_view_button.text = "Intrigue (%d)" % intrigue_n
	_update_players_table(game_state)

func _update_players_table(game_state: Dictionary) -> void:
	if players_table_rows == null:
		return
	var current_player_id := str(game_state.get("currentPlayerId", "")).strip_edges()
	var first_player_id := str(game_state.get("firstPlayerId", "")).strip_edges()
	var players: Variant = game_state.get("players", [])
	if typeof(players) != TYPE_ARRAY:
		players = []
	var desired_ids: Array[String] = []
	for player_value in players:
		if typeof(player_value) != TYPE_DICTIONARY:
			continue
		var player := player_value as Dictionary
		var player_id := str(player.get("id", "")).strip_edges()
		if player_id == "":
			continue
		desired_ids.append(player_id)
		var row: PlayerTabletRow = _player_rows_by_id.get(player_id, null) as PlayerTabletRow
		if row == null:
			row = PLAYER_TABLET_ROW_SCENE.instantiate() as PlayerTabletRow
			_player_rows_by_id[player_id] = row
		if row.get_parent() != players_table_rows:
			players_table_rows.add_child(row)
		players_table_rows.move_child(row, players_table_rows.get_child_count() - 1)
		row.bind_player(
			player,
			player_id != "" and player_id == current_player_id,
			player_id != "" and player_id == first_player_id
		)
	# Remove rows for players that no longer exist.
	var stale_ids: Array[String] = []
	for cached_id_raw in _player_rows_by_id.keys():
		var cached_id := str(cached_id_raw)
		if desired_ids.has(cached_id):
			continue
		stale_ids.append(cached_id)
	for stale_id in stale_ids:
		var stale_row: PlayerTabletRow = _player_rows_by_id.get(stale_id, null) as PlayerTabletRow
		if stale_row != null:
			stale_row.queue_free()
		_player_rows_by_id.erase(stale_id)

func _update_hand(game_state: Dictionary) -> void:
	var current_player := _get_current_player(game_state)
	var cards_by_id: Dictionary = game_state.get("cardsById", {})
	if current_player.is_empty():
		hand.set_cards([], cards_by_id)
		return

	var hand_ids = current_player.get("hand", [])
	if typeof(hand_ids) != TYPE_ARRAY:
		hand_ids = []
	hand.set_cards(hand_ids, cards_by_id)

func _get_current_player(game_state: Dictionary) -> Dictionary:
	var players = game_state.get("players", [])
	if typeof(players) != TYPE_ARRAY:
		return {}

	var current_player_id := str(game_state.get("currentPlayerId", ""))
	for player in players:
		if typeof(player) != TYPE_DICTIONARY:
			continue
		if str(player.get("id", "")) == current_player_id:
			return player
	return {}

func set_reveal_button_mode(waiting_for_end_turn: bool) -> void:
	reveal_button.text = "End Turn" if waiting_for_end_turn else "Reveal"

func set_market_interactable(value: bool) -> void:
	for list_node in [market_list, reserve_list]:
		if list_node == null:
			continue
		_set_buttons_disabled_recursive(list_node, not value)

func _update_market_if_needed(game_state: Dictionary, force: bool) -> void:
	var snapshot_key := _build_market_snapshot_key(game_state)
	if snapshot_key != _market_snapshot_key:
		_market_snapshot_key = snapshot_key
		_market_dirty = true
	if not force and (market_panel == null or not market_panel.visible):
		return
	if not _market_dirty and not force:
		return
	_update_market(game_state)
	_market_dirty = false

func _build_market_snapshot_key(game_state: Dictionary) -> String:
	var current_player := _get_current_player(game_state)
	var persuasion := int(current_player.get("persuasion", 0)) if not current_player.is_empty() else 0
	var phase := str(game_state.get("phase", ""))
	var passed_reveal := bool(current_player.get("passedReveal", false)) if not current_player.is_empty() else false
	var market_cards: Variant = game_state.get("imperiumMarket", [])
	var reserve_cards: Variant = game_state.get("reserveCards", {})
	return "%s|%s|%s|%s|%s" % [
		phase,
		str(passed_reveal),
		str(persuasion),
		JSON.stringify(market_cards),
		JSON.stringify(reserve_cards)
	]

func _update_market(game_state: Dictionary) -> void:
	_clear_children(market_list)
	_clear_children(reserve_list)

	var cards_by_id: Dictionary = game_state.get("cardsById", {})
	var current_player := _get_current_player(game_state)
	var persuasion := int(current_player.get("persuasion", 0)) if not current_player.is_empty() else 0
	var can_buy := str(game_state.get("phase", "")) == "player_turns" and bool(current_player.get("passedReveal", false))

	var market_cards = game_state.get("imperiumMarket", [])
	if typeof(market_cards) == TYPE_ARRAY:
		var market_ids: Array[String] = []
		for card_id_raw in market_cards:
			market_ids.append(str(card_id_raw))
		_add_market_cards_grid(market_list, market_ids, cards_by_id, persuasion, can_buy)

	var reserve_cards = game_state.get("reserveCards", {})
	if typeof(reserve_cards) == TYPE_DICTIONARY:
		var reserve_ids: Array = []
		for pile_id in reserve_cards.keys():
			var pile = reserve_cards[pile_id]
			if typeof(pile) != TYPE_ARRAY:
				continue
			for card_id_raw in pile:
				var card_id := str(card_id_raw)
				if reserve_ids.has(card_id):
					continue
				reserve_ids.append(card_id)
		reserve_ids.sort()
		var reserve_ids_typed: Array[String] = []
		for reserve_card_id in reserve_ids:
			reserve_ids_typed.append(str(reserve_card_id))
		_add_market_cards_grid(reserve_list, reserve_ids_typed, cards_by_id, persuasion, can_buy)

func _add_market_cards_grid(
	parent: VBoxContainer,
	card_ids: Array[String],
	cards_by_id: Dictionary,
	persuasion: int,
	can_buy: bool
) -> void:
	if parent == null:
		return
	if card_ids.is_empty():
		return
	var cards_per_row := _resolve_market_cards_per_row()
	var current_row: HBoxContainer = null
	for i in range(card_ids.size()):
		if i % cards_per_row == 0:
			current_row = HBoxContainer.new()
			current_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			current_row.alignment = BoxContainer.ALIGNMENT_BEGIN
			current_row.add_theme_constant_override("separation", int(MARKET_ROW_SEPARATION))
			parent.add_child(current_row)
		var card_id := card_ids[i]
		var card_def: Variant = cards_by_id.get(card_id, {})
		var slot := _build_market_card_slot(card_id, card_def, persuasion, can_buy)
		if slot != null:
			current_row.add_child(slot)

func _build_market_card_slot(card_id: String, card_def: Variant, persuasion: int, can_buy: bool) -> Control:
	if typeof(card_def) != TYPE_DICTIONARY:
		return null
	var cost := int(card_def.get("cost", 0))
	var slot := VBoxContainer.new()
	slot.custom_minimum_size = Vector2(MARKET_CARD_WIDTH, 0)
	slot.add_theme_constant_override("separation", 6)

	var card_ui := MARKET_CARD_UI_SCENE.instantiate() as CardUI
	card_ui.custom_minimum_size = Vector2(MARKET_CARD_WIDTH, MARKET_CARD_HEIGHT)
	card_ui.disabled = true
	card_ui.inspect_requested.connect(_on_card_inspect_requested)
	var ui_data: Dictionary = card_def.duplicate(true)
	ui_data["id"] = card_id
	card_ui.card_data = ui_data
	slot.add_child(card_ui)

	var buy_button := Button.new()
	buy_button.text = "Buy (%d)" % cost
	buy_button.disabled = not can_buy or persuasion < cost
	buy_button.pressed.connect(_on_market_buy_pressed.bind(card_id))
	slot.add_child(buy_button)
	return slot

func _resolve_market_cards_per_row() -> int:
	var available := 720.0
	if market_panel != null and market_panel.size.x > 0.0:
		# Match MarketMargin horizontal paddings (6 + 6) for exact 5-card fit.
		available = market_panel.size.x - 12.0
	var per_row := int(floor((available + MARKET_ROW_SEPARATION) / (MARKET_CARD_WIDTH + MARKET_ROW_SEPARATION)))
	per_row = clampi(per_row, 1, MARKET_ROW_MAX_CARDS)
	return per_row

func _set_buttons_disabled_recursive(node: Node, disabled_value: bool) -> void:
	if node is Button:
		(node as Button).disabled = disabled_value
	for child in node.get_children():
		_set_buttons_disabled_recursive(child, disabled_value)

func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		child.queue_free()

func _on_market_buy_pressed(card_id: String) -> void:
	GameEvents.ui_intent_market_buy.emit(card_id)

func _on_reveal_pressed() -> void:
	GameEvents.ui_intent_reveal.emit()

func _on_cancel_selection_pressed() -> void:
	GameEvents.ui_intent_cancel_card_selection.emit()

func _on_hand_card_play_requested(card_id: String) -> void:
	GameEvents.ui_intent_card_play.emit(card_id)

func _on_card_inspect_requested(card_payload: Dictionary) -> void:
	if card_inspector_popup == null:
		return
	move_child(card_inspector_popup, get_child_count() - 1)
	card_inspector_popup.show_card(card_payload)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _close_topmost_popup():
		get_viewport().set_input_as_handled()
		return

func get_right_panel_width() -> float:
	if market_panel == null or not market_panel.visible:
		return 0.0
	# Centered overlays should not reserve side layout space for the board.
	if _is_centered_modal(market_panel):
		return 0.0
	return max(market_panel.size.x + 10.0, 0.0)

func get_left_panel_width() -> float:
	if left_players_panel == null or not left_players_panel.visible:
		return 0.0
	return max(left_players_panel.size.x + 10.0, 0.0)

func _is_centered_modal(panel: Control) -> bool:
	if panel == null:
		return false
	return (
		is_equal_approx(panel.anchor_left, 0.5)
		and is_equal_approx(panel.anchor_right, 0.5)
		and is_equal_approx(panel.anchor_top, 0.5)
		and is_equal_approx(panel.anchor_bottom, 0.5)
	)

func _close_topmost_popup() -> bool:
	if space_choice_popup != null and space_choice_popup.visible:
		_on_space_choice_cancel_pressed()
		return true
	if pending_trash_popup != null and pending_trash_popup.visible:
		pending_trash_popup.visible = false
		return true
	if pending_conflict_popup != null and pending_conflict_popup.visible:
		_close_popup(pending_conflict_popup)
		return true
	if choam_popup != null and choam_popup.visible:
		_close_popup(choam_popup)
		return true
	if card_inspector_popup != null and card_inspector_popup.visible:
		card_inspector_popup.hide_popup()
		return true
	if deck_view_popup != null and deck_view_popup.visible:
		_close_popup(deck_view_popup)
		return true
	if market_panel != null and market_panel.visible:
		_close_popup(market_panel)
		return true
	return false

func _open_popup(popup: Control) -> void:
	if popup == null:
		return
	popup.visible = true

func _close_popup(popup: Control) -> void:
	if popup == null:
		return
	popup.visible = false

func _setup_intrigue_view_button() -> void:
	var top_row := get_node_or_null("TopPanel/TopMargin/TopVBox/TopRow")
	if top_row == null:
		return
	_intrigue_view_button = Button.new()
	_intrigue_view_button.name = "IntrigueViewButton"
	_intrigue_view_button.text = "Intrigue (0)"
	_intrigue_view_button.custom_minimum_size = Vector2(0, 24)
	_intrigue_view_button.disabled = true
	_intrigue_view_button.pressed.connect(_on_intrigue_view_pressed)
	var insert_at := -1
	for i in range(top_row.get_child_count()):
		if str(top_row.get_child(i).name) == "DiscardButton":
			insert_at = i + 1
			break
	top_row.add_child(_intrigue_view_button)
	if insert_at >= 0:
		top_row.move_child(_intrigue_view_button, insert_at)

func _on_intrigue_view_pressed() -> void:
	if _last_bound_state.is_empty():
		return
	var player := _get_current_player(_last_bound_state)
	if player.is_empty():
		return
	var intrigue_hand_raw: Variant = player.get("intrigue", [])
	var intrigue_hand: Array = intrigue_hand_raw if typeof(intrigue_hand_raw) == TYPE_ARRAY else []
	var ib_raw: Variant = _last_bound_state.get("intriguesById", {})
	var ib: Dictionary = ib_raw if typeof(ib_raw) == TYPE_DICTIONARY else {}
	_clear_children(deck_view_list)
	deck_view_title.text = "Intrigue hand (%d)" % intrigue_hand.size()
	for iid_raw in intrigue_hand:
		var iid := str(iid_raw)
		var def_raw: Variant = ib.get(iid, {})
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 4)
		var title_lbl := Label.new()
		if typeof(def_raw) == TYPE_DICTIONARY:
			var def: Dictionary = def_raw
			title_lbl.text = "%s  [%s]" % [str(def.get("name", iid)), str(def.get("intrigueType", "?"))]
			var body_lbl := Label.new()
			body_lbl.text = IntrigueEffectTextScript.format_intrigue_card_def(def)
			body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			block.add_child(title_lbl)
			block.add_child(body_lbl)
		else:
			title_lbl.text = iid
			block.add_child(title_lbl)
		deck_view_list.add_child(block)
	_open_popup(deck_view_popup)

func _on_deck_button_pressed() -> void:
	_show_zone_cards("deck", "Deck")

func _on_discard_button_pressed() -> void:
	_show_zone_cards("discard", "Discard")

func _on_contracts_button_pressed() -> void:
	if _last_bound_state.is_empty():
		return
	var player := _get_current_player(_last_bound_state)
	if player.is_empty():
		return
	var contracts_by_id_raw: Variant = _last_bound_state.get("choamContractsById", {})
	var contracts_by_id: Dictionary = contracts_by_id_raw if typeof(contracts_by_id_raw) == TYPE_DICTIONARY else {}
	var owned_raw: Variant = player.get("contractsOwned", [])
	var completed_raw: Variant = player.get("contractsCompleted", [])
	var owned: Array = owned_raw if typeof(owned_raw) == TYPE_ARRAY else []
	var completed: Array = completed_raw if typeof(completed_raw) == TYPE_ARRAY else []
	var owned_sorted := _sort_contract_ids_for_display(owned, contracts_by_id)
	var completed_sorted := _sort_contract_ids_for_display(completed, contracts_by_id)

	_clear_children(deck_view_list)
	deck_view_title.text = "Contracts (%d active, %d completed)" % [owned_sorted.size(), completed_sorted.size()]

	var active_header := Label.new()
	active_header.text = "Active"
	active_header.add_theme_font_size_override("font_size", 14)
	deck_view_list.add_child(active_header)
	if owned_sorted.is_empty():
		var none_active := Label.new()
		none_active.text = "- none"
		deck_view_list.add_child(none_active)
	else:
		for contract_id in owned_sorted:
			deck_view_list.add_child(_build_contract_compact_card(contracts_by_id, contract_id, false))

	var completed_header := Label.new()
	completed_header.text = "Completed"
	completed_header.add_theme_font_size_override("font_size", 14)
	deck_view_list.add_child(completed_header)
	if completed_sorted.is_empty():
		var none_completed := Label.new()
		none_completed.text = "- none"
		deck_view_list.add_child(none_completed)
	else:
		for contract_id in completed_sorted:
			deck_view_list.add_child(_build_contract_compact_card(contracts_by_id, contract_id, true))

	_open_popup(deck_view_popup)

func _on_market_button_pressed() -> void:
	if market_panel == null:
		return
	if market_panel.visible:
		_close_popup(market_panel)
		if not _last_bound_state.is_empty():
			_update_intrigue_controls_row(_last_bound_state)
		return
	move_child(market_panel, get_child_count() - 1)
	market_panel.z_index = 100
	_open_popup(market_panel)
	if not _last_bound_state.is_empty():
		_update_market_if_needed(_last_bound_state, true)
		_update_intrigue_controls_row(_last_bound_state)

func _on_market_close_button_pressed() -> void:
	if market_panel == null:
		return
	_close_popup(market_panel)
	if not _last_bound_state.is_empty():
		_update_intrigue_controls_row(_last_bound_state)

func _on_deck_view_close_pressed() -> void:
	_close_popup(deck_view_popup)

func _show_zone_cards(zone_key: String, title_text: String) -> void:
	if _last_bound_state.is_empty():
		return
	var player := _get_current_player(_last_bound_state)
	if player.is_empty():
		return
	var zone_cards = player.get(zone_key, [])
	if typeof(zone_cards) != TYPE_ARRAY:
		zone_cards = []
	var cards_by_id: Dictionary = _last_bound_state.get("cardsById", {})

	_clear_children(deck_view_list)
	deck_view_title.text = "%s (%d)" % [title_text, zone_cards.size()]
	for card_id_raw in zone_cards:
		var card_id := str(card_id_raw)
		var card_def = cards_by_id.get(card_id, {})
		var card_name := card_id
		if typeof(card_def) == TYPE_DICTIONARY:
			card_name = str(card_def.get("name", card_id))
		var line := Label.new()
		line.text = "- %s" % card_name
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		deck_view_list.add_child(line)
	_open_popup(deck_view_popup)

func _update_pending_trash_popup(game_state: Dictionary) -> void:
	var current_player := _get_current_player(game_state)
	if current_player.is_empty():
		pending_trash_popup.visible = false
		return

	var pending_trash := int(current_player.get("pendingTrash", 0))
	if pending_trash <= 0:
		pending_trash_popup.visible = false
		_pending_zone_selected = ""
		_pending_card_selected = ""
		pending_trash_confirm_button.disabled = true
		return

	pending_trash_count_label.text = "Remaining: %d" % pending_trash
	var allowed_zones: Array = ["hand", "discard"]
	var pending_queue_raw: Variant = current_player.get("pendingTrashQueue", [])
	if typeof(pending_queue_raw) == TYPE_ARRAY:
		var pending_queue: Array = pending_queue_raw
		if not pending_queue.is_empty() and typeof(pending_queue[0]) == TYPE_DICTIONARY:
			var queue_entry: Dictionary = pending_queue[0]
			var zones_raw: Variant = queue_entry.get("allowedZones", [])
			if typeof(zones_raw) == TYPE_ARRAY and not (zones_raw as Array).is_empty():
				allowed_zones = zones_raw

	_pending_hand_cards = current_player.get("hand", [])
	if typeof(_pending_hand_cards) != TYPE_ARRAY:
		_pending_hand_cards = []
	_pending_discard_cards = current_player.get("discard", [])
	if typeof(_pending_discard_cards) != TYPE_ARRAY:
		_pending_discard_cards = []
	_pending_in_play_cards = current_player.get("inPlay", [])
	if typeof(_pending_in_play_cards) != TYPE_ARRAY:
		_pending_in_play_cards = []

	_fill_pending_zone_list(pending_hand_list, _pending_hand_cards, game_state)
	_fill_pending_zone_list(pending_discard_list, _pending_discard_cards, game_state)
	_fill_pending_zone_list(pending_in_play_list, _pending_in_play_cards, game_state)
	if pending_hand_list != null:
		pending_hand_list.visible = allowed_zones.has("hand")
		if pending_hand_list.get_parent() != null:
			(pending_hand_list.get_parent() as Control).visible = pending_hand_list.visible
	if pending_discard_list != null:
		pending_discard_list.visible = allowed_zones.has("discard")
		if pending_discard_list.get_parent() != null:
			(pending_discard_list.get_parent() as Control).visible = pending_discard_list.visible
	if pending_in_play_list != null:
		pending_in_play_list.visible = allowed_zones.has("inPlay")
		if pending_in_play_list.get_parent() != null:
			(pending_in_play_list.get_parent() as Control).visible = pending_in_play_list.visible
	if _pending_zone_selected != "" and not allowed_zones.has(_pending_zone_selected):
		_pending_zone_selected = ""
		_pending_card_selected = ""
		pending_trash_confirm_button.disabled = true
	pending_trash_popup.visible = true

func _update_pending_conflict_popup(game_state: Dictionary) -> void:
	var current_player := _get_current_player(game_state)
	if current_player.is_empty():
		pending_conflict_popup.visible = false
		return
	# Trash selection takes priority if both are pending.
	if int(current_player.get("pendingTrash", 0)) > 0:
		pending_conflict_popup.visible = false
		return

	var max_deploy := int(current_player.get("pendingConflictDeployMax", 0))
	if max_deploy <= 0:
		pending_conflict_popup.visible = false
		return

	var worms_in_conflict := int(current_player.get("sandwormsInConflict", 0))
	pending_conflict_label.text = "Send troops from garrison to conflict (0..%d). Worms: %d" % [max_deploy, worms_in_conflict]
	pending_conflict_spinbox.min_value = 0
	pending_conflict_spinbox.max_value = max_deploy
	if pending_conflict_spinbox.value > max_deploy:
		pending_conflict_spinbox.value = max_deploy
	pending_conflict_popup.visible = true

func _build_conflict_notice_text(game_state: Dictionary, current_player_id: String) -> String:
	var notice = game_state.get("lastConflictNotice", {})
	if typeof(notice) != TYPE_DICTIONARY:
		return ""
	if str(notice.get("playerId", "")) != current_player_id:
		return ""
	var notice_type := str(notice.get("type", ""))
	if notice_type == "sandworm_summon_blocked":
		return "Worm summon blocked by Shield Wall"
	if notice_type == "sandworm_summoned":
		var amount := int(notice.get("amount", 0))
		return "Summoned worms to conflict (+%d)" % amount
	return ""

func _build_choam_face_up_text(game_state: Dictionary) -> String:
	var face_up_raw: Variant = game_state.get("choamFaceUpContracts", [])
	if typeof(face_up_raw) != TYPE_ARRAY:
		return "CHOAM face-up: -"
	var face_up: Array = face_up_raw
	if face_up.is_empty():
		return "CHOAM face-up: empty"
	var contracts_by_id_raw: Variant = game_state.get("choamContractsById", {})
	var contracts_by_id: Dictionary = contracts_by_id_raw if typeof(contracts_by_id_raw) == TYPE_DICTIONARY else {}
	var parts: Array[String] = []
	for contract_id_raw in face_up:
		var contract_id := str(contract_id_raw)
		var contract_def_raw: Variant = contracts_by_id.get(contract_id, {})
		if typeof(contract_def_raw) != TYPE_DICTIONARY:
			parts.append(contract_id)
			continue
		var contract_def: Dictionary = contract_def_raw
		var contract_name := str(contract_def.get("name", contract_id))
		parts.append(contract_name)
	return "CHOAM face-up: %s" % ", ".join(parts)

func _on_choam_details_pressed() -> void:
	if _last_bound_state.is_empty() or choam_popup == null:
		return
	_rebuild_choam_popup(_last_bound_state)
	_open_popup(choam_popup)

func _on_choam_popup_close_pressed() -> void:
	if choam_popup == null:
		return
	_close_popup(choam_popup)

func _rebuild_choam_popup(game_state: Dictionary) -> void:
	if choam_popup_list == null:
		return
	_clear_children(choam_popup_list)
	var face_up_raw: Variant = game_state.get("choamFaceUpContracts", [])
	var contracts_by_id_raw: Variant = game_state.get("choamContractsById", {})
	if typeof(face_up_raw) != TYPE_ARRAY:
		return
	var face_up: Array = face_up_raw
	var contracts_by_id: Dictionary = contracts_by_id_raw if typeof(contracts_by_id_raw) == TYPE_DICTIONARY else {}
	if face_up.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No face-up contracts available."
		choam_popup_list.add_child(empty_label)
		return
	for contract_id_raw in face_up:
		var contract_id := str(contract_id_raw)
		var contract_def_raw: Variant = contracts_by_id.get(contract_id, {})
		var contract_def: Dictionary = contract_def_raw if typeof(contract_def_raw) == TYPE_DICTIONARY else {}
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 4)
		choam_popup_list.add_child(card)

		var name_label := Label.new()
		name_label.text = str(contract_def.get("name", contract_id))
		name_label.add_theme_font_size_override("font_size", 14)
		card.add_child(name_label)

		var trigger_label := Label.new()
		var trigger: Dictionary = contract_def.get("trigger", {})
		var trigger_space := str(trigger.get("spaceId", ""))
		var trigger_space_name := _resolve_board_space_name(trigger_space)
		trigger_label.text = "Trigger: send Agent to %s" % trigger_space_name
		card.add_child(trigger_label)

		var rewards_row := HBoxContainer.new()
		rewards_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_child(rewards_row)
		var reward_tokens := _contract_rewards_to_tokens(contract_def.get("rewardEffects", []))
		EffectsTokenRow.populate(rewards_row, reward_tokens, 1.3)

func _contract_rewards_to_tokens(reward_effects: Variant) -> String:
	if typeof(reward_effects) != TYPE_ARRAY:
		return "-"
	var parts: Array[String] = []
	for effect_raw in reward_effects:
		if typeof(effect_raw) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = effect_raw
		var effect_type := str(effect.get("type", ""))
		var amount := int(effect.get("amount", 0))
		match effect_type:
			"gain_resource":
				var resource := str(effect.get("resource", ""))
				if resource == "solari":
					parts.append("[solari_badge:%d]" % amount)
				elif resource == "spice":
					parts.append("[spice_badge:%d]" % amount)
				elif resource == "water":
					parts.append("[water_badge:%d]" % amount)
				else:
					parts.append("+%d %s" % [amount, resource])
			"draw_cards":
				for _i in range(maxi(amount, 1)):
					parts.append("[draw_card_icon]")
			"draw_intrigue":
				for _i in range(maxi(amount, 1)):
					parts.append("[intrigue_icon]")
			"recruit_troops":
				parts.append("[troops_badge:%d]" % amount)
			"gain_influence":
				parts.append("[faction_icon:%s]" % str(effect.get("faction", "")))
			_:
				parts.append(effect_type)
	if parts.is_empty():
		return "-"
	return " ".join(parts)

func _resolve_board_space_name(space_id: String) -> String:
	if space_id == "":
		return "unknown space"
	var space_def: Dictionary = _board_spaces_repo.get_by_id(space_id)
	if space_def.is_empty():
		return space_id
	var space_name := str(space_def.get("name", "")).strip_edges()
	if space_name == "":
		return space_id
	return space_name

func _contract_display_name(contracts_by_id: Dictionary, contract_id: String) -> String:
	var raw: Variant = contracts_by_id.get(contract_id, {})
	if typeof(raw) != TYPE_DICTIONARY:
		return contract_id
	var contract_def: Dictionary = raw
	var contract_name := str(contract_def.get("name", "")).strip_edges()
	return contract_id if contract_name == "" else contract_name

func _sort_contract_ids_for_display(contract_ids: Array, contracts_by_id: Dictionary) -> Array[String]:
	var rows: Array = []
	for contract_id_raw in contract_ids:
		var contract_id := str(contract_id_raw)
		var contract_def_raw: Variant = contracts_by_id.get(contract_id, {})
		var contract_def: Dictionary = contract_def_raw if typeof(contract_def_raw) == TYPE_DICTIONARY else {}
		var trigger_raw: Variant = contract_def.get("trigger", {})
		var trigger: Dictionary = trigger_raw if typeof(trigger_raw) == TYPE_DICTIONARY else {}
		rows.append({
			"id": contract_id,
			"name": _contract_display_name(contracts_by_id, contract_id).to_lower(),
			"space": str(trigger.get("spaceId", "")).to_lower()
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_space := str(a.get("space", ""))
		var b_space := str(b.get("space", ""))
		if a_space == b_space:
			return str(a.get("name", "")) < str(b.get("name", ""))
		return a_space < b_space
	)
	var sorted_ids: Array[String] = []
	for row_raw in rows:
		if typeof(row_raw) != TYPE_DICTIONARY:
			continue
		sorted_ids.append(str((row_raw as Dictionary).get("id", "")))
	return sorted_ids

func _build_contract_compact_card(contracts_by_id: Dictionary, contract_id: String, is_completed: bool) -> Control:
	var card := VBoxContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_constant_override("separation", 2)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(header)

	var name_label := Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text = _contract_display_name(contracts_by_id, contract_id)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 12)
	header.add_child(name_label)

	var status_label := Label.new()
	status_label.text = "done" if is_completed else "active"
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", Color(0.68, 0.76, 0.9, 0.95) if not is_completed else Color(0.72, 0.9, 0.72, 0.95))
	header.add_child(status_label)

	var contract_def_raw: Variant = contracts_by_id.get(contract_id, {})
	var contract_def: Dictionary = contract_def_raw if typeof(contract_def_raw) == TYPE_DICTIONARY else {}
	var trigger_raw: Variant = contract_def.get("trigger", {})
	var trigger: Dictionary = trigger_raw if typeof(trigger_raw) == TYPE_DICTIONARY else {}
	var trigger_space_id := str(trigger.get("spaceId", ""))
	var trigger_space_name := _resolve_board_space_name(trigger_space_id)

	var trigger_row := HBoxContainer.new()
	trigger_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(trigger_row)
	EffectsTokenRow.populate(trigger_row, "[get_agent_icon] %s" % trigger_space_name, 0.95)

	var rewards_row := HBoxContainer.new()
	rewards_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(rewards_row)
	EffectsTokenRow.populate(rewards_row, _contract_rewards_to_tokens(contract_def.get("rewardEffects", [])), 1.0)

	var separator := HSeparator.new()
	separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(separator)
	return card

func _fill_pending_zone_list(list: ItemList, cards: Array, game_state: Dictionary) -> void:
	list.clear()
	var cards_by_id: Dictionary = game_state.get("cardsById", {})
	for card_id_raw in cards:
		var card_id := str(card_id_raw)
		var card_name := card_id
		var card_def = cards_by_id.get(card_id, {})
		if typeof(card_def) == TYPE_DICTIONARY:
			card_name = str(card_def.get("name", card_id))
		list.add_item(card_name)

func _on_pending_hand_item_selected(index: int) -> void:
	if index < 0 or index >= _pending_hand_cards.size():
		return
	pending_discard_list.deselect_all()
	pending_in_play_list.deselect_all()
	_pending_zone_selected = "hand"
	_pending_card_selected = str(_pending_hand_cards[index])
	pending_trash_confirm_button.disabled = false

func _on_pending_discard_item_selected(index: int) -> void:
	if index < 0 or index >= _pending_discard_cards.size():
		return
	pending_hand_list.deselect_all()
	pending_in_play_list.deselect_all()
	_pending_zone_selected = "discard"
	_pending_card_selected = str(_pending_discard_cards[index])
	pending_trash_confirm_button.disabled = false

func _on_pending_in_play_item_selected(index: int) -> void:
	if index < 0 or index >= _pending_in_play_cards.size():
		return
	pending_hand_list.deselect_all()
	pending_discard_list.deselect_all()
	_pending_zone_selected = "inPlay"
	_pending_card_selected = str(_pending_in_play_cards[index])
	pending_trash_confirm_button.disabled = false

func _on_pending_trash_confirm_pressed() -> void:
	if _pending_zone_selected == "" or _pending_card_selected == "":
		return
	GameEvents.ui_intent_pending_trash.emit(_pending_zone_selected, _pending_card_selected)
	_pending_zone_selected = ""
	_pending_card_selected = ""
	pending_trash_confirm_button.disabled = true

func _on_pending_conflict_confirm_pressed() -> void:
	var amount := int(pending_conflict_spinbox.value)
	GameEvents.ui_intent_pending_conflict_deploy.emit(amount)

func _fill_intrigue_option_by_type(option: OptionButton, game_state: Dictionary, type_filter: String) -> void:
	if option == null:
		return
	option.clear()
	var player := _get_current_player(game_state)
	if player.is_empty():
		return
	var intrigue_hand_raw: Variant = player.get("intrigue", [])
	var intrigue_hand: Array = intrigue_hand_raw if typeof(intrigue_hand_raw) == TYPE_ARRAY else []
	var ib_raw: Variant = game_state.get("intriguesById", {})
	var ib: Dictionary = ib_raw if typeof(ib_raw) == TYPE_DICTIONARY else {}
	var want := type_filter.strip_edges().to_lower()
	for iid_raw in intrigue_hand:
		var iid := str(iid_raw)
		var def_raw: Variant = ib.get(iid, {})
		if typeof(def_raw) != TYPE_DICTIONARY:
			continue
		var it := str((def_raw as Dictionary).get("intrigueType", "")).strip_edges().to_lower()
		var is_anytime_draw := false
		if want == "plot":
			var fx_raw: Variant = (def_raw as Dictionary).get("playEffect", [])
			if typeof(fx_raw) == TYPE_ARRAY:
				for fx in (fx_raw as Array):
					if typeof(fx) == TYPE_DICTIONARY and str((fx as Dictionary).get("type", "")).strip_edges().to_lower() == "draw_cards":
						is_anytime_draw = true
						break
		if it != want and not is_anytime_draw:
			continue
		var def: Dictionary = def_raw
		var item_label := str(def.get("name", iid))
		option.add_item(item_label)
		var last_idx := option.get_item_count() - 1
		option.set_item_metadata(last_idx, iid)

func _setup_intrigue_controls_row() -> void:
	_intrigue_controls_panel = PanelContainer.new()
	_intrigue_controls_panel.name = "IntrigueControlsPanel"
	_intrigue_controls_panel.anchor_left = 0.0
	_intrigue_controls_panel.anchor_top = 1.0
	_intrigue_controls_panel.anchor_right = 0.0
	_intrigue_controls_panel.anchor_bottom = 1.0
	_intrigue_controls_panel.offset_left = 10.0
	_intrigue_controls_panel.offset_top = -108.0
	_intrigue_controls_panel.offset_right = 500.0
	_intrigue_controls_panel.offset_bottom = -66.0
	_intrigue_controls_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_intrigue_controls_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(_intrigue_controls_panel)
	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 6)
	panel_margin.add_theme_constant_override("margin_top", 6)
	panel_margin.add_theme_constant_override("margin_right", 6)
	panel_margin.add_theme_constant_override("margin_bottom", 6)
	_intrigue_controls_panel.add_child(panel_margin)
	_intrigue_bar = HBoxContainer.new()
	_intrigue_bar.name = "IntrigueControlsRow"
	_intrigue_bar.visible = false
	_intrigue_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_margin.add_child(_intrigue_bar)
	var pass_combat := Button.new()
	pass_combat.text = "Pass (combat)"
	pass_combat.custom_minimum_size = Vector2(0, 22)
	pass_combat.add_theme_font_size_override("font_size", 11)
	pass_combat.pressed.connect(func() -> void:
		GameEvents.ui_intent_combat_intrigue_pass.emit()
	)
	var play_combat := Button.new()
	play_combat.text = "Play combat"
	play_combat.custom_minimum_size = Vector2(0, 22)
	play_combat.add_theme_font_size_override("font_size", 11)
	play_combat.pressed.connect(_on_intrigue_play_combat_pressed)
	_combat_intrigue_option = OptionButton.new()
	_combat_intrigue_option.custom_minimum_size = Vector2(130, 22)
	_combat_intrigue_option.add_theme_font_size_override("font_size", 11)
	var plot_btn := Button.new()
	plot_btn.text = "Play plot"
	plot_btn.custom_minimum_size = Vector2(0, 22)
	plot_btn.add_theme_font_size_override("font_size", 11)
	plot_btn.pressed.connect(_on_intrigue_play_plot_pressed)
	_plot_intrigue_option = OptionButton.new()
	_plot_intrigue_option.custom_minimum_size = Vector2(130, 22)
	_plot_intrigue_option.add_theme_font_size_override("font_size", 11)
	var imm_play := Button.new()
	imm_play.text = "Play (conflict-win)"
	imm_play.custom_minimum_size = Vector2(0, 22)
	imm_play.add_theme_font_size_override("font_size", 11)
	imm_play.pressed.connect(func() -> void:
		GameEvents.ui_intent_immediate_conflict_win_intrigue_play.emit()
	)
	var imm_decl := Button.new()
	imm_decl.text = "Decline immediate"
	imm_decl.custom_minimum_size = Vector2(0, 22)
	imm_decl.add_theme_font_size_override("font_size", 11)
	imm_decl.pressed.connect(func() -> void:
		GameEvents.ui_intent_immediate_conflict_win_intrigue_decline.emit()
	)
	var eg_pass := Button.new()
	eg_pass.text = "Pass (endgame)"
	eg_pass.custom_minimum_size = Vector2(0, 22)
	eg_pass.add_theme_font_size_override("font_size", 11)
	eg_pass.pressed.connect(func() -> void:
		GameEvents.ui_intent_endgame_intrigue_pass.emit()
	)
	var eg_play := Button.new()
	eg_play.text = "Play endgame"
	eg_play.custom_minimum_size = Vector2(0, 22)
	eg_play.add_theme_font_size_override("font_size", 11)
	eg_play.pressed.connect(_on_intrigue_play_endgame_pressed)
	_endgame_intrigue_option = OptionButton.new()
	_endgame_intrigue_option.custom_minimum_size = Vector2(130, 22)
	_endgame_intrigue_option.add_theme_font_size_override("font_size", 11)
	for n in [
		pass_combat,
		play_combat,
		_combat_intrigue_option,
		plot_btn,
		_plot_intrigue_option,
		imm_play,
		imm_decl,
		eg_pass,
		eg_play,
		_endgame_intrigue_option
	]:
		_intrigue_bar.add_child(n)

func _on_intrigue_play_combat_pressed() -> void:
	if _combat_intrigue_option == null or _combat_intrigue_option.get_item_count() <= 0:
		return
	var idx := _combat_intrigue_option.selected
	var meta: Variant = _combat_intrigue_option.get_item_metadata(idx)
	var iid := str(meta)
	if iid == "":
		return
	GameEvents.ui_intent_combat_intrigue_play.emit(iid)

func _on_intrigue_play_plot_pressed() -> void:
	if _plot_intrigue_option == null or _plot_intrigue_option.get_item_count() <= 0:
		return
	var idx := _plot_intrigue_option.selected
	var meta: Variant = _plot_intrigue_option.get_item_metadata(idx)
	var iid := str(meta)
	if iid == "":
		return
	GameEvents.ui_intent_plot_intrigue_play.emit(iid)

func _on_intrigue_play_endgame_pressed() -> void:
	if _endgame_intrigue_option == null or _endgame_intrigue_option.get_item_count() <= 0:
		return
	var idx := _endgame_intrigue_option.selected
	var meta: Variant = _endgame_intrigue_option.get_item_metadata(idx)
	var iid := str(meta)
	if iid == "":
		return
	GameEvents.ui_intent_endgame_intrigue_play.emit(iid)

func _update_intrigue_controls_row(game_state: Dictionary) -> void:
	if _intrigue_bar == null:
		return
	var phase := str(game_state.get("phase", ""))
	var status := str(game_state.get("status", ""))
	var cir_raw: Variant = game_state.get("combatIntrigueRound", {})
	var cir: Dictionary = cir_raw if typeof(cir_raw) == TYPE_DICTIONARY else {}
	var pic_raw: Variant = game_state.get("pendingImmediateConflictWinIntrigue", {})
	var pic: Dictionary = pic_raw if typeof(pic_raw) == TYPE_DICTIONARY else {}
	var eir_raw: Variant = game_state.get("endgameIntrigueRound", {})
	var eir: Dictionary = eir_raw if typeof(eir_raw) == TYPE_DICTIONARY else {}
	var show_combat := phase == "conflict" and str(cir.get("status", "")) == "open"
	var show_immediate := not pic.is_empty()
	var show_plot := status != "finished"
	var show_end := status == "finished" and str(eir.get("status", "")) == "open"
	var show_any := show_combat or show_immediate or show_plot or show_end
	if market_panel != null and market_panel.visible:
		show_any = false
	_intrigue_bar.visible = show_any
	if _intrigue_controls_panel != null:
		_intrigue_controls_panel.visible = show_any
	_fill_intrigue_option_by_type(_combat_intrigue_option, game_state, "combat")
	_fill_intrigue_option_by_type(_plot_intrigue_option, game_state, "plot")
	_fill_intrigue_option_by_type(_endgame_intrigue_option, game_state, "endgame")
	var ch := _intrigue_bar.get_children()
	if ch.size() >= 10:
		(ch[0] as Control).visible = show_combat
		(ch[1] as Control).visible = show_combat
		(ch[2] as Control).visible = show_combat
		(ch[3] as Control).visible = show_plot
		(ch[4] as Control).visible = show_plot
		(ch[5] as Control).visible = show_immediate
		(ch[6] as Control).visible = show_immediate
		(ch[7] as Control).visible = show_end
		(ch[8] as Control).visible = show_end
		(ch[9] as Control).visible = show_end
	if ch.size() >= 10 and _combat_intrigue_option != null:
		var n := _combat_intrigue_option.get_item_count()
		(ch[1] as Button).disabled = show_combat and n <= 0
	if ch.size() >= 10 and _plot_intrigue_option != null:
		var np := _plot_intrigue_option.get_item_count()
		(ch[3] as Button).disabled = show_plot and np <= 0
	if ch.size() >= 10 and _endgame_intrigue_option != null:
		var ne := _endgame_intrigue_option.get_item_count()
		(ch[8] as Button).disabled = show_end and ne <= 0

func get_top_panel_height() -> float:
	if top_panel == null:
		return 0.0
	return max(top_panel.size.y, 0.0)

func get_bottom_overlay_height() -> float:
	if hand_dock != null:
		return hand_dock.get_reserved_bottom_height()
	if hand == null:
		return 0.0
	var viewport_height := get_viewport().get_visible_rect().size.y
	var hand_top := hand.global_position.y
	return max(viewport_height - hand_top, 0.0)
