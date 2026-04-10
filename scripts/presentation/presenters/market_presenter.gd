extends RefCounted
class_name MarketPresenter

func build_market_view_model(game_state: Dictionary) -> Dictionary:
	var market_raw: Variant = game_state.get("imperiumMarket", [])
	var market: Array = market_raw if typeof(market_raw) == TYPE_ARRAY else []
	return {"cards": market}
