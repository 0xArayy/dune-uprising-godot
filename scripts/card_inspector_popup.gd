class_name CardInspectorPopup
extends PanelContainer

@onready var close_button: Button = %CloseButton
@onready var card_ui: CardUI = %InspectorCard

func _ready() -> void:
	visible = false
	if close_button != null:
		close_button.pressed.connect(hide_popup)
	if card_ui != null:
		card_ui.disabled = true

func show_card(card_data: Dictionary) -> void:
	if card_ui == null:
		return
	card_ui.card_data = card_data.duplicate(true)
	card_ui.disabled = true
	visible = true

func hide_popup() -> void:
	visible = false
