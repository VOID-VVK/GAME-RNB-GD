class_name SingleAction

## 单次行动预算 — 每回合 1 次行动

var _acted: Dictionary = {}

func refill_budget(unit) -> void:
	_acted.erase(unit.unit_id)

func can_act(unit) -> bool:
	return not _acted.has(unit.unit_id)

func spend(unit, _cost: int) -> void:
	_acted[unit.unit_id] = true

func grant_extra(unit, _amount: int) -> void:
	_acted.erase(unit.unit_id)
