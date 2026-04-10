extends Control
class_name HandDock

## Bottom strip reserved for layout (GameRoot scales the board using this, not expanded height).
@export var collapsed_height: float = 45.0
@export var expanded_height: float = 240.0
## Cursor within this many pixels from the bottom of the viewport expands the dock.
@export var bottom_hover_px: float = 78.0
@export var tween_duration: float = 0.18

## Scene setup: Hand (HBox) is top-aligned inside this control so when collapsed and clipped,
## the visible strip shows the top of cards (headers/art), not the bottom edge.

var _expanded: bool = false
var _tween: Tween

@onready var hand: Hand = %Hand


func _ready() -> void:
	_apply_height_immediate(collapsed_height)


func _height_to_offset_top(height: float) -> float:
	return offset_bottom - height


func _process(_delta: float) -> void:
	var vp := get_viewport()
	var rect := vp.get_visible_rect()
	var mouse := vp.get_mouse_position()
	var h := rect.size.y
	var in_bottom_zone := mouse.y > h - bottom_hover_px
	var over_dock := get_global_rect().has_point(mouse)
	var want_expanded := in_bottom_zone or over_dock
	if want_expanded == _expanded:
		return
	_expanded = want_expanded
	_animate_to(want_expanded)


func get_reserved_bottom_height() -> float:
	return collapsed_height


func _apply_height_immediate(height: float) -> void:
	offset_top = _height_to_offset_top(height)


func _animate_to(expand: bool) -> void:
	var target_h := expanded_height if expand else collapsed_height
	var target_top := _height_to_offset_top(target_h)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, "offset_top", target_top, tween_duration)
