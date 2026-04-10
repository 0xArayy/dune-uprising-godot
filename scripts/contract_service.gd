extends RefCounted
class_name ContractService

const DEFAULT_CONTRACTS_PATH := "res://data/contracts_choam_minimal.json"
const FACE_UP_CONTRACTS_COUNT := 3

static func load_contracts_by_id(path: String = DEFAULT_CONTRACTS_PATH) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ContractService: failed to open %s" % path)
		return {}
	var text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("ContractService: expected array in %s" % path)
		return {}
	var by_id: Dictionary = {}
	for entry in parsed:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var normalized := _normalize_contract(entry)
		var contract_id := str(normalized.get("id", ""))
		if contract_id == "":
			continue
		if not _is_valid_contract(normalized):
			push_warning("ContractService: invalid contract schema for id=%s" % contract_id)
			continue
		by_id[contract_id] = normalized
	return by_id

static func build_choam_state(contract_ids: Array) -> Dictionary:
	var deck: Array = []
	for contract_id in contract_ids:
		deck.append(str(contract_id))
	var face_up: Array = []
	_refill_face_up(deck, face_up)
	return {
		"choamContractDeck": deck,
		"choamFaceUpContracts": face_up,
		"choamContractsAvailable": deck.size() + face_up.size()
	}

static func resolve_get_contract_effect(
	game_state: Dictionary,
	player_state: Dictionary,
	amount: int,
	fallback_effects: Variant,
	apply_effects_callable: Callable,
	log_callable: Callable = Callable()
) -> Dictionary:
	var desired := maxi(amount, 1)
	var choam_enabled := _is_choam_enabled(game_state)
	var fallback_count := 0
	if not choam_enabled:
		fallback_count = _apply_fallback_effects(desired, fallback_effects, apply_effects_callable)
		_emit_log(log_callable, {
			"type": "contract_fallback_applied",
			"playerId": str(player_state.get("id", "")),
			"reason": "choam_disabled",
			"fallbackCount": fallback_count
		})
		_sync_available_count(game_state)
		return {"granted": 0, "fallbackApplied": fallback_count > 0, "fallbackCount": fallback_count, "reason": "choam_disabled"}

	var granted_contracts: Array = []
	var deck: Array = _get_array(game_state.get("choamContractDeck", []))
	var face_up: Array = _get_array(game_state.get("choamFaceUpContracts", []))
	var owned: Array = _get_array(player_state.get("contractsOwned", []))

	for _i in range(desired):
		if face_up.is_empty():
			_refill_face_up(deck, face_up)
		if face_up.is_empty():
			break
		var contract_id := str(face_up.pop_front())
		if contract_id == "":
			continue
		owned.append(contract_id)
		granted_contracts.append(contract_id)
		_refill_face_up(deck, face_up)

	player_state["contractsOwned"] = owned
	game_state["choamContractDeck"] = deck
	game_state["choamFaceUpContracts"] = face_up
	_sync_available_count(game_state)

	for granted in granted_contracts:
		_emit_log(log_callable, {
			"type": "contract_taken",
			"playerId": str(player_state.get("id", "")),
			"contractId": granted
		})

	var missing := desired - granted_contracts.size()
	if missing > 0:
		fallback_count = _apply_fallback_effects(missing, fallback_effects, apply_effects_callable)
		_emit_log(log_callable, {
			"type": "contract_fallback_applied",
			"playerId": str(player_state.get("id", "")),
			"reason": "no_contracts_available",
			"fallbackCount": fallback_count
		})

	return {
		"granted": granted_contracts.size(),
		"grantedContracts": granted_contracts,
		"fallbackApplied": fallback_count > 0,
		"fallbackCount": fallback_count
	}

