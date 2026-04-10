extends RefCounted
class_name SpyPostVisualSubsystem

var _draw_spy_posts: Callable
var _load_spy_connections: Callable

func _init(draw_spy_posts: Callable, load_spy_connections: Callable) -> void:
	_draw_spy_posts = draw_spy_posts
	_load_spy_connections = load_spy_connections

func load_connections() -> Dictionary:
	if not _load_spy_connections.is_valid():
		return {}
	var result: Variant = _load_spy_connections.call()
	return result if typeof(result) == TYPE_DICTIONARY else {}

func draw() -> void:
	if _draw_spy_posts.is_valid():
		_draw_spy_posts.call()
