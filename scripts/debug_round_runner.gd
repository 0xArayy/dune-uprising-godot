extends Node

const IntrigueCardsDbScript = preload("res://scripts/intrigue_cards_db.gd")

# Runs isolated MVP tests with explicit checks.
func run(game_state, controller, board_map):
	var snapshot: Dictionary = game_state.duplicate(true)
	var conflict_test_id := _pick_conflict_test_id(game_state)
	if conflict_test_id == "":
		push_error("DebugRoundRunner: no level II conflict card found for debug tests")
		return

	# Conflict resolution tests do not need board interactions.
	# Test 1: non-tie (p1 power > p2 power) -> 1st/2nd reward split.
	var zone_1 = {
		"p1": { "troops": 2, "revealedSwordPower": 0 }, # power = 4
		"p2": { "troops": 1, "revealedSwordPower": 0 }  # power = 2
	}
	_run_conflict_test_2p(game_state, controller, conflict_test_id, zone_1, false)

	# Test 2: tie (equal power) -> both take 2nd reward.
	var zone_2 = {
		"p1": { "troops": 1, "revealedSwordPower": 0 }, # power = 2
		"p2": { "troops": 1, "revealedSwordPower": 0 }  # power = 2
	}
	_run_conflict_test_2p(game_state, controller, conflict_test_id, zone_2, true)
	_run_round_order_test(game_state, controller, board_map)
	_run_choam_tests(game_state, controller, board_map)
	_run_pending_trash_tests(game_state, controller)
	_restore_state(game_state, snapshot)
	print("DebugRoundRunner: all debug scenarios finished")

func _run_conflict_test_2p(game_state, controller, conflict_card_id, zone_by_player, is_tie):
	var defs = game_state.get("conflictCardsById", {})
	if typeof(defs) != TYPE_DICTIONARY or not defs.has(conflict_card_id):
		push_error("DebugRoundRunner: missing conflict card def: " + str(conflict_card_id))
		return

	# Reset per-player rewards/state for a clean test.
	for p in game_state.get("players", []):
		p["resources"]["solari"] = 0
		p["vp"] = 0
		p["revealedSwordPower"] = 0
		p["garrisonTroops"] = 0

	game_state["conflictZone"] = {}
	for p in game_state.get("players", []):
		var pid = str(p.get("id", ""))
		var zone = zone_by_player.get(pid, {})
		var troops = int(zone.get("troops", 0))
		var revealed_sword_power = int(zone.get("revealedSwordPower", 0))
		p["garrisonTroops"] = troops
		game_state["conflictZone"][pid] = {
			"troops": troops,
			"revealedSwordPower": revealed_sword_power,
			"totalPower": 0
		}

	# Force conflict phase and set the active conflict card for rewards.
	game_state["phase"] = "conflict"
	game_state["activeConflictCardId"] = conflict_card_id
	game_state["activeConflictCardDef"] = defs[conflict_card_id]
	game_state["combatIntrigueRound"] = {"status": "done"}

	var result = controller.resolve_conflict_stub(game_state)
	_expect(bool(result.get("ok", false)), "conflict resolve returned ok")
	_expect(str(game_state.get("phase", "")) == "makers", "phase switched to makers after conflict")
	_expect(typeof(game_state.get("conflictZone", null)) == TYPE_DICTIONARY and game_state["conflictZone"].is_empty(), "conflict zone cleared after conflict")

	var test_label = "non-tie"
	if is_tie:
		test_label = "tie"
	print("MVP conflict test (" + test_label + "): ", result)
	print("After resolve: conflictZone = ", game_state.get("conflictZone", {}))

	# Sanity checks for reward relationships.
	var vp_values: Array = []
	var solari_values: Array = []
	for p in game_state.get("players", []):
		print("  player ", p.get("id", ""), " solari=", p["resources"].get("solari", 0), " vp=", p.get("vp", 0))
		vp_values.append(int(p.get("vp", 0)))
		solari_values.append(int(p.get("resources", {}).get("solari", 0)))

	if vp_values.size() >= 2:
		if is_tie:
			_expect(vp_values[0] == vp_values[1], "tie test keeps VP rewards equal")
			_expect(solari_values[0] == solari_values[1], "tie test keeps solari rewards equal")
		else:
			_expect(vp_values[0] >= vp_values[1], "non-tie test keeps p1 reward not lower than p2")
			_expect(solari_values[0] >= solari_values[1], "non-tie test keeps p1 solari not lower than p2")

