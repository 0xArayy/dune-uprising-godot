extends Node

const ContractServiceScript = preload("res://scripts/contract_service.gd")
const DeckServiceScript = preload("res://scripts/deck_service.gd")
const GameConstantsScript = preload("res://scripts/domain/game_constants.gd")
const GameCoordinatorScript = preload("res://scripts/application/game_coordinator.gd")
const RuleContractRegressionScript = preload("res://tests/contracts/rule_contract_regression.gd")
const HudPresenterScript = preload("res://scripts/presentation/presenters/hud_presenter.gd")
const MarketPresenterScript = preload("res://scripts/presentation/presenters/market_presenter.gd")
const ContractsPresenterScript = preload("res://scripts/presentation/presenters/contracts_presenter.gd")
const PopupCoordinatorScript = preload("res://scripts/presentation/presenters/popup_coordinator.gd")
const UiInteractionPresenterScript = preload("res://scripts/presentation/presenters/ui_interaction_presenter.gd")
const InteractionStateMachineScript = preload("res://scripts/presentation/fsm/interaction_state_machine.gd")
const UiIntentRouterScript = preload("res://scripts/presentation/ui_intent_router.gd")
const CardsRepositoryScript = preload("res://scripts/infrastructure/cards_repository.gd")
const ConflictRepositoryScript = preload("res://scripts/infrastructure/conflict_repository.gd")
const IntrigueRepositoryScript = preload("res://scripts/infrastructure/intrigue_repository.gd")
const ObjectiveRepositoryScript = preload("res://scripts/infrastructure/objective_repository.gd")

## Standard table target for refactored core: 4 players.
const STARTING_PLAYER_IDS: PackedStringArray = GameConstantsScript.DEFAULT_PLAYER_IDS

@onready var board_map = $BoardMap
@onready var game_ui: GameUi = $GameUi

@export var run_debug_tests := false
@export var use_refactored_core := true
@export_range(2, 4, 1) var player_count := 2
@export var board_padding_left := 18.0
@export var board_padding_right := 18.0
@export var board_padding_top := 16.0
@export var board_padding_bottom := 16.0

var turn_controller: TurnController
var game_coordinator: GameCoordinator
var hud_presenter: HudPresenter
var market_presenter: MarketPresenter
var contracts_presenter: ContractsPresenter
var popup_coordinator: PopupCoordinator
var ui_interaction_presenter: UiInteractionPresenter
var interaction_fsm: InteractionStateMachine
var ui_intent_router: UiIntentRouter = UiIntentRouterScript.new()
var deck_service := DeckServiceScript.new()
var cards_repository: CardsRepository = CardsRepositoryScript.new()
var conflict_repository: ConflictRepository = ConflictRepositoryScript.new()
var intrigue_repository: IntrigueRepository = IntrigueRepositoryScript.new()
var objective_repository = ObjectiveRepositoryScript.new()
var game_state: Dictionary = {}
var pending_agent_card_id := ""
var _pending_space_choice_space_id := ""
var _pending_spy_selection_mode := ""
const CONFLICT_COST_CHOICE_SLOT := GameConstantsScript.PENDING_SLOT_CONFLICT_COST
const CONFLICT_INFLUENCE_CHOICE_SLOT := GameConstantsScript.PENDING_SLOT_CONFLICT_INFLUENCE
const CARD_EFFECT_CHOICE_SLOT := GameConstantsScript.PENDING_SLOT_CARD_EFFECT
const CONTRACT_CHOICE_SLOT := GameConstantsScript.PENDING_SLOT_CONTRACT

