class_name AllAtOnce

## 同时行动制 — 文明多人/Into the Breach

var _done: bool = false

func get_next(_ctx: TurnContext):
	if _done:
		return null
	_done = true
	var step := TurnStep.new()
	step.is_simultaneous = true
	return step

func on_round_start(_ctx: TurnContext) -> void:
	_done = false

func on_action_resolved(_ctx: TurnContext, _result: int) -> void:
	pass

func reset() -> void:
	_done = false