func _run_round_order_test(game_state, controller, board_map) -> void:
	var first_before := str(game_state.get("firstPlayerId", ""))
	game_state["phase"] = "player_turns"
	for p in game_state.get("players", []):
		p["passedReveal"] = true
	var end_turns = controller.end_player_turns_phase(game_state, board_map)
	_expect(bool(end_turns.get("ok", false)), "player_turns phase can end")
	_expect(str(game_state.get("phase", "")) == "conflict", "phase switched to conflict")

	game_state["combatIntrigueRound"] = {"status": "done"}
	var conflict = controller.resolve_conflict_stub(game_state)
	_expect(bool(conflict.get("ok", false)), "conflict step can resolve")
	_expect(str(game_state.get("phase", "")) == "makers", "phase switched to makers")

	var makers = controller.run_maker_phase(game_state, board_map)
	_expect(bool(makers.get("ok", false)), "makers step can resolve")
	_expect(str(game_state.get("phase", "")) == "recall", "phase switched to recall")

	var recall = controller.run_recall_phase(game_state)
	_expect(bool(recall.get("ok", false)), "recall step can resolve")
	var first_after := str(game_state.get("firstPlayerId", ""))
	_expect(first_after != "" and first_after != first_before, "first player marker rotates in recall")

	print("MVP step pipeline: ", {
		"end_player_turns_phase": end_turns,
		"resolve_conflict_stub": conflict,
		"run_maker_phase": makers,
		"run_recall_phase": recall
	})
	print("First player before/after: ", first_before, " -> ", first_after)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("DebugRoundRunner PASS: ", message)
		return
	push_error("DebugRoundRunner FAIL: " + message)

func _restore_state(target: Dictionary, source: Dictionary) -> void:
	target.clear()
	for key in source.keys():
		target[key] = source[key]

func _pick_conflict_test_id(game_state: Dictionary) -> String:
	var defs = game_state.get("conflictCardsById", {})
	if typeof(defs) != TYPE_DICTIONARY:
		return ""
	var ids: Array = defs.keys()
	ids.sort()
	for card_id in ids:
		var card = defs[card_id]
		if typeof(card) != TYPE_DICTIONARY:
			continue
		if str(card.get("level", "")) == "II":
			return str(card_id)
	return ""

