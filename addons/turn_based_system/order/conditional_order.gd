class_name ConditionalOrder

## 弱点连锁制 — 女神异闻录/真女神转生

var _queue: Array = []
var _granted_extra: bool = false

func get_next(_ctx: TurnContext):
	if _queue.is_empty():
		return null
	_granted_extra = false
	var step := TurnStep.new()
	step.unit = _queue.pop_front()
	return step

func on_round_start(ctx: TurnContext) -> void:
	_queue.clear()
	for faction in ctx.factions:
		for unit in faction.get_active_units():
			_queue.append(unit)
	_queue.sort_custom(func(a, b): return a.initiative > b.initiative)

func on_action_resolved(ctx: TurnContext, result: int) -> void:
	if result == TurnEnums.ActionResult.CRITICAL and ctx.active_unit != null and not _granted_extra:
		_queue.push_front(ctx.active_unit)
		_granted_extra = true

func reset() -> void:
	_queue.clear()
	_granted_extra = false