func _ready():
	if board_map == null:
		push_error("GameRoot: $BoardMap is null")
		return

	var script = board_map.get_script()
	if script == null:
		push_error("GameRoot: BoardMap has no script attached")
		return

	if not board_map.has_method("take_agent_turn"):
		push_error("GameRoot: $BoardMap does not have take_agent_turn. Script may not be attached.")
		return

	var cards_by_id = cards_repository.get_all()
	var starter_deck_template = _build_starter_deck_template(cards_by_id)
	var imperium_setup := _build_imperium_setup(cards_by_id)
	var conflict_setup := _build_conflict_setup_10_rounds()
	var choam_contracts_by_id := ContractServiceScript.load_contracts_by_id()
	var choam_contract_ids: Array = choam_contracts_by_id.keys()
	choam_contract_ids.sort()
	deck_service.shuffle_array(choam_contract_ids)
	var choam_setup := ContractServiceScript.build_choam_state(choam_contract_ids)
	var intrigue_setup := _build_intrigue_setup()
	var objective_setup := _build_objective_setup()
	var starting_player_ids: Array = _resolve_starting_player_ids()

	var players: Array = []
	for seat in range(starting_player_ids.size()):
		var pid := str(starting_player_ids[seat])
		players.append(_build_player_state(pid, seat, 2, 0, 1, starter_deck_template))
	_apply_objective_deal(players, objective_setup)

	game_state = {
		"id": "local_hotseat_game",
		"version": 1,
		"phase": "round_start",
		"round": 0,
		"firstPlayerId": "p1",
		"currentPlayerId": "p1",
		"status": "in_progress",
		"winnerPlayerId": null,
		"cardsById": cards_by_id,
		"imperiumDeck": imperium_setup.get("deck", []),
		"imperiumMarket": imperium_setup.get("market", []),
		"reserveCards": imperium_setup.get("reserve", {}),
		"players": players,
		"boardOccupancy": {},
		"conflictDeck": conflict_setup.get("deck", []),
		"conflictDeckTotal": int(conflict_setup.get("deck", []).size()),
		"activeConflictCardId": null,
		"activeConflictCardDef": null,
		"conflictCardsById": conflict_setup.get("defs", {}),
		"objectiveCardsById": objective_setup.get("defs", {}),
		"objectiveDeck": objective_setup.get("deck", []),
		"intriguesById": intrigue_setup.get("defs", {}),
		"intrigueDeck": intrigue_setup.get("deck", []),
		"intrigueDiscard": [],
		"combatIntrigueRound": {},
		"pendingImmediateConflictWinIntrigue": {},
		"endgameIntrigueRound": {},
		"pendingConflictRewardIntrigueDraw": {},
		"pendingConflictCostChoice": {},
		"pendingConflictSandwormSecondCost": {},
		"pendingConflictInfluenceChoice": {},
		"choamContractsById": choam_contracts_by_id,
		"choamContractDeck": choam_setup.get("choamContractDeck", []),
		"choamFaceUpContracts": choam_setup.get("choamFaceUpContracts", []),
		"choamContractsAvailable": int(choam_setup.get("choamContractsAvailable", 0)),
		"makerSpice": {
			"deep_desert": 0,
			"hagga_basin": 0,
			"imperial_basin": 0
		},
		"factionAlliances": {
			"emperor": "",
			"guild": "",
			"beneGesserit": "",
			"fremen": ""
		},
		"controlBySpace": {
			"arrakeen": "",
			"spice_refinery": "",
			"imperial_basin": ""
		},
		"shieldWallIntact": true,
		"rulesConfig": {
			"enableOutOfScopeSystems": false,
			"choamEnabled": true
		},
		"log": []
	}

	turn_controller = TurnController.new()
	add_child(turn_controller)
	game_coordinator = GameCoordinatorScript.new()
	add_child(game_coordinator)
	game_coordinator.setup(turn_controller)
	hud_presenter = HudPresenterScript.new()
	market_presenter = MarketPresenterScript.new()
	contracts_presenter = ContractsPresenterScript.new()
	popup_coordinator = PopupCoordinatorScript.new()
	ui_interaction_presenter = UiInteractionPresenterScript.new()
	interaction_fsm = InteractionStateMachineScript.new()
	_setup_event_connections()
	board_map.highlighted_space_selected.connect(_on_board_highlighted_space_selected)
	board_map.highlighted_spy_post_selected.connect(_on_board_highlighted_spy_post_selected)
	get_viewport().size_changed.connect(_on_viewport_size_changed)

	var regression: RuleContractRegression = RuleContractRegressionScript.new()
	var regression_result := regression.run_all_checks()
	if not bool(regression_result.get("ok", false)):
		push_warning("Rule contract regression failed: %s" % str(regression_result))
	var start_result := {}
	if use_refactored_core:
		start_result = game_coordinator.start_round(game_state)
	else:
		start_result = turn_controller.start_round(game_state)
	if not bool(start_result.get("ok", false)):
		push_warning("GameCoordinator start_round failed: %s" % str(start_result))
	_refresh_ui()
	call_deferred("_layout_board_map")

	if run_debug_tests:
		var runner_script = load("res://tests/integration/debug_round_runner.gd")
		if runner_script == null:
			push_warning("GameRoot: debug runner script not found (res://tests/integration/debug_round_runner.gd)")
			return

		var runner = runner_script.new()
		add_child(runner)
		runner.run(game_state, turn_controller, board_map)

func _setup_event_connections() -> void:
	ui_intent_router.bind_default_handlers(self)

func _exit_tree() -> void:
	ui_intent_router.unbind_all()
	if board_map != null and board_map.highlighted_spy_post_selected.is_connected(_on_board_highlighted_spy_post_selected):
		board_map.highlighted_spy_post_selected.disconnect(_on_board_highlighted_spy_post_selected)

func _on_viewport_size_changed() -> void:
	_layout_board_map()

func _layout_board_map() -> void:
	if board_map == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var top_reserved := board_padding_top
	var bottom_reserved := board_padding_bottom
	var left_reserved := board_padding_left
	var right_reserved := board_padding_right
	if game_ui != null:
		top_reserved += game_ui.get_top_panel_height()
		bottom_reserved += game_ui.get_bottom_overlay_height()
		left_reserved += game_ui.get_left_panel_width()
		right_reserved += game_ui.get_right_panel_width()

	var available_width := viewport_size.x - left_reserved - right_reserved
	var available_height := viewport_size.y - top_reserved - bottom_reserved
	if available_width <= 1.0 or available_height <= 1.0:
		return

	var board_rect := _get_board_content_rect()
	if board_rect.size.x <= 1.0 or board_rect.size.y <= 1.0:
		return

	var scale_factor: float = minf(available_width / board_rect.size.x, available_height / board_rect.size.y)
	scale_factor = minf(scale_factor, 1.0)
	board_map.scale = Vector2.ONE * scale_factor

	var centered_x: float = left_reserved + (available_width - board_rect.size.x * scale_factor) * 0.5
	var centered_y: float = top_reserved + (available_height - board_rect.size.y * scale_factor) * 0.5
	board_map.position = Vector2(centered_x, centered_y) - board_rect.position * scale_factor

