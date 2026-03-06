class_name ActionPointsBudget

## 行动点数预算 — 杀戮尖塔/神界原罪2

var _default_ap: int
var _remaining: Dictionary = {}

func _init(p_default_ap: int = 3) -> void:
	_default_ap = p_default_ap

func refill_budget(unit) -> void:
	_remaining[unit.unit_id] = _default_ap

func can_act(unit) -> bool:
	return _remaining.get(unit.unit_id, 0) > 0

func spend(unit, cost: int) -> void:
	if _remaining.has(unit.unit_id):
		_remaining[unit.unit_id] -= cost

func grant_extra(unit, amount: int) -> void:
	if _remaining.has(unit.unit_id):
		_remaining[unit.unit_id] += amount

func get_remaining(unit_id: String) -> int:
	return _remaining.get(unit_id, 0)
