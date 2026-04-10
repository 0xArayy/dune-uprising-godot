extends RefCounted
class_name EffectPipeline

const EffectDslScript = preload("res://scripts/domain/effect_dsl.gd")

func validate(raw_effects: Variant) -> Dictionary:
	if typeof(raw_effects) != TYPE_ARRAY:
		return {"ok": false, "reason": "effects_not_array"}
	return {"ok": true}

func normalize(raw_effects: Variant) -> Array:
	return EffectDslScript.normalize_effects_with_aliases(raw_effects)

func run(
	raw_effects: Variant,
	executor: Callable,
	player_state: Dictionary,
	game_state: Dictionary,
	context: Dictionary
) -> Dictionary:
	var shape: Dictionary = validate(raw_effects)
	if not bool(shape.get("ok", false)):
		return shape
	var normalized: Array = normalize(raw_effects)
	return executor.call(normalized, player_state, game_state, context)