static func queue_contract_choice_for_player(
	game_state: Dictionary,
	player_state: Dictionary,
	amount: int,
	fallback_effects: Variant,
	apply_effects_callable: Callable,
	log_callable: Callable = Callable()
) -> Dictionary:
	var desired := maxi(amount, 1)
	if not _is_choam_enabled(game_state):
		var disabled_fallback := _apply_fallback_effects(desired, fallback_effects, apply_effects_callable)
		_emit_log(log_callable, {
			"type": "contract_fallback_applied",
			"playerId": str(player_state.get("id", "")),
			"reason": "choam_disabled",
			"fallbackCount": disabled_fallback
		})
		return {"queued": false, "fallbackCount": disabled_fallback}

	var available_total := int(game_state.get("choamContractsAvailable", 0))
	if available_total <= 0:
		var empty_fallback := _apply_fallback_effects(desired, fallback_effects, apply_effects_callable)
		_emit_log(log_callable, {
			"type": "contract_fallback_applied",
			"playerId": str(player_state.get("id", "")),
			"reason": "no_contracts_available",
			"fallbackCount": empty_fallback
		})
		return {"queued": false, "fallbackCount": empty_fallback}

	var picks := mini(desired, available_total)
	var missing := desired - picks
	var fallback_count := 0
	if missing > 0:
		fallback_count = _apply_fallback_effects(missing, fallback_effects, apply_effects_callable)
		_emit_log(log_callable, {
			"type": "contract_fallback_applied",
			"playerId": str(player_state.get("id", "")),
			"reason": "partial_contract_pool",
			"fallbackCount": fallback_count
		})
	var pending: Dictionary = {
		"picksRemaining": picks,
		"fallbackEffects": _get_array(fallback_effects)
	}
	player_state["pendingContractChoice"] = pending
	return {"queued": picks > 0, "picksQueued": picks, "fallbackCount": fallback_count}

static func resolve_pending_contract_choice(
	game_state: Dictionary,
	player_state: Dictionary,
	contract_id: String,
	log_callable: Callable = Callable()
) -> Dictionary:
	var pending_raw: Variant = player_state.get("pendingContractChoice", {})
	if typeof(pending_raw) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "no_pending_contract_choice"}
	var pending: Dictionary = pending_raw
	var picks_remaining := int(pending.get("picksRemaining", 0))
	if picks_remaining <= 0:
		player_state["pendingContractChoice"] = {}
		return {"ok": false, "reason": "no_pending_contract_choice"}
	var face_up: Array = _get_array(game_state.get("choamFaceUpContracts", []))
	var pick_idx := face_up.find(contract_id)
	if pick_idx < 0:
		return {"ok": false, "reason": "contract_not_face_up"}
	var deck: Array = _get_array(game_state.get("choamContractDeck", []))
	var owned: Array = _get_array(player_state.get("contractsOwned", []))
	var taken := str(face_up[pick_idx])
	face_up.remove_at(pick_idx)
	if taken != "":
		owned.append(taken)
		_emit_log(log_callable, {
			"type": "contract_taken",
			"playerId": str(player_state.get("id", "")),
			"contractId": taken
		})
	_refill_face_up(deck, face_up)
	game_state["choamContractDeck"] = deck
	game_state["choamFaceUpContracts"] = face_up
	player_state["contractsOwned"] = owned
	_sync_available_count(game_state)
	picks_remaining -= 1
	if picks_remaining > 0 and int(game_state.get("choamContractsAvailable", 0)) > 0:
		pending["picksRemaining"] = picks_remaining
		player_state["pendingContractChoice"] = pending
	else:
		player_state["pendingContractChoice"] = {}
	return {"ok": true, "contractId": taken, "remaining": picks_remaining}

