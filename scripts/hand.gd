class_name Hand
extends HBoxContainer

signal card_play_requested(card_id: String)

const CARD_UI_SCENE := preload("res://scenes/card_ui.tscn")
var _cards_interactable := true
var _card_nodes_by_key: Dictionary = {}

func set_cards(card_ids: Array, cards_by_id: Dictionary) -> void:
	var desired_order_keys: Array[String] = []
	for index in range(card_ids.size()):
		var card_id := str(card_ids[index])
		var card_def: Variant = cards_by_id.get(card_id, {})
		if typeof(card_def) != TYPE_DICTIONARY:
			continue
		var key := _make_hand_card_key(card_id, desired_order_keys)
		desired_order_keys.append(key)
		var card_ui: CardUI = _card_nodes_by_key.get(key, null) as CardUI
		if card_ui == null:
			card_ui = _create_card_ui(card_id, card_def)
			_card_nodes_by_key[key] = card_ui
			add_child(card_ui)
		else:
			_rebind_card_ui(card_ui, card_id, card_def)
		card_ui.disabled = not _cards_interactable
		move_child(card_ui, get_child_count() - 1)
	_cleanup_removed_cards(desired_order_keys)

func add_card(card_id: String, card_def: Dictionary) -> void:
	var key := _make_hand_card_key(card_id, _card_nodes_by_key.keys())
	var card_ui := _create_card_ui(card_id, card_def)
	_card_nodes_by_key[key] = card_ui
	add_child(card_ui)
	card_ui.disabled = not _cards_interactable

func set_cards_interactable(value: bool) -> void:
	_cards_interactable = value
	for child in get_children():
		if child is CardUI:
			(child as CardUI).disabled = not value

func _clear_cards() -> void:
	for child in get_children():
		child.queue_free()
	_card_nodes_by_key.clear()

func _on_card_ui_play_requested(card_id: String, _card_ui: CardUI) -> void:
	card_play_requested.emit(card_id)

func _create_card_ui(card_id: String, card_def: Dictionary) -> CardUI:
	var new_card_ui := CARD_UI_SCENE.instantiate() as CardUI
	new_card_ui.play_requested.connect(_on_card_ui_play_requested.bind(new_card_ui))
	_rebind_card_ui(new_card_ui, card_id, card_def)
	return new_card_ui

func _rebind_card_ui(card_ui: CardUI, card_id: String, card_def: Dictionary) -> void:
	var ui_data: Dictionary = card_def.duplicate(true)
	ui_data["id"] = card_id
	if card_ui.card_data != ui_data:
		card_ui.card_data = ui_data

func _cleanup_removed_cards(desired_order_keys: Array[String]) -> void:
	var stale_keys: Array[String] = []
	for existing_key_raw in _card_nodes_by_key.keys():
		var existing_key := str(existing_key_raw)
		if desired_order_keys.has(existing_key):
			continue
		stale_keys.append(existing_key)
	for stale_key in stale_keys:
		var card_ui: CardUI = _card_nodes_by_key.get(stale_key, null) as CardUI
		if card_ui != null:
			card_ui.queue_free()
		_card_nodes_by_key.erase(stale_key)

func _make_hand_card_key(card_id: String, used_keys: Array) -> String:
	var index := 0
	while true:
		var candidate := "%s#%d" % [card_id, index]
		if not used_keys.has(candidate):
			return candidate
		index += 1
	return "%s#%d" % [card_id, index]
