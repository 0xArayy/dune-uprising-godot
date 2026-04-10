extends RefCounted
class_name PopupCoordinator

func resolve_popup_state(
	has_pending_interaction: bool,
	has_pending_space_choice: bool,
	is_space_choice_open: bool
) -> Dictionary:
	return {
		"needsBlockInput": has_pending_interaction or has_pending_space_choice,
		"showChoice": has_pending_interaction and not is_space_choice_open
	}
