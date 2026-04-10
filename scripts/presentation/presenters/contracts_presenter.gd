extends RefCounted
class_name ContractsPresenter


func build_view_model(game_state: Dictionary) -> Dictionary:
	var face_up_raw: Variant = game_state.get("choamFaceUpContracts", [])
	var face_up: Array = face_up_raw if typeof(face_up_raw) == TYPE_ARRAY else []
	var by_id_raw: Variant = game_state.get("choamContractsById", {})
	var by_id: Dictionary = by_id_raw if typeof(by_id_raw) == TYPE_DICTIONARY else {}
	var entries: Array = []
	for cid_raw in face_up:
		var cid := str(cid_raw)
		var def_raw: Variant = by_id.get(cid, {})
		var def: Dictionary = def_raw if typeof(def_raw) == TYPE_DICTIONARY else {}
		entries.append({
			"id": cid,
			"name": str(def.get("name", cid))
		})
	return {
		"faceUpCount": face_up.size(),
		"faceUpContractIds": face_up.duplicate(),
		"entries": entries
	}
