extends SceneTree

const RuleContractRegressionScript = preload("res://scripts/testing/rule_contract_regression.gd")

func _initialize() -> void:
	var regression: RuleContractRegression = RuleContractRegressionScript.new()
	var result: Dictionary = regression.run_all_checks()
	if bool(result.get("ok", false)):
		print("HEADLESS_REGRESSION_OK")
		quit(0)
		return
	push_error("HEADLESS_REGRESSION_FAIL: %s" % JSON.stringify(result))
	quit(1)
