extends Node

# UI -> game root (intents, same role as tutorial `Events` bus wiring in `run.gd`).
signal ui_intent_reveal
signal ui_intent_card_play(card_id: String)
signal ui_intent_cancel_card_selection
signal ui_intent_market_buy(card_id: String)
signal ui_intent_pending_trash(zone_key: String, card_id: String)
signal ui_intent_pending_conflict_deploy(amount: int)
signal ui_intent_space_choice(slot: int, option_index: int)
signal ui_intent_space_choice_cancel
signal ui_intent_combat_intrigue_pass
signal ui_intent_combat_intrigue_play(card_id: String)
signal ui_intent_plot_intrigue_play(card_id: String)
signal ui_intent_immediate_conflict_win_intrigue_play
signal ui_intent_immediate_conflict_win_intrigue_decline
signal ui_intent_endgame_intrigue_pass
signal ui_intent_endgame_intrigue_play(card_id: String)
signal spy_selection_state_changed(active: bool, mode: String, pending_amount: int)

# State broadcast for UI that binds to `game_state` dictionaries.
signal state_changed(game_state: Dictionary)
signal phase_changed(phase: String)