func _get_board_content_rect() -> Rect2:
	var spaces_root := board_map.get_node_or_null("BoardSpaces")
	if spaces_root == null:
		return Rect2(0, 0, 1, 1)

	var has_points := false
	var min_x := 0.0
	var max_x := 0.0
	var min_y := 0.0
	var max_y := 0.0

	for child in spaces_root.get_children():
		if not (child is Node2D):
			continue
		var marker := child as Node2D
		var pos := marker.position
		var marker_left := pos.x - 60.0
		var marker_right := pos.x + 60.0
		var marker_top := pos.y - 12.0
		# Board markers now include multiline location effects text.
		var marker_bottom := pos.y + 122.0

		if not has_points:
			min_x = marker_left
			max_x = marker_right
			min_y = marker_top
			max_y = marker_bottom
			has_points = true
			continue

		min_x = minf(min_x, marker_left)
		max_x = maxf(max_x, marker_right)
		min_y = minf(min_y, marker_top)
		max_y = maxf(max_y, marker_bottom)

	if not has_points:
		return Rect2(0, 0, 1, 1)

	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)

func _on_ui_reveal_pressed():
	if turn_controller == null:
		return
	if turn_controller.has_pending_player_interaction(game_state):
		_refresh_ui()
		return
	if pending_agent_card_id != "" or _pending_space_choice_space_id != "":
		return
	_clear_pending_agent_play()

	var current_player := _get_current_player_state()
	var waiting_for_end_turn := not current_player.is_empty() and bool(current_player.get("passedReveal", false))
	var action_result: Dictionary = {}
	if waiting_for_end_turn:
		action_result = turn_controller.advance_after_reveal(game_state)
	else:
		action_result = turn_controller.take_turn_reveal(game_state, board_map)

	if not bool(action_result.get("ok", false)):
		push_warning("Reveal/Pass failed: %s" % str(action_result.get("reason", "unknown")))
		_refresh_ui()
		return

	if bool(action_result.get("phaseFinished", false)):
		# Defensive guard: if phaseFinished is reported but not all players have
		# actually completed reveal, avoid triggering round pipeline prematurely.
		if not turn_controller.is_player_turns_phase_finished(game_state):
			_refresh_ui()
			return
		var pipeline = turn_controller.finish_round_pipeline(game_state, board_map)
		if use_refactored_core:
			pipeline = game_coordinator.finish_round(game_state, board_map)
		if not bool(pipeline.get("ok", false)):
			push_warning("Round pipeline failed: %s" % str(pipeline))

	_refresh_ui()

func _maybe_continue_round_after_conflict_resolution(result: Dictionary) -> void:
	if turn_controller == null:
		return
	if not bool(result.get("ok", false)):
		return
	if bool(result.get("awaitingInteraction", false)):
		return
	if str(game_state.get("phase", "")) == "makers":
		var cont: Dictionary
		if use_refactored_core:
			cont = game_coordinator.continue_round_pipeline_from_current_phase(game_state, board_map)
		else:
			cont = turn_controller.continue_round_pipeline_from_current_phase(game_state, board_map)
		if not bool(cont.get("ok", false)):
			push_warning("continue_round_pipeline_from_current_phase: %s" % str(cont))

func _on_ui_combat_intrigue_pass() -> void:
	if turn_controller == null:
		return
	var r: Dictionary = turn_controller.pass_combat_intrigue(game_state, board_map)
	_maybe_continue_round_after_conflict_resolution(r)
	_refresh_ui()

func _on_ui_combat_intrigue_play(card_id: String) -> void:
	if turn_controller == null or str(card_id).strip_edges() == "":
		return
	var r: Dictionary = turn_controller.play_combat_intrigue(game_state, board_map, card_id)
	_maybe_continue_round_after_conflict_resolution(r)
	_refresh_ui()

func _on_ui_plot_intrigue_play(card_id: String) -> void:
	if turn_controller == null or str(card_id).strip_edges() == "":
		return
	turn_controller.play_plot_intrigue(game_state, board_map, card_id)
	_refresh_ui()

func _on_ui_immediate_conflict_win_intrigue_play() -> void:
	if turn_controller == null:
		return
	turn_controller.play_immediate_conflict_win_intrigue(game_state, board_map)
	_refresh_ui()

func _on_ui_immediate_conflict_win_intrigue_decline() -> void:
	if turn_controller == null:
		return
	turn_controller.decline_immediate_conflict_win_intrigue(game_state)
	_refresh_ui()

func _on_ui_endgame_intrigue_pass() -> void:
	if turn_controller == null:
		return
	turn_controller.pass_endgame_intrigue(game_state)
	_refresh_ui()

func _on_ui_endgame_intrigue_play(card_id: String) -> void:
	if turn_controller == null or str(card_id).strip_edges() == "":
		return
	turn_controller.play_endgame_intrigue(game_state, board_map, card_id)
	_refresh_ui()

func _on_ui_card_play_requested(card_id: String) -> void:
	if turn_controller == null:
		return
	if turn_controller.has_pending_player_interaction(game_state):
		_refresh_ui()
		return
	if _pending_space_choice_space_id != "":
		_refresh_ui()
		return
	if str(game_state.get("phase", "")) != "player_turns":
		_refresh_ui()
		return
	if pending_agent_card_id != "":
		return

	var player = _get_current_player_state()
	if player.is_empty():
		_refresh_ui()
		return
	if int(player.get("agentsAvailable", 0)) <= 0:
		return

	var playable_spaces := _get_playable_space_ids_for_card(player, card_id)
	if playable_spaces.is_empty():
		push_warning("No playable board space for card: %s" % card_id)
		_refresh_ui()
		return

	pending_agent_card_id = card_id
	if interaction_fsm != null:
		interaction_fsm.to_selecting_space()
	board_map.set_highlighted_spaces(playable_spaces)
	_refresh_ui()

