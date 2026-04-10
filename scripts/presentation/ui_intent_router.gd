extends RefCounted
class_name UiIntentRouter

var _bindings: Array[Dictionary] = []

func bind_default_handlers(target: Node) -> void:
	_bind(GameEvents.ui_intent_card_play, Callable(target, "_on_ui_card_play_requested"))
	_bind(GameEvents.ui_intent_cancel_card_selection, Callable(target, "_on_ui_cancel_card_selection_requested"))
	_bind(GameEvents.ui_intent_market_buy, Callable(target, "_on_ui_market_buy_requested"))
	_bind(GameEvents.ui_intent_pending_trash, Callable(target, "_on_ui_pending_trash_selected"))
	_bind(GameEvents.ui_intent_pending_conflict_deploy, Callable(target, "_on_ui_pending_conflict_deploy_selected"))
	_bind(GameEvents.ui_intent_space_choice, Callable(target, "_on_ui_space_choice_selected"))
	_bind(GameEvents.ui_intent_space_choice_cancel, Callable(target, "_on_ui_space_choice_cancel_requested"))
	_bind(GameEvents.ui_intent_reveal, Callable(target, "_on_ui_reveal_pressed"))
	_bind(GameEvents.ui_intent_combat_intrigue_pass, Callable(target, "_on_ui_combat_intrigue_pass"))
	_bind(GameEvents.ui_intent_combat_intrigue_play, Callable(target, "_on_ui_combat_intrigue_play"))
	_bind(GameEvents.ui_intent_plot_intrigue_play, Callable(target, "_on_ui_plot_intrigue_play"))
	_bind(GameEvents.ui_intent_immediate_conflict_win_intrigue_play, Callable(target, "_on_ui_immediate_conflict_win_intrigue_play"))
	_bind(GameEvents.ui_intent_immediate_conflict_win_intrigue_decline, Callable(target, "_on_ui_immediate_conflict_win_intrigue_decline"))
	_bind(GameEvents.ui_intent_endgame_intrigue_pass, Callable(target, "_on_ui_endgame_intrigue_pass"))
	_bind(GameEvents.ui_intent_endgame_intrigue_play, Callable(target, "_on_ui_endgame_intrigue_play"))

func unbind_all() -> void:
	for binding in _bindings:
		var sig: Signal = binding.get("signal")
		var cb: Callable = binding.get("callable")
		if sig.is_connected(cb):
			sig.disconnect(cb)
	_bindings.clear()

func _bind(sig: Signal, cb: Callable) -> void:
	if sig.is_connected(cb):
		return
	sig.connect(cb)
	_bindings.append({"signal": sig, "callable": cb})
