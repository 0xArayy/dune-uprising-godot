extends Node2D
## Visual highlight around Arrakeen, Imperial Basin, and Spice Refinery (control locations).

const SPACE_IDS: Array[String] = ["spice_refinery", "arrakeen", "imperial_basin"]
const PADDING_PX: float = 16.0

@onready var _fill: Polygon2D = $Fill
@onready var _outline: Line2D = $Outline


func _ready() -> void:
	_rebuild_zone()


func _rebuild_zone() -> void:
	var board_spaces := get_parent().get_node_or_null("BoardSpaces")
	if board_spaces == null:
		return
	var corners: PackedVector2Array = []
	for space_id in SPACE_IDS:
		var marker = board_spaces.get_node_or_null(space_id)
		if marker == null:
			continue
		var sz: Vector2 = marker.slot_size
		var hw: float = sz.x * 0.5 + PADDING_PX
		var hh: float = sz.y * 0.5 + PADDING_PX
		var c: Vector2 = marker.position
		corners.append_array(
			[
				Vector2(c.x - hw, c.y - hh),
				Vector2(c.x + hw, c.y - hh),
				Vector2(c.x + hw, c.y + hh),
				Vector2(c.x - hw, c.y + hh),
			]
		)
	if corners.size() < 3:
		return
	var hull: PackedVector2Array = Geometry2D.convex_hull(corners)
	_fill.polygon = hull
	_outline.points = hull
