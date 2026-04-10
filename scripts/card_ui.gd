class_name CardUI
extends Control

signal play_requested(card_id: String)

@export var card_data: Dictionary : set = set_card_data
@export var disabled := false

@onready var card_visuals: CardVisuals = $CardVisuals

var _is_dragging := false
var _drag_offset := Vector2.ZERO
var _original_global_position := Vector2.ZERO
var _original_local_position := Vector2.ZERO
var _play_line_y := 0.0

func set_card_data(value: Dictionary) -> void:
	if card_data == value:
		return
	card_data = value
	if not is_node_ready():
		await ready
	card_visuals.card_data = card_data

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_set_children_mouse_filter_ignore(card_visuals)

func _gui_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton:
		return
	var button_event := event as InputEventMouseButton
	if disabled:
		return
	if button_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if button_event.pressed:
		_start_drag()
		accept_event()
		return

func _process(_delta: float) -> void:
	if not _is_dragging:
		return
	global_position = get_global_mouse_position() - _drag_offset
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_finish_drag()

func _start_drag() -> void:
	_is_dragging = true
	_original_global_position = global_position
	_original_local_position = position
	_drag_offset = get_global_mouse_position() - global_position
	_play_line_y = _resolve_play_line_y()
	top_level = true
	z_index = 100

func _finish_drag() -> void:
	_is_dragging = false
	var should_play := global_position.y < _play_line_y

	if should_play:
		# Keep visual state stable until hand refresh removes/rebuilds cards.
		global_position = _original_global_position
		top_level = false
		z_index = 0
		position = _original_local_position
		play_requested.emit(str(card_data.get("id", "")))
		return

	# Restore while still top_level, then restore local layout slot in the hand.
	global_position = _original_global_position
	top_level = false
	z_index = 0
	position = _original_local_position

func _resolve_play_line_y() -> float:
	var hand_node := get_parent()
	if hand_node == null:
		return global_position.y - 1.0
	var hand_control := hand_node as Control
	if hand_control == null:
		return global_position.y - 1.0
	return hand_control.global_position.y - 12.0

func _set_children_mouse_filter_ignore(root: Node) -> void:
	if root == null:
		return
	for child in root.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)
