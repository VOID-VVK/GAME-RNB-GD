class_name ImmediateResolution

## 立即结算 — 提交即执行

var has_pending: bool:
	get: return false

func submit(action, _ctx: TurnContext) -> int:
	return action.execute()

func resolve_all(_ctx: TurnContext) -> void:
	pass
