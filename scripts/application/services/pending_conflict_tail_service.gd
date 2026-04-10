extends RefCounted
class_name PendingConflictTailService

func continue_after_conflict_pending_resolution(game_state: Dictionary, board_map: Node, callbacks: Dictionary) -> Dictionary:
	var has_pending_conflict_reward_choice: Callable = callbacks.get("has_pending_conflict_reward_choice", Callable())
	if bool(has_pending_conflict_reward_choice.call(game_state)):
		var set_current_player_from_pending_conflict_choice: Callable = callbacks.get("set_current_player_from_pending_conflict_choice", Callable())
		set_current_player_from_pending_conflict_choice.call(game_state)
		var bump_state_version: Callable = callbacks.get("bump_state_version", Callable())
		bump_state_version.call(game_state)
		return {"ok": true, "awaitingInteraction": true}

	var pending_contract_player_id := find_player_id_with_pending_contract_choice(game_state)
	if pending_contract_player_id != "":
		game_state["currentPlayerId"] = pending_contract_player_id
		var bump_state_version_contract: Callable = callbacks.get("bump_state_version", Callable())
		bump_state_version_contract.call(game_state)
		return {"ok": true, "awaitingInteraction": true}

	var pending_place_spy_id := find_first_player_id_with_pending_place_spy(game_state)
	if pending_place_spy_id != "":
		game_state["currentPlayerId"] = pending_place_spy_id
		var find_player_by_id: Callable = callbacks.get("find_player_by_id", Callable())
		var psp: Variant = find_player_by_id.call(game_state, pending_place_spy_id)
		if typeof(psp) == TYPE_DICTIONARY:
			var sync_pending_interactions: Callable = callbacks.get("sync_pending_interactions", Callable())
			sync_pending_interactions.call(psp)
		var bump_state_version_spy: Callable = callbacks.get("bump_state_version", Callable())
		bump_state_version_spy.call(game_state)
		return {"ok": true, "awaitingInteraction": true}

	var pending_spy_recall_player_id := find_player_id_with_pending_spy_recall_draw(game_state)
	if pending_spy_recall_player_id != "":
		game_state["currentPlayerId"] = pending_spy_recall_player_id
		var bump_state_version_recall: Callable = callbacks.get("bump_state_version", Callable())
		bump_state_version_recall.call(game_state)
		return {"ok": true, "awaitingInteraction": true}

	var phase_to_makers: Callable = callbacks.get("phase_to_makers", Callable())
	phase_to_makers.call(game_state)
	var append_log: Callable = callbacks.get("append_log", Callable())
	append_log.call(game_state, {"type": "phase_changed", "phase": "makers"})

	var run_maker_phase: Callable = callbacks.get("run_maker_phase", Callable())
	var makers: Dictionary = run_maker_phase.call(game_state, board_map)
	if not bool(makers.get("ok", false)):
		return {"ok": false, "reason": "makers_failed", "detail": makers}

	var run_recall_phase: Callable = callbacks.get("run_recall_phase", Callable())
	var recall: Dictionary = run_recall_phase.call(game_state)
	if not bool(recall.get("ok", false)):
		return {"ok": false, "reason": "recall_failed", "detail": recall}

	var start_round: Callable = callbacks.get("start_round", Callable())
	var start: Dictionary = start_round.call(game_state)
	return {"ok": bool(start.get("ok", false)), "awaitingInteraction": false, "startRound": start}

func find_player_id_with_pending_spy_recall_draw(game_state: Dictionary) -> String:
	var players: Variant = game_state.get("players", [])
	if typeof(players) != TYPE_ARRAY:
		return ""
	for entry in players:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var player: Dictionary = entry
		if int(player.get("pendingSpyRecallDrawCards", 0)) > 0:
			return str(player.get("id", ""))
	return ""

func find_player_id_with_pending_contract_choice(game_state: Dictionary) -> String:
	var players: Variant = game_state.get("players", [])
	if typeof(players) != TYPE_ARRAY:
		return ""
	for entry in players:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var player: Dictionary = entry
		var pending_raw: Variant = player.get("pendingContractChoice", {})
		if typeof(pending_raw) != TYPE_DICTIONARY:
			continue
		if not (pending_raw as Dictionary).is_empty():
			return str(player.get("id", ""))
	return ""

func find_first_player_id_with_pending_place_spy(game_state: Dictionary) -> String:
	var players: Variant = game_state.get("players", [])
	if typeof(players) != TYPE_ARRAY:
		return ""
	for entry in players:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var p: Dictionary = entry
		if int(p.get("pendingPlaceSpy", 0)) > 0:
			return str(p.get("id", ""))
	return ""
