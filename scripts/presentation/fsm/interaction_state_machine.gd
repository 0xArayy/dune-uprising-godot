extends RefCounted
class_name InteractionStateMachine

enum State {
	IDLE,
	SELECTING_CARD,
	SELECTING_SPACE,
	RESOLVING_PENDING
}

var _state: State = State.IDLE

func current_state() -> State:
	return _state

func to_idle() -> void:
	_state = State.IDLE

func to_selecting_card() -> void:
	_state = State.SELECTING_CARD

func to_selecting_space() -> void:
	_state = State.SELECTING_SPACE

func to_resolving_pending() -> void:
	_state = State.RESOLVING_PENDING