func _on_board_highlighted_space_selected(space_id: String) -> void:
	if pending_agent_card_id == "":
		return
	if turn_controller == null:
		return
	if turn_controller.has_pending_player_interaction(game_state):
		_refresh_ui()
		return
	if _pending_space_choice_space_id != "":
		return

	if board_map.has_method("get_pending_space_choice_context"):
		var choice_ctx: Dictionary = board_map.get_pending_space_choice_context(
			space_id,
			_get_current_player_state(),
			game_state
		)
		if not choice_ctx.is_empty():
			if bool(choice_ctx.get("noValidOptions", false)):
				push_warning("No valid choice options for space: %s" % space_id)
				_refresh_ui()
				return
			if choice_ctx.has("autoSelectOriginalIndex"):
				var choice_slot := int(choice_ctx.get("slot", 0))
				var auto_idx := int(choice_ctx.get("autoSelectOriginalIndex", 0))
				var auto_result = turn_controller.take_turn_send_agent(game_state, board_map, space_id, pending_agent_card_id, null, {
					"choice_indexes": { str(choice_slot): auto_idx }
				})
				if not bool(auto_result.get("ok", false)):
					push_warning("Card play failed: %s" % str(auto_result.get("reason", "unknown")))
					_refresh_ui()
					return
				_clear_pending_agent_play()
				_refresh_ui()
				return
			_pending_space_choice_space_id = space_id
			game_ui.show_space_choice(
				str(choice_ctx.get("title", space_id)),
				choice_ctx.get("optionEffectsTexts", choice_ctx.get("optionLabels", [])),
				int(choice_ctx.get("slot", 0)),
				choice_ctx.get("optionOriginalIndices", null)
			)
			_refresh_ui()
			return

	var result = turn_controller.take_turn_send_agent(game_state, board_map, space_id, pending_agent_card_id)
	if not bool(result.get("ok", false)):
		push_warning("Card play failed: %s" % str(result.get("reason", "unknown")))
		return

	_clear_pending_agent_play()
	_refresh_ui()

func _on_board_highlighted_spy_post_selected(post_id: String) -> void:
	if turn_controller == null:
		return
	var spy_recall_draw_ctx := turn_controller.get_pending_spy_recall_draw_context(game_state)
	if int(spy_recall_draw_ctx.get("pendingSpyRecallDrawCards", 0)) > 0:
		if _pending_spy_selection_mode != "recall_for_draw":
			_pending_spy_selection_mode = "recall_for_draw"
		var draw_result := turn_controller.resolve_pending_spy_recall_draw(game_state, board_map, post_id)
		if not bool(draw_result.get("ok", false)):
			push_warning("Spy recall-for-draw failed: %s" % str(draw_result.get("reason", "unknown")))
			return
		_pending_spy_selection_mode = ""
		_refresh_ui()
		return

	var spy_ctx := turn_controller.get_pending_spy_context(game_state)
	if int(spy_ctx.get("pendingPlaceSpy", 0)) <= 0:
		return

	if _pending_spy_selection_mode == "recall":
		var recall_result := turn_controller.resolve_pending_spy_recall(game_state, post_id)
		if not bool(recall_result.get("ok", false)):
			push_warning("Spy recall failed: %s" % str(recall_result.get("reason", "unknown")))
			return
		_pending_spy_selection_mode = ""
		_refresh_ui()
		return

	if _pending_spy_selection_mode == "place":
		var place_result := turn_controller.resolve_pending_place_spy(game_state, board_map, post_id)
		if not bool(place_result.get("ok", false)):
			push_warning("Spy placement failed: %s" % str(place_result.get("reason", "unknown")))
			return
		_pending_spy_selection_mode = ""
		_refresh_ui()
		return

	_refresh_ui()

func _on_ui_space_choice_selected(slot: int, option_index: int) -> void:
	if turn_controller == null:
		return
	if slot == CONFLICT_COST_CHOICE_SLOT:
		var accept_choice := option_index == 0
		var choice_result := turn_controller.resolve_pending_conflict_cost_choice(game_state, board_map, accept_choice)
		if not bool(choice_result.get("ok", false)):
			push_warning("Conflict cost choice failed: %s" % str(choice_result.get("reason", "unknown")))
		_refresh_ui()
		return
	if slot == CONFLICT_INFLUENCE_CHOICE_SLOT:
		var pending_ctx := turn_controller.get_pending_conflict_influence_choice_context(game_state)
		var option_factions: Array = pending_ctx.get("optionFactions", [])
		if option_index < 0 or option_index >= option_factions.size():
			_refresh_ui()
			return
		var faction_id := str(option_factions[option_index])
		var choice_result := turn_controller.resolve_pending_conflict_influence_choice(game_state, board_map, faction_id)
		if not bool(choice_result.get("ok", false)):
			push_warning("Conflict influence choice failed: %s" % str(choice_result.get("reason", "unknown")))
		_refresh_ui()
		return
	if slot == CARD_EFFECT_CHOICE_SLOT:
		var pending_card_ctx := turn_controller.get_pending_card_choice_context(game_state)
		var pending_slot := int(pending_card_ctx.get("slot", 0))
		var choice_result := turn_controller.resolve_pending_card_choice(game_state, board_map, pending_slot, int(option_index))
		if not bool(choice_result.get("ok", false)):
			push_warning("Card effect choice failed: %s" % str(choice_result.get("reason", "unknown")))
		_refresh_ui()
		return
	if slot == CONTRACT_CHOICE_SLOT:
		var pending_contract_ctx := turn_controller.get_pending_contract_choice_context(game_state)
		var option_contract_ids: Array = pending_contract_ctx.get("optionContractIds", [])
		if option_index < 0 or option_index >= option_contract_ids.size():
			_refresh_ui()
			return
		var contract_id := str(option_contract_ids[option_index])
		var contract_result := turn_controller.resolve_pending_contract_choice(game_state, board_map, contract_id)
		if not bool(contract_result.get("ok", false)):
			push_warning("Contract choice failed: %s" % str(contract_result.get("reason", "unknown")))
		_refresh_ui()
		return
	if pending_agent_card_id == "" or _pending_space_choice_space_id == "":
		return

	var space_id := _pending_space_choice_space_id
	var context := {
		"choice_indexes": {
			str(slot): option_index
		}
	}
	var result = turn_controller.take_turn_send_agent(game_state, board_map, space_id, pending_agent_card_id, null, context)
	if not bool(result.get("ok", false)):
		push_warning("Card play failed: %s" % str(result.get("reason", "unknown")))
		_pending_space_choice_space_id = space_id
		if board_map.has_method("get_pending_space_choice_context"):
			var ctx: Dictionary = board_map.get_pending_space_choice_context(
				space_id,
				_get_current_player_state(),
				game_state
			)
			if not ctx.is_empty() and not bool(ctx.get("noValidOptions", false)):
				var retry_texts = ctx.get("optionEffectsTexts", ctx.get("optionLabels", []))
				var has_retry_ui := false
				if typeof(retry_texts) == TYPE_PACKED_STRING_ARRAY:
					has_retry_ui = (retry_texts as PackedStringArray).size() > 0
				elif typeof(retry_texts) == TYPE_ARRAY:
					has_retry_ui = (retry_texts as Array).size() > 0
				if has_retry_ui:
					game_ui.show_space_choice(
						str(ctx.get("title", space_id)),
						retry_texts,
						int(ctx.get("slot", 0)),
						ctx.get("optionOriginalIndices", null)
					)
		_refresh_ui()
		return

	_pending_space_choice_space_id = ""
	_clear_pending_agent_play()
	_refresh_ui()