func _run_choam_tests(game_state: Dictionary, controller, board_map) -> void:
	var players: Variant = game_state.get("players", [])
	if typeof(players) != TYPE_ARRAY or players.is_empty():
		push_error("DebugRoundRunner: no players for CHOAM tests")
		return
	var player: Dictionary = players[0]
	var rules_config: Variant = game_state.get("rulesConfig", {})
	if typeof(rules_config) != TYPE_DICTIONARY:
		rules_config = {}

	player["resources"] = {"solari": 0, "spice": 0, "water": 0}
	player["contractsOwned"] = []
	player["contractsCompleted"] = []
	player["completedContracts"] = 0
	game_state["choamContractDeck"] = []
	game_state["choamFaceUpContracts"] = []
	game_state["choamContractsAvailable"] = 0

	# CHOAM off => contract icon fallback grants 2 Solari.
	rules_config["choamEnabled"] = false
	game_state["rulesConfig"] = rules_config
	board_map.resolve_space_effects([{"type": "get_contract", "amount": 1}], player, game_state, {"context": "debug_choam"})
	_expect(int(player.get("resources", {}).get("solari", 0)) == 2, "CHOAM disabled fallback grants 2 Solari")

	# CHOAM on => take face-up contract.
	rules_config["choamEnabled"] = true
	game_state["rulesConfig"] = rules_config
	player["resources"] = {"solari": 0, "spice": 0, "water": 0}
	player["contractsOwned"] = []
	player["pendingContractChoice"] = {}
	game_state["choamFaceUpContracts"] = ["choam_arrakeen_supply", "choam_spice_refinery_output"]
	game_state["choamContractDeck"] = ["choam_guild_logistics"]
	game_state["choamContractsAvailable"] = 3
	board_map.resolve_space_effects([{"type": "get_contract", "amount": 1}], player, game_state, {"context": "debug_choam"})
	_expect(int((player.get("contractsOwned", []) as Array).size()) == 1, "CHOAM enabled grants one contract")

	# Reveal context => opens pending choice.
	player["contractsOwned"] = []
	player["pendingContractChoice"] = {}
	game_state["choamFaceUpContracts"] = ["choam_arrakeen_supply", "choam_spice_refinery_output"]
	game_state["choamContractDeck"] = ["choam_guild_logistics"]
	game_state["choamContractsAvailable"] = 3
	board_map.resolve_space_effects([{"type": "get_contract", "amount": 1}], player, game_state, {"context": "reveal"})
	var reveal_pending: Dictionary = player.get("pendingContractChoice", {})
	_expect(int(reveal_pending.get("picksRemaining", 0)) == 1, "reveal get_contract queues pending contract choice")

	# Purchase context => opens pending choice.
	player["pendingContractChoice"] = {}
	board_map.resolve_space_effects([{"type": "get_contract", "amount": 1}], player, game_state, {"context": "purchase"})
	var purchase_pending: Dictionary = player.get("pendingContractChoice", {})
	_expect(int(purchase_pending.get("picksRemaining", 0)) == 1, "purchase get_contract queues pending contract choice")

	# Queued context with CHOAM off => fallback still applies, no pending.
	player["resources"] = {"solari": 0, "spice": 0, "water": 0}
	player["pendingContractChoice"] = {}
	rules_config["choamEnabled"] = false
	game_state["rulesConfig"] = rules_config
	board_map.resolve_space_effects([{"type": "get_contract", "amount": 1}], player, game_state, {"context": "reveal"})
	_expect(int(player.get("resources", {}).get("solari", 0)) == 2, "queued reveal fallback grants 2 Solari when CHOAM disabled")
	_expect((player.get("pendingContractChoice", {}) as Dictionary).is_empty(), "queued reveal does not leave pending when CHOAM disabled")
	rules_config["choamEnabled"] = true
	game_state["rulesConfig"] = rules_config

	# Conflict reward get_contract => queues pending and keeps conflict phase.
	var players_for_conflict: Variant = game_state.get("players", [])
	if typeof(players_for_conflict) == TYPE_ARRAY and not players_for_conflict.is_empty():
		var p0: Dictionary = players_for_conflict[0]
		var p0_id := str(p0.get("id", ""))
		p0["pendingContractChoice"] = {}
		p0["contractsOwned"] = []
		p0["garrisonTroops"] = 1
		game_state["choamFaceUpContracts"] = ["choam_arrakeen_supply", "choam_spice_refinery_output"]
		game_state["choamContractDeck"] = ["choam_guild_logistics"]
		game_state["choamContractsAvailable"] = 3
		game_state["phase"] = "conflict"
		game_state["activeConflictCardDef"] = {"firstReward": [{"type": "get_contract", "amount": 1}], "secondReward": [], "thirdReward": []}
		game_state["conflictZone"] = {p0_id: {"troops": 1, "revealedSwordPower": 0, "totalPower": 0}}
		game_state["combatIntrigueRound"] = {"status": "done"}
		var conflict_result: Dictionary = controller.resolve_conflict_stub(game_state)
		_expect(bool(conflict_result.get("awaitingInteraction", false)), "conflict get_contract waits for pending contract choice")
		_expect(str(game_state.get("phase", "")) == "conflict", "conflict phase remains active while contract choice is pending")
		_expect(int((p0.get("pendingContractChoice", {}) as Dictionary).get("picksRemaining", 0)) == 1, "conflict reward queues pending contract choice")

	# Mandatory + multi-completion on the same placement.
	player["contractsOwned"] = ["choam_arrakeen_supply", "choam_arrakeen_supply"]
	player["contractsCompleted"] = []
	player["completedContracts"] = 0
	player["resources"] = {"solari": 0, "spice": 0, "water": 0}
	var completion_result: Dictionary = board_map.resolve_contract_completions_for_space(player, game_state, "arrakeen")
	_expect(int(completion_result.get("completedCount", 0)) == 2, "multiple contracts complete from one placement")
	_expect(int(player.get("completedContracts", 0)) == 2, "completedContracts counter increments after completion")
	_expect(int(player.get("resources", {}).get("solari", 0)) == 4, "completed contracts apply rewards mandatorily")

	# Card integration: Cargo Runner scales with completedContracts thresholds.
	var cards_by_id_raw: Variant = game_state.get("cardsById", {})
	var cards_by_id: Dictionary = cards_by_id_raw if typeof(cards_by_id_raw) == TYPE_DICTIONARY else {}
	var cargo_raw: Variant = cards_by_id.get("imperium_cargo_runner", {})
	if typeof(cargo_raw) == TYPE_DICTIONARY:
		var cargo: Dictionary = cargo_raw
		var cargo_agent_effects: Variant = cargo.get("agentEffect", [])
		if typeof(cargo_agent_effects) == TYPE_ARRAY:
			player["pendingDrawCards"] = 0
			player["completedContracts"] = 1
			board_map.resolve_space_effects(cargo_agent_effects, player, game_state, {"context": "debug_cargo_runner"})
			_expect(int(player.get("pendingDrawCards", 0)) == 0, "Cargo Runner draws 0 cards below completed contract threshold")

			player["pendingDrawCards"] = 0
			player["completedContracts"] = 2
			board_map.resolve_space_effects(cargo_agent_effects, player, game_state, {"context": "debug_cargo_runner"})
			_expect(int(player.get("pendingDrawCards", 0)) == 1, "Cargo Runner draws 1 card at completedContracts >= 2")

			player["pendingDrawCards"] = 0
			player["completedContracts"] = 4
			board_map.resolve_space_effects(cargo_agent_effects, player, game_state, {"context": "debug_cargo_runner"})
			_expect(int(player.get("pendingDrawCards", 0)) == 2, "Cargo Runner draws 2 cards at completedContracts >= 4")

