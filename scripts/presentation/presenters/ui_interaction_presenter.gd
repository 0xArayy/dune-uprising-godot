extends RefCounted
class_name UiInteractionPresenter

func build_view_model(
	game_state: Dictionary,
	current_player: Dictionary,
	pending_agent_card_id: String,
	has_pending_interaction: bool,
	awaiting_space_choice: bool,
	has_pending_spy_recall_draw: bool
) -> Dictionary:
	var is_player_turns := str(game_state.get("phase", "")) == "player_turns"
	var can_play_cards := false
	if is_player_turns and not current_player.is_empty():
		can_play_cards = int(current_player.get("agentsAvailable", 0)) > 0 and not bool(current_player.get("passedReveal", false))
	if pending_agent_card_id != "":
		can_play_cards = false

	var waiting_for_end_turn := is_player_turns and not current_player.is_empty() and bool(current_player.get("passedReveal", false))
	var can_reveal := is_player_turns and pending_agent_card_id == ""
	var can_cancel_selection := is_player_turns and pending_agent_card_id != ""

	if waiting_for_end_turn:
		can_play_cards = false
	if has_pending_interaction or awaiting_space_choice:
		can_play_cards = false
		can_reveal = false
	if has_pending_interaction:
		can_cancel_selection = has_pending_spy_recall_draw
	elif awaiting_space_choice:
		can_cancel_selection = is_player_turns and pending_agent_card_id != ""

	return {
		"isPlayerTurns": is_player_turns,
		"waitingForEndTurn": waiting_for_end_turn,
		"canPlayCards": can_play_cards,
		"canReveal": can_reveal,
		"canCancelSelection": can_cancel_selection
	}