func _on_ui_space_choice_cancel_requested() -> void:
	var pending_cost_ctx := turn_controller.get_pending_conflict_cost_choice_context(game_state) if turn_controller != null else {}
	if not pending_cost_ctx.is_empty():
		var choice_result := turn_controller.resolve_pending_conflict_cost_choice(game_state, board_map, false)
		if not bool(choice_result.get("ok", false)):
			push_warning("Conflict cost choice skip failed: %s" % str(choice_result.get("reason", "unknown")))
		_refresh_ui()
		return
	var pending_influence_ctx := turn_controller.get_pending_conflict_influence_choice_context(game_state) if turn_controller != null else {}
	if not pending_influence_ctx.is_empty():
		_refresh_ui()
		return
	var pending_contract_ctx := turn_controller.get_pending_contract_choice_context(game_state) if turn_controller != null else {}
	if not pending_contract_ctx.is_empty():
		_refresh_ui()
		return
	_clear_pending_agent_play()
	_refresh_ui()

func _on_ui_cancel_card_selection_requested() -> void:
	if turn_controller != null:
		var spy_recall_draw_ctx := turn_controller.get_pending_spy_recall_draw_context(game_state)
		if int(spy_recall_draw_ctx.get("pendingSpyRecallDrawCards", 0)) > 0:
			var skip_result := turn_controller.skip_pending_spy_recall_draw(game_state, board_map)
			if not bool(skip_result.get("ok", false)):
				push_warning("Skip spy recall-for-draw failed: %s" % str(skip_result.get("reason", "unknown")))
			_refresh_ui()
			return
	if pending_agent_card_id == "":
		return
	_clear_pending_agent_play()
	_refresh_ui()

func _on_ui_market_buy_requested(card_id: String) -> void:
	if turn_controller == null:
		return
	if turn_controller.has_pending_player_interaction(game_state) or _pending_space_choice_space_id != "":
		_refresh_ui()
		return
	if card_id == "":
		return
	var buy_result = turn_controller.buy_market_card(game_state, card_id, board_map)
	if not bool(buy_result.get("ok", false)):
		var reason := str(buy_result.get("reason", "unknown"))
		# Not enough persuasion is a normal gameplay case, avoid log spam.
		if reason != "insufficient_persuasion":
			push_warning("Market buy failed: %s" % reason)
	_refresh_ui()

func _on_ui_pending_trash_selected(zone_key: String, card_id: String) -> void:
	if turn_controller == null:
		return
	var result = turn_controller.resolve_pending_trash(game_state, zone_key, card_id)
	if not bool(result.get("ok", false)):
		push_warning("Pending trash resolve failed: %s" % str(result.get("reason", "unknown")))
	_refresh_ui()

func _on_ui_pending_conflict_deploy_selected(amount: int) -> void:
	if turn_controller == null:
		return
	var result = turn_controller.resolve_pending_conflict_deploy(game_state, board_map, amount)
	if not bool(result.get("ok", false)):
		push_warning("Pending conflict deploy resolve failed: %s" % str(result.get("reason", "unknown")))
	_refresh_ui()

