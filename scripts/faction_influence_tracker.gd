extends Node2D
class_name FactionInfluenceTracker

@export var faction_id: String = "emperor"
@export var min_influence: int = 0
@export var max_influence: int = 6

var _player_values: Array[int] = [0, 0]

const TRACKER_SIZE := Vector2(62, 188)
const HEADER_CENTER := Vector2(31, 22)
const TRACK_X := 31.0
const TRACK_TOP := 46.0
const TRACK_BOTTOM := 168.0
const PLAYER_TOKEN_COLORS: Array[Color] = [
	Color(0.95, 0.78, 0.33, 1.0),
	Color(0.44, 0.74, 0.97, 1.0),
	Color(0.85, 0.48, 0.86, 1.0),
	Color(0.58, 0.9, 0.57, 1.0)
]
const TOKEN_OFFSETS: Array[Vector2] = [
	Vector2(-10.0, -4.0),
	Vector2(10.0, -4.0),
	Vector2(-10.0, 4.0),
	Vector2(10.0, 4.0)
]

func set_player_values(values: Array) -> void:
	_player_values.clear()
	for value in values:
		_player_values.append(int(value))
	queue_redraw()

func _draw() -> void:
	var outer := Rect2(Vector2.ZERO, TRACKER_SIZE)
	draw_rect(outer, Color(0.07, 0.07, 0.09, 0.74), true)
	draw_rect(outer, Color(0.62, 0.58, 0.5, 0.86), false, 2.0)

	var faction_color := _get_faction_color(faction_id)
	draw_circle(HEADER_CENTER, 16.0, faction_color)
	draw_circle(HEADER_CENTER, 16.0, Color(0.08, 0.08, 0.1, 1.0), false, 2.0)

	draw_line(Vector2(TRACK_X, TRACK_TOP), Vector2(TRACK_X, TRACK_BOTTOM), Color(0.8, 0.76, 0.68, 0.92), 2.0)

	var steps := maxi(max_influence - min_influence, 1)
	for i in range(steps + 1):
		var ratio := float(i) / float(steps)
		var y := lerpf(TRACK_BOTTOM, TRACK_TOP, ratio)
		draw_circle(Vector2(TRACK_X, y), 3.0, Color(0.82, 0.79, 0.71, 0.9))

	var visible_players := mini(_player_values.size(), 4)
	for i in range(visible_players):
		var influence_value := clampi(_player_values[i], min_influence, max_influence)
		var influence_ratio := float(influence_value - min_influence) / float(steps)
		var token_base_y := lerpf(TRACK_BOTTOM, TRACK_TOP, influence_ratio)
		var token_offset := TOKEN_OFFSETS[i]
		var token_y := token_base_y + token_offset.y
		var token_x := TRACK_X + token_offset.x
		var token_color: Color = PLAYER_TOKEN_COLORS[i % PLAYER_TOKEN_COLORS.size()]

		draw_circle(Vector2(token_x, token_y), 6.5, token_color)
		draw_circle(Vector2(token_x, token_y), 6.5, Color(0.1, 0.1, 0.12, 1.0), false, 1.5)

func _get_faction_color(id: String) -> Color:
	match id:
		"emperor":
			return Color(0.58, 0.6, 0.64, 1.0)
		"guild":
			return Color(0.76, 0.38, 0.34, 1.0)
		"beneGesserit":
			return Color(0.7, 0.48, 0.8, 1.0)
		"fremen":
			return Color(0.48, 0.71, 0.88, 1.0)
		_:
			return Color(0.72, 0.67, 0.58, 1.0)
