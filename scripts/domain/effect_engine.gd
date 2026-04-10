extends RefCounted
class_name EffectEngine

const EffectResolverScript = preload("res://scripts/effect_resolver.gd")
const EffectDslScript = preload("res://scripts/domain/effect_dsl.gd")
const EffectTextTokensScript = preload("res://scripts/domain/effect_text_tokens.gd")

var _resolver := EffectResolverScript.new()


func normalize_effects(effects: Variant) -> Array:
	return EffectDslScript.normalize_effects_with_aliases(effects)


func format_effects_board(effects: Variant, space_area_id: String = "") -> String:
	return EffectTextTokensScript.effects_to_text_board(effects, space_area_id)


func format_effects_card_with_skips(
	effects: Variant,
	skip_persuasion: bool = false,
	skip_sword: bool = false,
	skip_draw_cards: bool = false,
	skip_recruit_troops: bool = false,
	skip_draw_intrigue: bool = false,
	skip_trash_card: bool = false,
	skip_gain_resource: bool = false,
	skip_spend_resource: bool = false,
	skip_gain_influence: bool = false,
	skip_vp: bool = false,
	skip_get_contract: bool = false,
	skip_summon_sandworm: bool = false,
	skip_maker_space_conditional_if: bool = false,
	skip_place_spy: bool = false
) -> String:
	return EffectTextTokensScript.effects_to_text_card_with_skips(
		effects,
		skip_persuasion,
		skip_sword,
		skip_draw_cards,
		skip_recruit_troops,
		skip_draw_intrigue,
		skip_trash_card,
		skip_gain_resource,
		skip_spend_resource,
		skip_gain_influence,
		skip_vp,
		skip_get_contract,
		skip_summon_sandworm,
		skip_maker_space_conditional_if,
		skip_place_spy
	)

func execute(
	effects: Variant,
	player_state: Dictionary,
	game_state: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	if typeof(effects) != TYPE_ARRAY:
		return {"ok": true, "applied": 0}
	var fx: Array = effects
	if fx.is_empty():
		return {"ok": true, "applied": 0}

	var applied := 0
	for entry in fx:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if _resolver.apply_single_effect(entry, player_state, game_state, context):
			applied += 1
	return {"ok": true, "applied": applied}
