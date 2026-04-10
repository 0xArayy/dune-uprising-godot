extends Node2D
class_name VpTracker

@export var min_points: int = 0
@export var max_points: int = 12
@export var vp_icon: Texture2D = preload("res://data/icons/vp.png")

var _player_values: Array[int] = [0, 0]
const WIN_THRESHOLD := 10

const TRACKER_SIZE := Vector2(92, 996)
const HEADER_CENTER := Vector2(46, 44)
const TRACK_X := 38.0
const TRACK_TOP := 94.0
const TRACK_BOTTOM := 946.0
const PLAYER_TOKEN_COLORS: Array[Color] = [
	Color(0.95, 0.78, 0.33, 1.0),
	Color(0.44, 0.74, 0.97, 1.0),
	Color(0.85, 0.48, 0.86, 1.0),
	Color(0.58, 0.9, 0.57, 1.0)
]
const TOKEN_OFFSETS: Array[Vector2] = [
	Vector2(-14.0, -8.0),
	Vector2(14.0, -8.0),
	Vector2(-14.0, 8.0),
	Vector2(14.0, 8.0)
]

func set_player_values(values: Array) -> void:
	_player_values.clear()
	for value in values:
		_player_values.append(int(value))
	queue_redraw()

func _draw() -> void:
	var outer := Rect2(Vector2.ZERO, TRACKER_SIZE)
	draw_rect(outer, Color(0.07, 0.07, 0.09, 0.78), true)
	draw_rect(outer, Color(0.67, 0.62, 0.52, 0.9), false, 3.0)
	var font: Font = ThemeDB.fallback_font
	var base_font_size: int = ThemeDB.fallback_font_size

	draw_circle(HEADER_CENTER, 26.0, Color(0.88, 0.78, 0.38, 1.0))
	draw_circle(HEADER_CENTER, 26.0, Color(0.1, 0.1, 0.12, 1.0), false, 2.0)
	if vp_icon != null:
		var icon_size := Vector2(78.0, 78.0)
		var icon_rect := Rect2(HEADER_CENTER - icon_size * 0.5, icon_size)
		draw_texture_rect(vp_icon, icon_rect, false, Color(1, 1, 1, 1))
	else:
		draw_string(font, Vector2(31.0, 50.0), "VP", HORIZONTAL_ALIGNMENT_LEFT, -1, max(base_font_size + 1, 14), Color(0.12, 0.12, 0.12, 1.0))

	var steps := maxi(max_points - min_points, 1)
	var threshold_ratio := float(clampi(WIN_THRESHOLD, min_points, max_points) - min_points) / float(steps)
	var threshold_y := lerpf(TRACK_BOTTOM, TRACK_TOP, threshold_ratio)
	var win_zone := Rect2(Vector2(6.0, TRACK_TOP - 8.0), Vector2(TRACKER_SIZE.x - 12.0, threshold_y - TRACK_TOP + 8.0))
	if win_zone.size.y > 0.0:
		draw_rect(win_zone, Color(0.95, 0.77, 0.24, 0.17), true)

	draw_line(Vector2(TRACK_X, TRACK_TOP), Vector2(TRACK_X, TRACK_BOTTOM), Color(0.84, 0.8, 0.72, 0.94), 3.0)
	draw_line(Vector2(8.0, threshold_y), Vector2(TRACKER_SIZE.x - 8.0, threshold_y), Color(0.96, 0.78, 0.26, 0.95), 3.0)

	for i in range(steps + 1):
		var ratio := float(i) / float(steps)
		var y := lerpf(TRACK_BOTTOM, TRACK_TOP, ratio)
		draw_circle(Vector2(TRACK_X, y), 4.0, Color(0.82, 0.79, 0.71, 0.92))
		draw_string(
			font,
			Vector2(TRACK_X + 13.0, y + 6.0),
			str(min_points + i),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			max(base_font_size + 1, 13),
			Color(0.9, 0.88, 0.82, 0.95)
		)

	var visible_players := mini(_player_values.size(), 4)
	for i in range(visible_players):
		var vp_value := clampi(_player_values[i], min_points, max_points)
		var vp_ratio := float(vp_value - min_points) / float(steps)
		var token_base_y := lerpf(TRACK_BOTTOM, TRACK_TOP, vp_ratio)
		var token_offset := TOKEN_OFFSETS[i]
		var token_y := token_base_y + token_offset.y
		var token_x := TRACK_X + token_offset.x
		var token_color: Color = PLAYER_TOKEN_COLORS[i % PLAYER_TOKEN_COLORS.size()]

		draw_circle(Vector2(token_x, token_y), 9.5, token_color)
		draw_circle(Vector2(token_x, token_y), 9.5, Color(0.1, 0.1, 0.12, 1.0), false, 2.0)
