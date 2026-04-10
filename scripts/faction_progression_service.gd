extends RefCounted
class_name FactionProgressionService

const MAX_INFLUENCE := 6
const ALLIANCE_THRESHOLD := 4
const VP_THRESHOLD := 2
const SUPPORTED_FACTIONS := ["emperor", "guild", "beneGesserit", "fremen"]

func apply_influence_delta(game_state: Dictionary, player_state: Dictionary, faction: String, delta: int) -> Dictionary:
	if typeof(game_state) != TYPE_DICTIONARY or typeof(player_state) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "invalid_state"}
	if faction == "" or not SUPPORTED_FACTIONS.has(faction):
		return {"ok": false, "reason": "invalid_faction"}

	var influence: Dictionary = {}
	var raw_influence: Variant = player_state.get("influence", {})
	if typeof(raw_influence) == TYPE_DICTIONARY:
		influence = raw_influence

	var old_value := int(influence.get(faction, 0))
	var new_value := clampi(old_value + delta, 0, MAX_INFLUENCE)
	influence[faction] = new_value
	player_state["influence"] = influence

	var milestones_claimed: Dictionary = {}
	var raw_milestones_claimed: Variant = player_state.get("influenceVpClaimed", {})
	if typeof(raw_milestones_claimed) == TYPE_DICTIONARY:
		milestones_claimed = raw_milestones_claimed

	var awarded_vp := 0
	if old_value < VP_THRESHOLD and new_value >= VP_THRESHOLD and not bool(milestones_claimed.get(faction, false)):
		player_state["vp"] = int(player_state.get("vp", 0)) + 1
		milestones_claimed[faction] = true
		awarded_vp = 1
	player_state["influenceVpClaimed"] = milestones_claimed

	var alliance_result := _resolve_alliance(game_state, player_state, faction, old_value, new_value)
	return {
		"ok": true,
		"oldInfluence": old_value,
		"newInfluence": new_value,
		"awardedVp": awarded_vp,
		"allianceChanged": bool(alliance_result.get("changed", false)),
		"allianceOwner": str(alliance_result.get("owner", "")),
		"allianceBonusApplied": bool(alliance_result.get("bonusApplied", false))
	}

func _resolve_alliance(game_state: Dictionary, player_state: Dictionary, faction: String, _old_value: int, new_value: int) -> Dictionary:
	_ensure_alliance_maps(game_state)
	var player_id := str(player_state.get("id", ""))
	if player_id == "":
		return {"changed": false, "owner": "", "bonusApplied": false}

	var current_owner := _get_alliance_owner(game_state, faction)
	var resolved_owner := _determine_alliance_owner(game_state, faction, current_owner)
	if resolved_owner == current_owner:
		return {"changed": false, "owner": current_owner, "bonusApplied": false}

	_set_alliance_owner(game_state, faction, resolved_owner)
	var bonus_applied := false
	if resolved_owner == player_id and new_value >= ALLIANCE_THRESHOLD:
		_apply_alliance_bonus(player_state, faction)
		bonus_applied = true
	return {"changed": true, "owner": resolved_owner, "bonusApplied": bonus_applied}

func _determine_alliance_owner(game_state: Dictionary, faction: String, current_owner: String) -> String:
	var players := _get_players(game_state)
	if players.is_empty():
		return ""

	var highest_influence := -1
	var contenders: Array[String] = []
	for player in players:
		var influence_map := _get_player_influence_map(player)
		var value := int(influence_map.get(faction, 0))
		if value < ALLIANCE_THRESHOLD:
			continue
		if value > highest_influence:
			highest_influence = value
			contenders = [str(player.get("id", ""))]
		elif value == highest_influence:
			contenders.append(str(player.get("id", "")))

	if contenders.is_empty():
		return ""
	if contenders.size() == 1:
		return contenders[0]
	if current_owner != "" and contenders.has(current_owner):
		return current_owner
	return ""

func _get_alliance_owner(game_state: Dictionary, faction: String) -> String:
	var alliances: Dictionary = {}
	var raw_alliances: Variant = game_state.get("factionAlliances", {})
	if typeof(raw_alliances) == TYPE_DICTIONARY:
		alliances = raw_alliances
	return str(alliances.get(faction, ""))

