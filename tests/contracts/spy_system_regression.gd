extends RefCounted

const SpySystemScript = preload("res://scripts/spy_system.gd")

func run_all_checks() -> Dictionary:
	var checks: Array = [
		_check_place_spy_success(),
		_check_spy_cap(),
		_check_occupied_post_rejected()
	]
	for result in checks:
		if typeof(result) != TYPE_DICTIONARY:
			return {"ok": false, "reason": "spy_system_invalid_check_result"}
		if not bool((result as Dictionary).get("ok", false)):
			var out: Dictionary = (result as Dictionary).duplicate(true)
			out["suite"] = "spy_system"
			return out
	return {"ok": true}

func _minimal_spy_state() -> Dictionary:
	return {
		"spyPostConnections": {
			"post_a": ["s1"],
			"post_b": ["s2"],
			"post_c": ["s3"],
			"post_d": ["s4"]
		},
		"spyPostsOccupancy": {
			"post_a": null,
			"post_b": null,
			"post_c": null,
			"post_d": null
		}
	}

func _check_place_spy_success() -> Dictionary:
	var gs := _minimal_spy_state()
	var r: Dictionary = SpySystemScript.place_spy(gs, "p1", "post_a")
	if not bool(r.get("ok", false)):
		return {"ok": false, "reason": "place_spy_expected_ok", "detail": r}
	return {"ok": true}

func _check_spy_cap() -> Dictionary:
	var gs := _minimal_spy_state()
	SpySystemScript.place_spy(gs, "p1", "post_a")
	SpySystemScript.place_spy(gs, "p1", "post_b")
	SpySystemScript.place_spy(gs, "p1", "post_c")
	var r: Dictionary = SpySystemScript.place_spy(gs, "p1", "post_d")
	if bool(r.get("ok", false)):
		return {"ok": false, "reason": "spy_cap_should_fail"}
	if str(r.get("reason", "")) != "spy_cap_reached":
		return {"ok": false, "reason": "spy_cap_wrong_reason", "detail": r}
	return {"ok": true}

func _check_occupied_post_rejected() -> Dictionary:
	var gs := _minimal_spy_state()
	SpySystemScript.place_spy(gs, "p2", "post_a")
	var r: Dictionary = SpySystemScript.place_spy(gs, "p1", "post_a")
	if bool(r.get("ok", false)):
		return {"ok": false, "reason": "occupied_post_should_fail"}
	if str(r.get("reason", "")) != "spy_post_occupied":
		return {"ok": false, "reason": "occupied_post_wrong_reason", "detail": r}
	return {"ok": true}
