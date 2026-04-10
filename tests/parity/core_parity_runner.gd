extends RefCounted
class_name CoreParityRunner

func compare_pipeline_results(
	legacy_controller: TurnController,
	coordinator: GameCoordinator,
	base_state: Dictionary,
	board_map: Node
) -> Dictionary:
	if legacy_controller == null or coordinator == null:
		return {"ok": false, "reason": "missing_dependencies"}

	var legacy_state: Dictionary = base_state.duplicate(true)
	var refactored_state: Dictionary = base_state.duplicate(true)

	var legacy_result: Dictionary = legacy_controller.finish_round_pipeline(legacy_state, board_map)
	var refactored_result: Dictionary = coordinator.finish_round(refactored_state, board_map)

	var legacy_ok := bool(legacy_result.get("ok", false))
	var refactored_ok := bool(refactored_result.get("ok", false))
	if legacy_ok != refactored_ok:
		return {
			"ok": false,
			"reason": "pipeline_ok_mismatch",
			"legacy": legacy_result,
			"refactored": refactored_result
		}
	return {"ok": true}