func _apply_alliance_bonus(player_state: Dictionary, faction: String) -> void:
	match faction:
		"fremen":
			_change_resource(player_state, "water", 1)
		"beneGesserit":
			player_state["pendingDrawIntrigue"] = int(player_state.get("pendingDrawIntrigue", 0)) + 1
		"guild":
			_change_resource(player_state, "solari", 3)
		"emperor":
			player_state["pendingPlaceSpy"] = int(player_state.get("pendingPlaceSpy", 0)) + 1

func _set_alliance_owner(game_state: Dictionary, faction: String, new_owner_id: String) -> void:
	var alliances: Dictionary = {}
	var raw_alliances: Variant = game_state.get("factionAlliances", {})
	if typeof(raw_alliances) == TYPE_DICTIONARY:
		alliances = raw_alliances
	alliances[faction] = new_owner_id
	game_state["factionAlliances"] = alliances

	var players: Array = []
	var raw_players: Variant = game_state.get("players", [])
	if typeof(raw_players) == TYPE_ARRAY:
		players = raw_players
	if typeof(players) != TYPE_ARRAY:
		return
	for player in players:
		if typeof(player) != TYPE_DICTIONARY:
			continue
		var pid := str(player.get("id", ""))
		var player_alliances: Dictionary = {}
		var raw_player_alliances: Variant = player.get("alliances", {})
		if typeof(raw_player_alliances) == TYPE_DICTIONARY:
			player_alliances = raw_player_alliances
		player_alliances[faction] = pid == new_owner_id
		player["alliances"] = player_alliances
	_sync_alliance_vp_bonus(players)

func _find_player_by_id(game_state: Dictionary, player_id: String) -> Dictionary:
	var players := _get_players(game_state)
	for player in players:
		if typeof(player) == TYPE_DICTIONARY and str(player.get("id", "")) == player_id:
			return player
	return {}

func _ensure_alliance_maps(game_state: Dictionary) -> void:
	var alliances: Dictionary = {}
	var raw_alliances: Variant = game_state.get("factionAlliances", {})
	if typeof(raw_alliances) == TYPE_DICTIONARY:
		alliances = raw_alliances
	for faction in SUPPORTED_FACTIONS:
		if not alliances.has(faction):
			alliances[faction] = ""
	game_state["factionAlliances"] = alliances

	var players := _get_players(game_state)
	if players.is_empty():
		return
	for player in players:
		if typeof(player) != TYPE_DICTIONARY:
			continue
		var player_alliances: Dictionary = {}
		var raw_player_alliances: Variant = player.get("alliances", {})
		if typeof(raw_player_alliances) == TYPE_DICTIONARY:
			player_alliances = raw_player_alliances
		for faction in SUPPORTED_FACTIONS:
			if not player_alliances.has(faction):
				player_alliances[faction] = false
		player["alliances"] = player_alliances

func _get_players(game_state: Dictionary) -> Array:
	var players: Array = []
	var raw_players: Variant = game_state.get("players", [])
	if typeof(raw_players) == TYPE_ARRAY:
		players = raw_players
	return players

func _get_player_influence_map(player_state: Dictionary) -> Dictionary:
	var influence_map: Dictionary = {}
	var raw_influence_map: Variant = player_state.get("influence", {})
	if typeof(raw_influence_map) == TYPE_DICTIONARY:
		influence_map = raw_influence_map
	return influence_map

func _sync_alliance_vp_bonus(players: Array) -> void:
	for player in players:
		if typeof(player) != TYPE_DICTIONARY:
			continue
		var alliances: Dictionary = {}
		var raw_alliances: Variant = player.get("alliances", {})
		if typeof(raw_alliances) == TYPE_DICTIONARY:
			alliances = raw_alliances

		var active_alliances := 0
		for faction in SUPPORTED_FACTIONS:
			if bool(alliances.get(faction, false)):
				active_alliances += 1

		var previous_bonus := int(player.get("allianceVpBonus", 0))
		if previous_bonus != active_alliances:
			player["vp"] = int(player.get("vp", 0)) + (active_alliances - previous_bonus)
		player["allianceVpBonus"] = active_alliances

func _change_resource(player_state: Dictionary, resource: String, delta: int) -> void:
	var resources: Dictionary = {}
	var raw_resources: Variant = player_state.get("resources", {})
	if typeof(raw_resources) == TYPE_DICTIONARY:
		resources = raw_resources
	var current := int(resources.get(resource, 0))
	resources[resource] = max(current + delta, 0)
	player_state["resources"] = resources
