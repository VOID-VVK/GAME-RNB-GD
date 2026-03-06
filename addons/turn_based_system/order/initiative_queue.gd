class_name InitiativeQueue

## 速度先攻制 — 博德之门3/FFX CTB

var _recalc_after_action: bool
var _queue: Array = []
var _acted: bool = false

func _init(p_recalc_after_action: bool = false) -> void:
	_recalc_after_action = p_recalc_after_action

func get_next(_ctx: TurnContext):
	if _acted and not _recalc_after_action:
		return null
	if _queue.is_empty():
		return null
	_acted = true
	var unit = _queue.pop_front()
	var step := TurnStep.new()
	step.unit = unit
	return step

func on_round_start(ctx: TurnContext) -> void:
	_acted = false
	_rebuild_queue(ctx)

func on_action_resolved(_ctx: TurnContext, _result: int) -> void:
	if _recalc_after_action:
		_acted = false

func _rebuild_queue(ctx: TurnContext) -> void:
	_queue.clear()
	for faction in ctx.factions:
		for unit in faction.get_active_units():
			_queue.append(unit)
	_queue.sort_custom(func(a, b): return a.initiative > b.initiative)

func reset() -> void:
	_queue.clear()
	_acted = false
