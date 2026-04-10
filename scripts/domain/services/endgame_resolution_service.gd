extends RefCounted
class_name EndgameResolutionService

func init_endgame_intrigue_round_if_any_cards(game_state: Dictionary, callbacks: Dictionary) -> void:
	var players: Array = game_state.get("players", [])
	if typeof(players) != TYPE_ARRAY:
		game_state["endgameIntrigueRound"] = {"status": "done"}
		return
	var intrigues_by_id_raw: Variant = game_state.get("intriguesById", {})
	var intrigues_by_id: Dictionary = intrigues_by_id_raw if typeof(intrigues_by_id_raw) == TYPE_DICTIONARY else {}
	var any_endgame := false
	for p in players:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var ir: Variant = p.get("intrigue", [])
		if typeof(ir) != TYPE_ARRAY:
			continue
		for cid_raw in ir:
			var cid := str(cid_raw)
			var defv: Variant = intrigues_by_id.get(cid, {})
			if typeof(defv) == TYPE_DICTIONARY and str((defv as Dictionary).get("intrigueType", "")).strip_edges().to_lower() == "endgame":
				any_endgame = true
				break
		if any_endgame:
			break
	if not any_endgame:
		game_state["endgameIntrigueRound"] = {"status": "done"}
		return
	var all_ids: Array = []
	for p2 in players:
		if typeof(p2) != TYPE_DICTIONARY:
			continue
		var pid := str(p2.get("id", ""))
		if pid != "":
			all_ids.append(pid)
	var order_from_first: Callable = callbacks.get("order_player_ids_from_first_player", Callable())
	var ordered: Array = order_from_first.call(game_state, all_ids)
	var eid: Array = []
	for x in ordered:
		eid.append(str(x))
	if eid.is_empty():
		game_state["endgameIntrigueRound"] = {"status": "done"}
		return
	game_state["endgameIntrigueRound"] = {
		"status": "open",
		"eligiblePlayerIds": eid,
		"currentIndex": 0,
		"consecutivePasses": 0,
		"currentPlayerId": str(eid[0])
	}
	game_state["currentPlayerId"] = str(eid[0])
	var append_log: Callable = callbacks.get("append_log", Callable())
	append_log.call(game_state, {
		"type": "endgame_intrigue_round_started",
		"eligiblePlayerIds": eid
	})

func finalize_game_if_vp_threshold_reached(game_state: Dictionary, callbacks: Dictionary) -> Dictionary:
	var players: Variant = game_state.get("players", [])
	if typeof(players) != TYPE_ARRAY or (players as Array).is_empty():
		return {"ended": false}
	var threshold_reached := false
	var top_vp := -2147483648
	var top_players: Array[Dictionary] = []
	var top_player_ids: Array[String] = []
	for p in (players as Array):
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var vp := int((p as Dictionary).get("vp", 0))
		if vp >= 10:
			threshold_reached = true
		if vp > top_vp:
			top_vp = vp
			top_players = [p]
			top_player_ids = [str((p as Dictionary).get("id", ""))]
		elif vp == top_vp:
			top_players.append(p)
			top_player_ids.append(str((p as Dictionary).get("id", "")))
	if not threshold_reached:
		return {"ended": false}
	game_state["status"] = "finished"
	var winner_id := ""
	if top_players.size() == 1:
		winner_id = str(top_players[0].get("id", ""))
	elif top_players.size() > 1:
		var compare_players_for_endgame: Callable = callbacks.get("compare_players_for_endgame", Callable())
		var best: Dictionary = top_players[0]
		for i in range(1, top_players.size()):
			var candidate: Dictionary = top_players[i]
			if int(compare_players_for_endgame.call(candidate, best)) > 0:
				best = candidate
		winner_id = str(best.get("id", ""))
	game_state["winnerPlayerId"] = winner_id
	var append_log: Callable = callbacks.get("append_log", Callable())
	append_log.call(game_state, {
		"type": "game_finished",
		"reason": "vp_threshold_reached",
		"threshold": 10,
		"topVp": top_vp,
		"topPlayers": top_player_ids,
		"winnerPlayerId": winner_id
	})
	init_endgame_intrigue_round_if_any_cards(game_state, callbacks)
	return {
		"ended": true,
		"winnerPlayerId": winner_id,
		"topVp": top_vp,
		"topPlayers": top_player_ids
	}