func _run_pending_trash_tests(game_state: Dictionary, controller) -> void:
	var players: Variant = game_state.get("players", [])
	if typeof(players) != TYPE_ARRAY or players.is_empty():
		push_error("DebugRoundRunner: no players for pending trash tests")
		return
	var player: Dictionary = players[0]
	var player_id := str(player.get("id", ""))
	game_state["phase"] = "player_turns"
	game_state["currentPlayerId"] = player_id
	player["pendingTrash"] = 0
	player["pendingTrashQueue"] = []
	player["hand"] = ["imperium_cargo_runner"]
	player["discard"] = ["imperium_spacing_guild_s_favor"]
	player["inPlay"] = ["imperium_sardaukar_soldier"]
	player["resources"] = {"solari": 0, "spice": 0, "water": 0}
	player["pendingDrawIntrigue"] = 0
	player["intrigue"] = []
	game_state["intriguesById"] = IntrigueCardsDbScript.load_intrigue_cards_by_id()
	game_state["intrigueDeck"] = ["intrigue_plot_desert_alliance"]
	game_state["intrigueDiscard"] = []

	# Queue one trash with all zones allowed.
	player["pendingTrash"] = 1
	player["pendingTrashQueue"] = [{"remaining": 1, "allowedZones": ["hand", "discard", "inPlay"]}]
	var invalid_zone_result: Dictionary = controller.resolve_pending_trash(game_state, "deck", "imperium_cargo_runner")
	_expect(not bool(invalid_zone_result.get("ok", false)), "pending trash rejects invalid zone key")
	var in_play_ok: Dictionary = controller.resolve_pending_trash(game_state, "inPlay", "imperium_sardaukar_soldier")
	_expect(bool(in_play_ok.get("ok", false)), "pending trash supports inPlay zone")
	var intr_after: Variant = player.get("intrigue", [])
	var intr_arr: Array = intr_after if typeof(intr_after) == TYPE_ARRAY else []
	_expect(
		intr_arr.size() == 1 and str(intr_arr[0]) == "intrigue_plot_desert_alliance",
		"Sardaukar on-trash resolves draw_intrigue into intrigue hand"
	)

	# Queue progression for multi-trash amounts.
	player["pendingTrash"] = 2
	player["pendingTrashQueue"] = [{"remaining": 2, "allowedZones": ["hand", "discard", "inPlay"]}]
	var first_ok: Dictionary = controller.resolve_pending_trash(game_state, "hand", "imperium_cargo_runner")
	_expect(bool(first_ok.get("ok", false)), "first trash resolves from hand")
	var queue_after_first_raw: Variant = player.get("pendingTrashQueue", [])
	var queue_after_first: Array = queue_after_first_raw if typeof(queue_after_first_raw) == TYPE_ARRAY else []
	var head_remaining := int((queue_after_first[0] as Dictionary).get("remaining", 0)) if not queue_after_first.is_empty() and typeof(queue_after_first[0]) == TYPE_DICTIONARY else -1
	_expect(head_remaining == 1 and int(player.get("pendingTrash", 0)) == 1, "pending trash queue decrements after first resolve")
	var second_ok: Dictionary = controller.resolve_pending_trash(game_state, "discard", "imperium_spacing_guild_s_favor")
	_expect(bool(second_ok.get("ok", false)), "second trash resolves from discard")
	_expect(int(player.get("pendingTrash", 0)) == 0, "pending trash counter reaches zero")
	_expect((player.get("pendingTrashQueue", []) as Array).is_empty(), "pending trash queue clears at completion")
