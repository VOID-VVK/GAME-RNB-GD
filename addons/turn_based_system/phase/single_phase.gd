class_name SinglePhaseSequence

## 单阶段 — 象棋/Initiative/ATB/Tick

func get_phases() -> Array:
	return [TurnPhaseConfig.new("Main", true, false)]
