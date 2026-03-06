class_name FactionRoundRobin

## 阵营全体行动 — 火焰纹章/XCOM

var _faction_count: int
var _current_faction_index: int = 0

func _init(p_faction_count: int = 2) -> void:
	_faction_count = p_faction_count

func get_next(ctx: TurnContext):
	var factions: Array = ctx.factions
	if _current_faction_index >= factions.size():
		return null
	var step := TurnStep.new()
	step.faction = factions[_current_faction_index]
	_current_faction_index += 1
	return step

func on_round_start(_ctx: TurnContext) -> void:
	_current_faction_index = 0

func on_action_resolved(_ctx: TurnContext, _result: int) -> void:
	pass

func reset() -> void:
	_current_faction_index = 0
