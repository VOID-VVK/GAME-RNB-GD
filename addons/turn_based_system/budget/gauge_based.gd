class_name GaugeBasedBudget

## ATB gauge 预算 — gauge 满 = 1 次行动，行动后清零

var _acted: Dictionary = {}

func refill_budget(unit) -> void:
	_acted.erase(unit.unit_id)

func can_act(unit) -> bool:
	return not _acted.has(unit.unit_id) and unit.atb_gauge >= 1.0

func spend(unit, _cost: int) -> void:
	unit.atb_gauge = 0.0
	_acted[unit.unit_id] = true

func grant_extra(unit, _amount: int) -> void:
	_acted.erase(unit.unit_id)
