extends Node
class_name SpySystem

const MAX_SPIES_PER_PLAYER := 3

static func ensure_spy_state(game_state: Dictionary) -> void:
	if typeof(game_state.get("spyPostConnections", null)) != TYPE_DICTIONARY:
		game_state["spyPostConnections"] = _load_default_connections()

	if typeof(game_state.get("spyPostsOccupancy", null)) != TYPE_DICTIONARY:
		var occupancy := {}
		var connections: Dictionary = game_state.get("spyPostConnections", {})
		for post_id in connections.keys():
			occupancy[str(post_id)] = null
		game_state["spyPostsOccupancy"] = occupancy

	if typeof(game_state.get("spyAccessByPlayer", null)) != TYPE_DICTIONARY:
		game_state["spyAccessByPlayer"] = {}

static func rebuild_access_by_player(game_state: Dictionary) -> Dictionary:
	ensure_spy_state(game_state)

	var by_player := {}
	var occupancy: Dictionary = game_state.get("spyPostsOccupancy", {})
	var connections: Dictionary = game_state.get("spyPostConnections", {})

	for post_id in occupancy.keys():
		var post_entry: Variant = occupancy[post_id]
		var owners: Array[String] = []
		if typeof(post_entry) == TYPE_ARRAY:
			for owner_raw in post_entry:
				var owner_id := str(owner_raw)
				if owner_id == "" or owners.has(owner_id):
					continue
				owners.append(owner_id)
		elif post_entry != null:
			var owner_id := str(post_entry)
			if owner_id != "":
				owners.append(owner_id)
		if owners.is_empty():
			continue

		var spaces: Array = connections.get(post_id, [])
		for player_id in owners:
			if not by_player.has(player_id):
				by_player[player_id] = []
			for space_id in spaces:
				if not by_player[player_id].has(space_id):
					by_player[player_id].append(space_id)

	game_state["spyAccessByPlayer"] = by_player
	return by_player

static func place_spy(game_state: Dictionary, player_id: String, post_id: String, allow_shared: bool = false) -> Dictionary:
	ensure_spy_state(game_state)
	var occupancy: Dictionary = game_state.get("spyPostsOccupancy", {})

	if not occupancy.has(post_id):
		return {"ok": false, "reason": "unknown_spy_post"}
	var post_entry: Variant = occupancy[post_id]
	var is_occupied := _entry_has_any_owner(post_entry)
	if is_occupied and not allow_shared:
		return {"ok": false, "reason": "spy_post_occupied"}
	if is_occupied and _entry_has_owner(post_entry, player_id):
		return {"ok": false, "reason": "spy_already_on_post"}
	if get_player_spy_count(game_state, player_id) >= MAX_SPIES_PER_PLAYER:
		return {"ok": false, "reason": "spy_cap_reached", "maxSpies": MAX_SPIES_PER_PLAYER}

	if not is_occupied:
		occupancy[post_id] = player_id
	elif typeof(post_entry) == TYPE_ARRAY:
		var owners: Array = post_entry
		owners.append(player_id)
		occupancy[post_id] = owners
	else:
		occupancy[post_id] = [str(post_entry), player_id]
	game_state["spyPostsOccupancy"] = occupancy
	rebuild_access_by_player(game_state)
	return {"ok": true}

static func recall_spy(game_state: Dictionary, player_id: String, post_id: String) -> Dictionary:
	ensure_spy_state(game_state)
	var occupancy: Dictionary = game_state.get("spyPostsOccupancy", {})

	if not occupancy.has(post_id):
		return {"ok": false, "reason": "unknown_spy_post"}
	var post_entry: Variant = occupancy[post_id]
	if not _entry_has_owner(post_entry, player_id):
		return {"ok": false, "reason": "spy_not_owned"}

	if typeof(post_entry) == TYPE_ARRAY:
		var owners: Array = post_entry
		var idx := owners.find(player_id)
		if idx >= 0:
			owners.remove_at(idx)
		if owners.is_empty():
			occupancy[post_id] = null
		elif owners.size() == 1:
			occupancy[post_id] = str(owners[0])
		else:
			occupancy[post_id] = owners
	else:
		occupancy[post_id] = null
	game_state["spyPostsOccupancy"] = occupancy
	rebuild_access_by_player(game_state)
	return {"ok": true}

static func get_player_spy_post_ids(game_state: Dictionary, player_id: String) -> Array:
	ensure_spy_state(game_state)
	var occupancy: Dictionary = game_state.get("spyPostsOccupancy", {})
	var owned_posts: Array = []
	for post_id_variant in occupancy.keys():
		if _entry_has_owner(occupancy[post_id_variant], player_id):
			owned_posts.append(str(post_id_variant))
	owned_posts.sort()
	return owned_posts

static func get_player_spy_count(game_state: Dictionary, player_id: String) -> int:
	return get_player_spy_post_ids(game_state, player_id).size()

static func get_unoccupied_spy_post_ids(game_state: Dictionary) -> Array:
	ensure_spy_state(game_state)
	var occupancy: Dictionary = game_state.get("spyPostsOccupancy", {})
	var available_posts: Array = []
	for post_id_variant in occupancy.keys():
		if not _entry_has_any_owner(occupancy[post_id_variant]):
			available_posts.append(str(post_id_variant))
	available_posts.sort()
	return available_posts

static func get_player_spy_post_ids_connected_to_space(game_state: Dictionary, player_id: String, space_id: String) -> Array:
	ensure_spy_state(game_state)
	var occupancy: Dictionary = game_state.get("spyPostsOccupancy", {})
	var connections: Dictionary = game_state.get("spyPostConnections", {})
	var connected_owned_posts: Array = []
	var target_space_id := str(space_id)
	for post_id_variant in occupancy.keys():
		var post_id := str(post_id_variant)
		if not _entry_has_owner(occupancy.get(post_id, null), player_id):
			continue
		var spaces: Variant = connections.get(post_id, [])
		if typeof(spaces) != TYPE_ARRAY:
			continue
		for linked_space_variant in spaces:
			if str(linked_space_variant) == target_space_id:
				connected_owned_posts.append(post_id)
				break
	connected_owned_posts.sort()
	return connected_owned_posts

static func _entry_has_owner(entry: Variant, player_id: String) -> bool:
	if entry == null:
		return false
	if typeof(entry) == TYPE_ARRAY:
		var owners: Array = entry
		return owners.has(player_id)
	return str(entry) == player_id

static func _entry_has_any_owner(entry: Variant) -> bool:
	if entry == null:
		return false
	if typeof(entry) == TYPE_ARRAY:
		return not (entry as Array).is_empty()
	return str(entry) != ""

static func _load_default_connections(path: String = "res://data/spy_posts_uprising.json") -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		return {}

	var by_post := {}
	for item in parsed:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var post_id := str(item.get("id", ""))
		if post_id == "":
			continue
		var spaces = item.get("connectedSpaces", [])
		if typeof(spaces) != TYPE_ARRAY:
			spaces = []
		by_post[post_id] = spaces
	return by_post
