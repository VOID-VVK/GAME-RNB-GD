class_name TickOrder

## Roguelike 滴答制 — 玩家动一步，所有敌人各动一步

var _queue: Array = []

func get_next(_ctx: TurnContext):
	if _queue.is_empty():
		return null
	var step := TurnStep.new()
	step.unit = _queue.pop_front()
	return step

func on_round_start(ctx: TurnContext) -> void:
	_queue.clear()
	var player_factions: Array = []
	var other_factions: Array = []
	for faction in ctx.factions:
		if faction.is_player_controlled:
			player_factions.append(faction)
		else:
			other_factions.append(faction)
	for faction in player_factions:
		_queue.append_array(faction.get_active_units())
	for faction in other_factions:
		_queue.append_array(faction.get_active_units())

func on_action_resolved(_ctx: TurnContext, _result: int) -> void:
	pass

func reset() -> void:
	_queue.clear()
