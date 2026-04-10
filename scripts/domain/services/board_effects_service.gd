extends RefCounted
class_name BoardEffectsService

func resolve_space_effects(
	normalized_effects: Array,
	player_state: Dictionary,
	game_state: Dictionary,
	context: Dictionary,
	choice_option_is_choosable: Callable,
	is_requirement_met: Callable,
	apply_single_effect: Callable,
	contains_effect_type: Callable,
	update_shield_wall_visuals: Callable
) -> Dictionary:
	var pending: Array = normalized_effects.duplicate(true)
	var resolved: Array = []
	var choice_indexes: Dictionary = context.get("choice_indexes", {})
	var choice_slot := 0
	while pending.size() > 0:
		var effect: Variant = pending.pop_front()
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		var effect_dict: Dictionary = effect
		var effect_type := str(effect_dict.get("type", ""))
		if effect_type == "choice":
			var options: Variant = effect_dict.get("options", [])
			if typeof(options) != TYPE_ARRAY or (options as Array).is_empty():
				continue
			var executable_indices: Array[int] = []
			for opt_idx in range((options as Array).size()):
				var option: Variant = (options as Array)[opt_idx]
				if typeof(option) != TYPE_DICTIONARY:
					continue
				if bool(choice_option_is_choosable.call(option, player_state, game_state)):
					executable_indices.append(opt_idx)
			if executable_indices.is_empty():
				choice_slot += 1
				continue
			var choice_idx := int(choice_indexes.get(str(choice_slot), executable_indices[0]))
			choice_slot += 1
			if choice_idx < 0 or choice_idx >= (options as Array).size() or not executable_indices.has(choice_idx):
				choice_idx = executable_indices[0]
			var selected: Dictionary = (options as Array)[choice_idx]
			var selected_effects: Variant = selected.get("effects", [])
			if typeof(selected_effects) == TYPE_ARRAY and bool(contains_effect_type.call(selected_effects, "remove_shield_wall")):
				game_state["shieldWallIntact"] = false
				update_shield_wall_visuals.call(game_state)
			if typeof(selected_effects) == TYPE_ARRAY:
				for i in range((selected_effects as Array).size() - 1, -1, -1):
					pending.push_front((selected_effects as Array)[i])
			resolved.append({"type": "choice", "selected": choice_idx})
			continue
		if effect_type == "if":
			var requirement: Variant = effect_dict.get("requirement", {})
			var then_effects: Variant = effect_dict.get("then", [])
			var else_effects: Variant = effect_dict.get("else", [])
			var met := bool(is_requirement_met.call(requirement, player_state, context, game_state))
			var branch: Variant = then_effects if met else else_effects
			if typeof(branch) == TYPE_ARRAY:
				for i in range((branch as Array).size() - 1, -1, -1):
					pending.push_front((branch as Array)[i])
			resolved.append({"type": "if", "met": met})
			continue
		apply_single_effect.call(effect_dict, player_state, game_state, context)
		resolved.append(effect_dict)
	return {
		"ok": true,
		"resolvedEffects": resolved,
		"playerState": player_state,
		"gameState": game_state
	}
