extends RefCounted
class_name DeckService

func create_shuffled_deck_from_template(template: Array) -> Array:
	var deck: Array = template.duplicate()
	_shuffle_array(deck)
	return deck

func shuffle_array(values: Array) -> void:
	_shuffle_array(values)

func draw_cards(player_state: Dictionary, count: int) -> void:
	if typeof(player_state) != TYPE_DICTIONARY:
		return
	for _i in range(max(count, 0)):
		var drawn := draw_one(player_state)
		if drawn == "":
			return

func draw_one(player_state: Dictionary) -> String:
	if typeof(player_state) != TYPE_DICTIONARY:
		return ""

	reshuffle_discard_into_deck_if_needed(player_state)
	var deck := _ensure_card_zone_array(player_state, "deck")
	if deck.is_empty():
		return ""

	var card_id := str(deck.pop_back())
	player_state["deck"] = deck

	var hand := _ensure_card_zone_array(player_state, "hand")
	hand.append(card_id)
	player_state["hand"] = hand
	return card_id

func reshuffle_discard_into_deck_if_needed(player_state: Dictionary) -> void:
	if typeof(player_state) != TYPE_DICTIONARY:
		return

	var deck := _ensure_card_zone_array(player_state, "deck")
	if not deck.is_empty():
		return

	var discard := _ensure_card_zone_array(player_state, "discard")
	if discard.is_empty():
		return

	var refill_deck: Array = discard.duplicate()
	_shuffle_array(refill_deck)
	player_state["deck"] = refill_deck
	player_state["discard"] = []

func move_card_hand_to_in_play(player_state: Dictionary, card_id: String) -> bool:
	if typeof(player_state) != TYPE_DICTIONARY:
		return false

	var hand := _ensure_card_zone_array(player_state, "hand")
	var idx := hand.find(card_id)
	if idx < 0:
		return false

	hand.remove_at(idx)
	player_state["hand"] = hand

	var in_play := _ensure_card_zone_array(player_state, "inPlay")
	in_play.append(card_id)
	player_state["inPlay"] = in_play
	return true

func move_card_in_play_to_hand(player_state: Dictionary, card_id: String) -> bool:
	if typeof(player_state) != TYPE_DICTIONARY:
		return false

	var in_play := _ensure_card_zone_array(player_state, "inPlay")
	var idx := in_play.find(card_id)
	if idx < 0:
		return false

	in_play.remove_at(idx)
	player_state["inPlay"] = in_play

	var hand := _ensure_card_zone_array(player_state, "hand")
	hand.append(card_id)
	player_state["hand"] = hand
	return true

func move_all_hand_to_in_play(player_state: Dictionary) -> void:
	if typeof(player_state) != TYPE_DICTIONARY:
		return

	var hand := _ensure_card_zone_array(player_state, "hand")
	if hand.is_empty():
		return

	var in_play := _ensure_card_zone_array(player_state, "inPlay")
	for card_id in hand:
		in_play.append(str(card_id))

	player_state["inPlay"] = in_play
	player_state["hand"] = []

func discard_all_hand_and_in_play(player_state: Dictionary) -> Array:
	if typeof(player_state) != TYPE_DICTIONARY:
		return []

	var discard := _ensure_card_zone_array(player_state, "discard")
	var hand := _ensure_card_zone_array(player_state, "hand")
	var in_play := _ensure_card_zone_array(player_state, "inPlay")
	var discarded_cards: Array = []

	for card_id in hand:
		var normalized := str(card_id)
		discard.append(normalized)
		discarded_cards.append(normalized)
	for card_id in in_play:
		var normalized := str(card_id)
		discard.append(normalized)
		discarded_cards.append(normalized)

	player_state["discard"] = discard
	player_state["hand"] = []
	player_state["inPlay"] = []
	return discarded_cards

func prepare_new_round_hand(player_state: Dictionary, hand_size: int) -> void:
	if typeof(player_state) != TYPE_DICTIONARY:
		return

	# Keep deck-builder flow deterministic: cleanup zones then draw a fresh hand.
	discard_all_hand_and_in_play(player_state)
	draw_cards(player_state, max(hand_size, 0))

func append_intrigue_discard(game_state: Dictionary, card_id: String) -> void:
	if typeof(game_state) != TYPE_DICTIONARY:
		return
	var cid := str(card_id).strip_edges()
	if cid == "":
		return
	var d_raw: Variant = game_state.get("intrigueDiscard", [])
	var d: Array = d_raw if typeof(d_raw) == TYPE_ARRAY else []
	d.append(cid)
	game_state["intrigueDiscard"] = d

func reshuffle_intrigue_discard_if_needed(game_state: Dictionary) -> void:
	if typeof(game_state) != TYPE_DICTIONARY:
		return
	var deck_raw: Variant = game_state.get("intrigueDeck", [])
	var deck: Array = deck_raw if typeof(deck_raw) == TYPE_ARRAY else []
	if not deck.is_empty():
		return
	var discard_raw: Variant = game_state.get("intrigueDiscard", [])
	var discard: Array = discard_raw if typeof(discard_raw) == TYPE_ARRAY else []
	if discard.is_empty():
		return
	var refill: Array = discard.duplicate()
	_shuffle_array(refill)
	game_state["intrigueDeck"] = refill
	game_state["intrigueDiscard"] = []

## Draws intrigue cards from the global intrigue deck into the player's intrigue hand (player_state["intrigue"]).
## Returns ids actually drawn (may be fewer than count if the deck is exhausted).
func draw_intrigue(game_state: Dictionary, player_state: Dictionary, count: int) -> Array:
	var drawn: Array = []
	if typeof(game_state) != TYPE_DICTIONARY or typeof(player_state) != TYPE_DICTIONARY:
		return drawn
	var n := maxi(count, 0)
	if n <= 0:
		return drawn
	for _i in range(n):
		reshuffle_intrigue_discard_if_needed(game_state)
		var deck_raw2: Variant = game_state.get("intrigueDeck", [])
		var intrigue_deck: Array = deck_raw2 if typeof(deck_raw2) == TYPE_ARRAY else []
		if intrigue_deck.is_empty():
			break
		var card_id := str(intrigue_deck.pop_back())
		game_state["intrigueDeck"] = intrigue_deck
		var intrigue_hand := _ensure_intrigue_hand_array(player_state)
		intrigue_hand.append(card_id)
		player_state["intrigue"] = intrigue_hand
		player_state["intrigueCount"] = intrigue_hand.size()
		drawn.append(card_id)
	return drawn

func _ensure_intrigue_hand_array(player_state: Dictionary) -> Array:
	var zone = player_state.get("intrigue", [])
	if typeof(zone) != TYPE_ARRAY:
		zone = []
	player_state["intrigue"] = zone
	return zone

func _ensure_card_zone_array(player_state: Dictionary, zone_key: String) -> Array:
	var zone = player_state.get(zone_key, [])
	if typeof(zone) != TYPE_ARRAY:
		zone = []
	player_state[zone_key] = zone
	return zone

func _shuffle_array(values: Array) -> void:
	RandomService.shuffle(values)
