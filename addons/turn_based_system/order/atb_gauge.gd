class_name ATBGaugeOrder

## ATB 半即时制 — FF4~FF9

var _gauge_speed: float
var _ready_unit = null

func _init(p_gauge_speed: float = 1.0) -> void:
	_gauge_speed = p_gauge_speed

func get_next(ctx: TurnContext):
	if _ready_unit != null:
		var step := TurnStep.new()
		step.unit = _ready_unit
		_ready_unit = null
		return step

	var all_units: Array = []
	for faction in ctx.factions:
		for unit in faction.get_active_units():
			if unit.is_active:
				all_units.append(unit)

	for unit in all_units:
		unit.atb_gauge += _gauge_speed * unit.initiative * 0.01
		if unit.atb_gauge >= 1.0:
			_ready_unit = unit
			break

	if _ready_unit != null:
		var step := TurnStep.new()
		step.unit = _ready_unit
		_ready_unit = null
		return step
	return null

func on_round_start(_ctx: TurnContext) -> void:
	pass

func on_action_resolved(ctx: TurnContext, _result: int) -> void:
	if ctx.active_unit != null:
		ctx.active_unit.atb_gauge = 0.0

func reset() -> void:
	_ready_unit = null
