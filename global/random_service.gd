extends Node

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func seed_from_value(seed_value: int) -> void:
	_rng.seed = seed_value

func shuffle(values: Array) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j = _rng.randi_range(0, i)
		var tmp = values[i]
		values[i] = values[j]
		values[j] = tmp
