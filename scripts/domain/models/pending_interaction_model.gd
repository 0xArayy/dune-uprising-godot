extends RefCounted
class_name PendingInteractionModel

var pending_trash: int = 0
var pending_conflict_deploy_max: int = 0
var pending_place_spy: int = 0
var pending_spy_recall_draw_cards: int = 0

func from_player_dict(player: Dictionary) -> PendingInteractionModel:
	pending_trash = int(player.get("pendingTrash", 0))
	pending_conflict_deploy_max = int(player.get("pendingConflictDeployMax", 0))
	pending_place_spy = int(player.get("pendingPlaceSpy", 0))
	pending_spy_recall_draw_cards = int(player.get("pendingSpyRecallDrawCards", 0))
	return self

func to_dict() -> Dictionary:
	return {
		"pendingTrash": pending_trash,
		"pendingConflictDeployMax": pending_conflict_deploy_max,
		"pendingPlaceSpy": pending_place_spy,
		"pendingSpyRecallDrawCards": pending_spy_recall_draw_cards
	}
