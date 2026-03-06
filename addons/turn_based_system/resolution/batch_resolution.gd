class_name BatchResolution

## 批量结算 — 收集一方所有行动后批量执行

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