func _refresh_ui():
	if game_ui == null:
		return
	game_ui.bind_state(game_state)
	if board_map != null and board_map.has_method("apply_game_state"):
		board_map.apply_game_state(game_state)
	var pending_conflict_influence_choice := turn_controller.get_pending_conflict_influence_choice_context(game_state) if turn_controller != null else {}
	if not pending_conflict_influence_choice.is_empty() and game_ui != null and not game_ui.is_space_choice_open():
		var influence_texts: Array = pending_conflict_influence_choice.get("optionEffectsTexts", [])
		game_ui.show_space_choice(
			str(pending_conflict_influence_choice.get("title", "Conflict reward choose two")),
			influence_texts,
			CONFLICT_INFLUENCE_CHOICE_SLOT
		)
		_sync_pending_spy_selection()
		return
	var pending_conflict_cost_choice := turn_controller.get_pending_conflict_cost_choice_context(game_state) if turn_controller != null else {}
	if not pending_conflict_cost_choice.is_empty() and game_ui != null and not game_ui.is_space_choice_open():
		var option_effects_texts: Array = ["-", "-"]
		var raw_option_texts: Variant = pending_conflict_cost_choice.get("optionEffectsTexts", option_effects_texts)
		if typeof(raw_option_texts) == TYPE_ARRAY:
			option_effects_texts = raw_option_texts
		game_ui.show_space_choice(
			"Conflict reward optional cost",
			option_effects_texts,
			CONFLICT_COST_CHOICE_SLOT
		)
	var pending_card_choice := turn_controller.get_pending_card_choice_context(game_state) if turn_controller != null else {}
	if not pending_card_choice.is_empty() and game_ui != null and not game_ui.is_space_choice_open():
		var card_choice_texts: Variant = pending_card_choice.get("optionEffectsTexts", [])
		game_ui.show_space_choice(
			str(pending_card_choice.get("title", "Card effect choice")),
			card_choice_texts,
			CARD_EFFECT_CHOICE_SLOT,
			pending_card_choice.get("optionOriginalIndices", null)
		)
	var pending_contract_choice := turn_controller.get_pending_contract_choice_context(game_state) if turn_controller != null else {}
	if not pending_contract_choice.is_empty() and game_ui != null and not game_ui.is_space_choice_open():
		var contract_entries: Variant = pending_contract_choice.get("optionEntries", pending_contract_choice.get("optionEffectsTexts", []))
		game_ui.show_space_choice(
			str(pending_contract_choice.get("title", "choose face-up contract")),
			contract_entries,
			CONTRACT_CHOICE_SLOT
		)
	_sync_pending_spy_selection()

	var current_player := _get_current_player_state()
	var has_pending_interaction := turn_controller != null and turn_controller.has_pending_player_interaction(game_state)
	var awaiting_space_choice := _pending_space_choice_space_id != ""
	var popup_vm: Dictionary = {}
	if popup_coordinator != null:
		popup_vm = popup_coordinator.resolve_popup_state(has_pending_interaction, awaiting_space_choice, game_ui.is_space_choice_open())
	var has_pending_spy_recall_draw := false
	if turn_controller != null:
		var spy_recall_draw_ctx := turn_controller.get_pending_spy_recall_draw_context(game_state)
		has_pending_spy_recall_draw = int(spy_recall_draw_ctx.get("pendingSpyRecallDrawCards", 0)) > 0
	var interaction_vm := {
		"isPlayerTurns": str(game_state.get("phase", "")) == "player_turns",
		"waitingForEndTurn": false,
		"canPlayCards": false,
		"canReveal": false,
		"canCancelSelection": false
	}
	if ui_interaction_presenter != null:
		interaction_vm = ui_interaction_presenter.build_view_model(
			game_state,
			current_player,
			pending_agent_card_id,
			has_pending_interaction,
			awaiting_space_choice,
			has_pending_spy_recall_draw
		)
	var is_player_turns := bool(interaction_vm.get("isPlayerTurns", false))
	var waiting_for_end_turn := bool(interaction_vm.get("waitingForEndTurn", false))
	var can_play_cards := bool(interaction_vm.get("canPlayCards", false))
	var can_reveal := bool(interaction_vm.get("canReveal", false))
	var can_cancel_selection := bool(interaction_vm.get("canCancelSelection", false))
	if has_pending_interaction or awaiting_space_choice:
		if interaction_fsm != null:
			interaction_fsm.to_resolving_pending()

	if not is_player_turns and pending_agent_card_id != "":
		_clear_pending_agent_play()
	if has_pending_interaction and pending_agent_card_id != "":
		_clear_pending_agent_play()
	game_ui.set_reveal_enabled(can_reveal)
	game_ui.set_reveal_button_mode(waiting_for_end_turn)
	game_ui.set_cancel_selection_visible(can_cancel_selection)
	game_ui.set_hand_interactable(can_play_cards)
	game_ui.set_market_interactable(not bool(popup_vm.get("needsBlockInput", false)))
	if hud_presenter != null:
		game_ui.set_meta("hud_vm", hud_presenter.build_view_model(game_state))
	if market_presenter != null:
		game_ui.set_meta("market_vm", market_presenter.build_market_view_model(game_state))
	if contracts_presenter != null:
		game_ui.set_meta("contracts_vm", contracts_presenter.build_view_model(game_state))
	GameEvents.state_changed.emit(game_state)
	GameEvents.phase_changed.emit(str(game_state.get("phase", "")))

