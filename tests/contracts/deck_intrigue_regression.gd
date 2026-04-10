extends RefCounted

const DeckServiceScript = preload("res://scripts/deck_service.gd")

func run_all_checks() -> Dictionary:
	var checks: Array = [
		_check_reshuffle_discard_into_deck(),
		_check_draw_intrigue_respects_deck_size()
	]
	for result in checks:
		if typeof(result) != TYPE_DICTIONARY:
			return {"ok": false, "reason": "deck_intrigue_invalid_check_result"}
		if not bool((result as Dictionary).get("ok", false)):
			var out: Dictionary = (result as Dictionary).duplicate(true)
			out["suite"] = "deck_intrigue"
			return out
	return {"ok": true}

func _check_reshuffle_discard_into_deck() -> Dictionary:
	var gs := {
		"intrigueDeck": [],
		"intrigueDiscard": ["i1", "i2", "i3"]
	}
	var deck_svc = DeckServiceScript.new()
	deck_svc.reshuffle_intrigue_discard_if_needed(gs)
	var d: Array = gs.get("intrigueDeck", [])
	var disc: Array = gs.get("intrigueDiscard", [])
	if d.size() != 3:
		return {"ok": false, "reason": "reshuffle_deck_size", "deck": d}
	if not disc.is_empty():
		return {"ok": false, "reason": "reshuffle_discard_should_clear"}
	var sorted_deck: Array = d.duplicate()
	sorted_deck.sort()
	var expected := ["i1", "i2", "i3"]
	expected.sort()
	if sorted_deck != expected:
		return {"ok": false, "reason": "reshuffle_wrong_ids", "deck": d}
	return {"ok": true}

func _check_draw_intrigue_respects_deck_size() -> Dictionary:
	var gs := {
		"intrigueDeck": ["a", "b"],
		"intrigueDiscard": []
	}
	var player := {"id": "p1", "intrigue": []}
	var deck_svc = DeckServiceScript.new()
	var drawn: Array = deck_svc.draw_intrigue(gs, player, 5)
	if drawn.size() != 2:
		return {"ok": false, "reason": "draw_should_not_exceed_deck", "drawn": drawn}
	var hand: Array = player.get("intrigue", [])
	if hand.size() != 2:
		return {"ok": false, "reason": "intrigue_hand_size", "hand": hand}
	return {"ok": true}
