class_name FactionPhasesSequence

## 阵营阶段 — 每个阵营一个阶段

var _phases: Array = []

func _init(p_faction_count: int = 2) -> void:
	for i in range(p_faction_count):
		_phases.append(TurnPhaseConfig.new("Faction_%d" % i, true, false))

func get_phases() -> Array:
	return _phases
