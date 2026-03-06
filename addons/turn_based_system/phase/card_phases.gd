class_name CardPhasesSequence

## 卡牌阶段 — 抽牌/主阶段/弃牌/结束

func get_phases() -> Array:
	return [
		TurnPhaseConfig.new("Draw", false, true),
		TurnPhaseConfig.new("Main", true, false),
		TurnPhaseConfig.new("Discard", false, true),
		TurnPhaseConfig.new("End", false, true),
	]
