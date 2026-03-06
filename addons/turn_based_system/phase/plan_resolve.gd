class_name PlanResolveSequence

## 规划-结算阶段 — 同时行动制

func get_phases() -> Array:
	return [
		TurnPhaseConfig.new("Planning", true, false),
		TurnPhaseConfig.new("Resolution", false, true),
	]
