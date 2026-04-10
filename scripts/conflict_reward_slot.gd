extends PanelContainer
class_name ConflictRewardSlot

@onready var rank_label: Label = %RankLabel
@onready var reward_row: HBoxContainer = %RewardRow


func set_rank_text(value: String) -> void:
	if rank_label == null:
		return
	rank_label.text = value


func set_reward_tokens(tokens_text: String) -> void:
	if reward_row == null:
		return
	EffectsTokenRow.populate(reward_row, tokens_text)


func apply_reward_slot_panel_style(style: StyleBoxFlat) -> void:
	if style == null:
		return
	add_theme_stylebox_override("panel", style)


func apply_rank_label_color(color: Color) -> void:
	if rank_label == null:
		return
	rank_label.add_theme_color_override("font_color", color)
