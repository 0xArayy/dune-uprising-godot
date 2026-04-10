extends RefCounted
class_name PlayerStateModel

var id: String
var seat_index: int
var agents_total: int
var agents_available: int
var vp: int
var passed_reveal: bool

func from_dict(data: Dictionary) -> PlayerStateModel:
	id = str(data.get("id", ""))
	seat_index = int(data.get("seatIndex", 0))
	agents_total = int(data.get("agentsTotal", 0))
	agents_available = int(data.get("agentsAvailable", 0))
	vp = int(data.get("vp", 0))
	passed_reveal = bool(data.get("passedReveal", false))
	return self

func to_dict() -> Dictionary:
	return {
		"id": id,
		"seatIndex": seat_index,
		"agentsTotal": agents_total,
		"agentsAvailable": agents_available,
		"vp": vp,
		"passedReveal": passed_reveal
	}