func _sync_pending_spy_selection() -> void:
	if turn_controller == null or board_map == null:
		return
	var phase := str(game_state.get("phase", ""))
	if phase != "player_turns" and phase != "conflict":
		_pending_spy_selection_mode = ""
		board_map.clear_highlighted_spy_posts()
		GameEvents.spy_selection_state_changed.emit(false, "", 0)
		return
	var spy_ctx := turn_controller.get_pending_spy_context(game_state)
	var spy_recall_draw_ctx := turn_controller.get_pending_spy_recall_draw_context(game_state)
	var pending_spy_recall_draw_cards := int(spy_recall_draw_ctx.get("pendingSpyRecallDrawCards", 0))
	if pending_spy_recall_draw_cards > 0:
		_pending_spy_selection_mode = "recall_for_draw"
		board_map.set_highlighted_spy_posts(spy_recall_draw_ctx.get("postIds", []))
		GameEvents.spy_selection_state_changed.emit(true, _pending_spy_selection_mode, pending_spy_recall_draw_cards)
		return
	var pending_spy := int(spy_ctx.get("pendingPlaceSpy", 0))
	if pending_spy <= 0:
		_pending_spy_selection_mode = ""
		board_map.clear_highlighted_spy_posts()
		GameEvents.spy_selection_state_changed.emit(false, "", 0)
		return

	var is_at_cap := bool(spy_ctx.get("isAtCap", false))
	if is_at_cap:
		_pending_spy_selection_mode = "recall"
		board_map.set_highlighted_spy_posts(spy_ctx.get("ownedSpyPostIds", []))
	else:
		_pending_spy_selection_mode = "place"
		board_map.set_highlighted_spy_posts(spy_ctx.get("availableSpyPostIds", []))
	GameEvents.spy_selection_state_changed.emit(true, _pending_spy_selection_mode, pending_spy)

func _get_current_player_state() -> Dictionary:
	var players = game_state.get("players", [])
	if typeof(players) != TYPE_ARRAY:
		return {}
	var current_player_id := str(game_state.get("currentPlayerId", ""))
	for player in players:
		if typeof(player) != TYPE_DICTIONARY:
			continue
		if str(player.get("id", "")) == current_player_id:
			return player
	return {}

func _get_playable_space_ids_for_card(player: Dictionary, card_id: String) -> Array:
	var cards_by_id: Dictionary = game_state.get("cardsById", {})
	if not cards_by_id.has(card_id):
		return []
	var card_def_raw = cards_by_id[card_id]
	if typeof(card_def_raw) != TYPE_DICTIONARY:
		return []

	var played_card: Dictionary = card_def_raw.duplicate(true)
	played_card["id"] = card_id

	var board_occupancy: Dictionary = game_state.get("boardOccupancy", {})
	var board_spaces: Dictionary = board_map.board_spaces_by_id
	var space_ids: Array = board_spaces.keys()
	space_ids.sort()
	var playable: Array = []

	for raw_space_id in space_ids:
		var space_id := str(raw_space_id)
		var can_place = board_map.can_place_agent(space_id, player, board_occupancy, played_card, game_state)
		if bool(can_place.get("ok", false)):
			playable.append(space_id)
	return playable

func _clear_pending_agent_play() -> void:
	pending_agent_card_id = ""
	_pending_space_choice_space_id = ""
	if interaction_fsm != null:
		interaction_fsm.to_idle()
	if game_ui != null:
		game_ui.hide_space_choice()
	if board_map != null:
		board_map.clear_highlighted_spaces()
		if turn_controller == null or int(turn_controller.get_pending_spy_context(game_state).get("pendingPlaceSpy", 0)) <= 0:
			board_map.clear_highlighted_spy_posts()

func _build_player_state(player_id, seat_index, agents_available, spice, water, starter_deck_template):
	var deck: Array = deck_service.create_shuffled_deck_from_template(starter_deck_template)

	return {
		"id": player_id,
		"name": player_id,
		"leaderName": player_id.to_upper(),
		"leaderPortrait": "",
		"seatIndex": seat_index,
		"agentsTotal": max(agents_available, 0),
		"agentsAvailable": agents_available,
		"agentsOnBoard": [],
		"resources": {
			"solari": 0,
			"spice": spice,
			"water": water
		},
		"vp": 0,
		"influence": {
			"emperor": 0,
			"guild": 0,
			"beneGesserit": 0,
			"fremen": 0
		},
		"influenceVpClaimed": {
			"emperor": false,
			"guild": false,
			"beneGesserit": false,
			"fremen": false
		},
		"alliances": {
			"emperor": false,
			"guild": false,
			"beneGesserit": false,
			"fremen": false
		},
		"allianceVpBonus": 0,
		"deck": deck,
		"hand": [],
		"intrigue": [],
		"discard": [],
		"inPlay": [],
		"intrigueCount": 0,
		"persuasion": 0,
		"revealedSwordPower": 0,
		"sandwormsInConflict": 0,
		"garrisonTroops": 3,
		"troopsInConflict": 0,
		"pendingConflictDeployMax": 0,
		"pendingConflictDeployFromEffect": 0,
		"pendingConflictDeployFromGarrison": 0,
		"pendingSummonSandworm": 0,
		"pendingPlaceSpy": 0,
		"pendingSpyRecallDrawCards": 0,
		"pendingSpyRecallDrawGrantCards": 0,
		"pendingSpyRecallRewardEffects": [],
		"pendingSpyRecallDrawPostIds": [],
		"pendingSpyRecallDrawSpaceId": "",
		"pendingCardChoice": {},
		"pendingContractChoice": {},
		"pendingTrashQueue": [],
		"pendingInteractions": [],
		"hasMakerHooks": false,
		"completedContracts": 0,
		"contractsOwned": [],
		"contractsCompleted": [],
		"objectiveCards": [],
		"wonConflictCards": [],
		"pendingContracts": 0,
		"turnFlags": {
			"sent_agent_to_maker_space_this_turn": false,
			"sent_agent_to_faction_space_this_turn": false,
			"recalled_spy_this_turn": false
		},
		"flags": {
			"has_high_council_seat": false
		},
		"passedReveal": false
	}

func _resolve_starting_player_ids() -> Array:
	var ids: Array = []
	var normalized_count := clampi(player_count, 2, STARTING_PLAYER_IDS.size())
	for i in range(normalized_count):
		ids.append(str(STARTING_PLAYER_IDS[i]))
	return ids

