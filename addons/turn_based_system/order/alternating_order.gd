class_name AlternatingOrder

## 双方严格交替 — 象棋/围棋

var _current_index: int = 0
var _acted: bool = false

func get_next(ctx: TurnContext):
	if _acted:
		return null
	_acted = true
	var factions: Array = ctx.factions
	if factions.is_empty():
		return null
	var faction = factions[_current_index % factions.size()]
	var units: Array = faction.get_active_units()
	if units.is_empty():
		return null
	var step := TurnStep.new()
	step.unit = units[0]
	step.faction = faction
	return step

func on_round_start(_ctx: TurnContext) -> void:
	_acted = false

func on_action_resolved(_ctx: TurnContext, _result: int) -> void:
	_current_index += 1

func reset() -> void:
	_current_index = 0
	_acted = false
