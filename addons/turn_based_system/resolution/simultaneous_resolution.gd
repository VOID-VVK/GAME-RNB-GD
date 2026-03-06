class_name SimultaneousResolution

## 同时结算 — 所有方规划完毕后同时结算

var _pending: Array = []

var has_pending: bool:
	get: return _pending.size() > 0

func submit(action, _ctx: TurnContext) -> int:
	_pending.append(action)
	return TurnEnums.ActionResult.SUCCESS

func resolve_all(_ctx: TurnContext) -> void:
	for action in _pending:
		action.execute()
	_pending.clear()