func _build_objective_setup() -> Dictionary:
	var defs: Dictionary = objective_repository.get_all_by_id()
	var deck: Array = defs.keys()
	deck.sort()
	deck_service.shuffle_array(deck)
	return {"defs": defs, "deck": deck}

func _apply_objective_deal(players: Array, objective_setup: Dictionary) -> void:
	if typeof(players) != TYPE_ARRAY or players.is_empty():
		return
	var defs_raw: Variant = objective_setup.get("defs", {})
	var defs: Dictionary = defs_raw if typeof(defs_raw) == TYPE_DICTIONARY else {}
	var deck_raw: Variant = objective_setup.get("deck", [])
	var deck: Array = deck_raw if typeof(deck_raw) == TYPE_ARRAY else []
	for player_raw in players:
		if typeof(player_raw) != TYPE_DICTIONARY:
			continue
		var player: Dictionary = player_raw
		player["objectiveCards"] = []
		if deck.is_empty():
			continue
		var objective_id := str(deck.pop_back())
		var objective_def_raw: Variant = defs.get(objective_id, {})
		var objective_def: Dictionary = objective_def_raw if typeof(objective_def_raw) == TYPE_DICTIONARY else {}
		player["objectiveCards"] = [{
			"id": objective_id,
			"battleIcon": str(objective_def.get("battleIcon", "")),
			"faceUp": true
		}]
	objective_setup["deck"] = deck

func _build_starter_deck_template(cards_by_id):
	var starter_cards: Array = []
	if typeof(cards_by_id) != TYPE_DICTIONARY:
		return starter_cards

	for card_id in cards_by_id.keys():
		var card_def = cards_by_id[card_id]
		if typeof(card_def) != TYPE_DICTIONARY:
			continue
		if not bool(card_def.get("starter", false)):
			continue

		var starter_count = int(card_def.get("starterCount", 1))
		for _i in range(max(starter_count, 0)):
			starter_cards.append(str(card_id))

	if starter_cards.is_empty():
		push_warning("GameRoot: no starter cards marked in cards_uprising.json")

	return starter_cards

func _build_conflict_setup_10_rounds() -> Dictionary:
	# Setup pattern from rulebook:
	# 1 Conflict I + 5 Conflict II + 4 Conflict III = 10 cards.
	var all_cards: Array = []
	var cached_defs: Dictionary = conflict_repository.get_all_by_id()
	for card_id in cached_defs.keys():
		var raw: Variant = cached_defs.get(card_id, {})
		if typeof(raw) == TYPE_DICTIONARY:
			all_cards.append((raw as Dictionary).duplicate(true))
	var defs: Dictionary = {}
	var pool_i: Array = []
	var pool_ii: Array = []
	var pool_iii: Array = []

	for entry in all_cards:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var card_id := str(entry.get("id", ""))
		if card_id == "":
			continue

		defs[card_id] = entry
		var level := str(entry.get("level", "")).to_upper()
		if level == "I":
			pool_i.append(entry)
		elif level == "II":
			pool_ii.append(entry)
		elif level == "III":
			pool_iii.append(entry)

	deck_service.shuffle_array(pool_i)
	deck_service.shuffle_array(pool_ii)
	deck_service.shuffle_array(pool_iii)

	var selected_i: Array = []
	var selected_ii: Array = []
	var selected_iii: Array = []
	if not pool_i.is_empty():
		selected_i.append(pool_i[0])
	for idx in range(min(5, pool_ii.size())):
		selected_ii.append(pool_ii[idx])
	for idx in range(min(4, pool_iii.size())):
		selected_iii.append(pool_iii[idx])

	var deck: Array = []
	for entry in selected_iii:
		deck.append(str(entry.get("id", "")))
	for entry in selected_ii:
		deck.append(str(entry.get("id", "")))
	for entry in selected_i:
		deck.append(str(entry.get("id", "")))

	return {"deck": deck, "defs": defs}

func _build_intrigue_setup() -> Dictionary:
	var by_id: Dictionary = intrigue_repository.get_all_by_id()
	var deck: Array = []
	for card_id in by_id.keys():
		deck.append(str(card_id))
	deck_service.shuffle_array(deck)
	return {"deck": deck, "defs": by_id}

func _build_imperium_setup(cards_by_id: Dictionary) -> Dictionary:
	var imperium_deck: Array = []
	var reserve_cards := {
		"preparations": [],
		"spiceMustFlow": []
	}

	if typeof(cards_by_id) != TYPE_DICTIONARY:
		return {"deck": imperium_deck, "market": [], "reserve": reserve_cards}

	for card_id in cards_by_id.keys():
		var card_def = cards_by_id[card_id]
		if typeof(card_def) != TYPE_DICTIONARY:
			continue
		if bool(card_def.get("starter", false)):
			continue

		var source := str(card_def.get("source", "imperium"))
		if source == "reserve":
			var reserve_count := maxi(1, int(card_def.get("reserveCount", 1)))
			var tags = card_def.get("tags", [])
			if typeof(tags) == TYPE_ARRAY and tags.has("spice_must_flow"):
				for _i in range(reserve_count):
					reserve_cards["spiceMustFlow"].append(str(card_id))
			else:
				for _i in range(reserve_count):
					reserve_cards["preparations"].append(str(card_id))
			continue

		imperium_deck.append(str(card_id))

	deck_service.shuffle_array(imperium_deck)
	var market: Array = []
	for _i in range(min(5, imperium_deck.size())):
		market.append(str(imperium_deck.pop_back()))

	return {
		"deck": imperium_deck,
		"market": market,
		"reserve": reserve_cards
	}