static func resolve_mandatory_completions_for_space(
	game_state: Dictionary,
	player_state: Dictionary,
	space_id: String,
	apply_effects_callable: Callable,
	log_callable: Callable = Callable()
) -> Dictionary:
	var owned: Array = _get_array(player_state.get("contractsOwned", []))
	if owned.is_empty():
		return {"completedCount": 0, "completedContractIds": []}
	var contracts_by_id: Dictionary = _get_dict(game_state.get("choamContractsById", {}))
	if contracts_by_id.is_empty():
		return {"completedCount": 0, "completedContractIds": []}

	var completed_ids: Array = []
	var still_owned: Array = []
	for contract_id_raw in owned:
		var contract_id := str(contract_id_raw)
		var contract_def: Dictionary = _get_dict(contracts_by_id.get(contract_id, {}))
		if contract_def.is_empty():
			still_owned.append(contract_id)
			continue
		var trigger: Dictionary = _get_dict(contract_def.get("trigger", {}))
		var trigger_type := str(trigger.get("type", ""))
		var trigger_space_id := str(trigger.get("spaceId", ""))
		if trigger_type == "agent_on_space" and trigger_space_id == space_id:
			var reward_effects: Array = _get_array(contract_def.get("rewardEffects", []))
			if not reward_effects.is_empty():
				apply_effects_callable.call(reward_effects)
			completed_ids.append(contract_id)
			_emit_log(log_callable, {
				"type": "contract_completed",
				"playerId": str(player_state.get("id", "")),
				"contractId": contract_id,
				"spaceId": space_id
			})
			continue
		still_owned.append(contract_id)

	if completed_ids.is_empty():
		return {"completedCount": 0, "completedContractIds": []}

	var completed_list: Array = _get_array(player_state.get("contractsCompleted", []))
	for completed_id in completed_ids:
		completed_list.append(completed_id)
	player_state["contractsOwned"] = still_owned
	player_state["contractsCompleted"] = completed_list
	player_state["completedContracts"] = int(player_state.get("completedContracts", 0)) + completed_ids.size()
	return {"completedCount": completed_ids.size(), "completedContractIds": completed_ids}

static func _normalize_contract(contract: Dictionary) -> Dictionary:
	var normalized: Dictionary = contract.duplicate(true)
	var trigger: Dictionary = _get_dict(normalized.get("trigger", {}))
	var trigger_type := str(trigger.get("type", "")).strip_edges()
	if trigger_type == "":
		trigger_type = "agent_on_space"
	trigger["type"] = trigger_type
	trigger["spaceId"] = str(trigger.get("spaceId", "")).strip_edges()
	normalized["trigger"] = trigger
	var reward_effects: Array = _get_array(normalized.get("rewardEffects", []))
	normalized["rewardEffects"] = reward_effects
	normalized["id"] = str(normalized.get("id", "")).strip_edges()
	normalized["name"] = str(normalized.get("name", normalized.get("id", ""))).strip_edges()
	return normalized

static func _is_valid_contract(contract: Dictionary) -> bool:
	var contract_id := str(contract.get("id", ""))
	if contract_id == "":
		return false
	var trigger: Variant = contract.get("trigger", {})
	if typeof(trigger) != TYPE_DICTIONARY:
		return false
	if str((trigger as Dictionary).get("type", "")) != "agent_on_space":
		return false
	if str((trigger as Dictionary).get("spaceId", "")) == "":
		return false
	var rewards: Variant = contract.get("rewardEffects", [])
	return typeof(rewards) == TYPE_ARRAY

static func _is_choam_enabled(game_state: Dictionary) -> bool:
	var rules_config: Dictionary = _get_dict(game_state.get("rulesConfig", {}))
	if rules_config.is_empty():
		return true
	return bool(rules_config.get("choamEnabled", true))

static func _apply_fallback_effects(
	count: int,
	fallback_effects: Variant,
	apply_effects_callable: Callable
) -> int:
	var fallback: Array = _get_array(fallback_effects)
	if fallback.is_empty():
		fallback = [{"type": "gain_resource", "resource": "solari", "amount": 2}]
	for _i in range(maxi(count, 0)):
		apply_effects_callable.call(fallback)
	return maxi(count, 0)

static func _refill_face_up(deck: Array, face_up: Array) -> void:
	while face_up.size() < FACE_UP_CONTRACTS_COUNT and not deck.is_empty():
		face_up.append(str(deck.pop_back()))

static func _sync_available_count(game_state: Dictionary) -> void:
	var deck: Array = _get_array(game_state.get("choamContractDeck", []))
	var face_up: Array = _get_array(game_state.get("choamFaceUpContracts", []))
	game_state["choamContractsAvailable"] = deck.size() + face_up.size()

static func _emit_log(log_callable: Callable, entry: Dictionary) -> void:
	if log_callable.is_valid():
		log_callable.call(entry)

static func _get_array(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return value
	return []

static func _get_dict(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}
