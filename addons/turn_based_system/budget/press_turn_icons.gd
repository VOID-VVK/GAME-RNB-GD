class_name PressTurnIconsBudget

## Press Turn 图标预算 — 女神异闻录

var _icons_per_turn: int
var _icons: Dictionary = {}

func _init(p_icons_per_turn: int = 4) -> void:
	_icons_per_turn = p_icons_per_turn

func refill_budget(unit) -> void:
	_icons[unit.unit_id] = float(_icons_per_turn)

func can_act(unit) -> bool:
	return _icons.get(unit.unit_id, 0.0) >= 0.5

func spend(unit, cost: int) -> void:
	if _icons.has(unit.unit_id):
		_icons[unit.unit_id] -= cost

func grant_extra(unit, _amount: int) -> void:
	if _icons.has(unit.unit_id):
		_icons[unit.unit_id] += 0.5

func get_remaining_icons(unit_id: String) -> float:
	return _icons.get(unit_id, 0.0)
