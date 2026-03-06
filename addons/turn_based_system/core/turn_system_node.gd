class_name TurnSystemNode
extends Node

## 回合制编排器 — 驱动整个回合循环
##
## 鸭子类型约定：
## ITurnUnit:  unit_id, faction_id, initiative, atb_gauge, is_active, on_turn_start(), on_turn_end()
## ITurnFaction: faction_id, order, is_player_controlled, get_active_units() -> Array
## ITurnAction: action_name, cost, actor(ITurnUnit), execute() -> TurnEnums.ActionResult

# ==================== 信号 ====================
signal round_started(round_number: int)
signal round_ended(round_number: int)
signal phase_changed(phase_name: String)
signal unit_turn_started(unit_id: String)
signal unit_turn_ended(unit_id: String)
signal faction_turn_started(faction_id: String)
signal faction_turn_ended(faction_id: String)
signal action_resolved(unit_id: String, action_name: String, result: int)
signal timeline_changed
signal budget_changed(unit_id: String, remaining: int)

# ==================== 四维策略 ====================
var _order_resolver = null
var _action_budget = null
var _resolution_policy = null
var _phase_sequence = null

# ==================== 状态 ====================
var _factions: Array = []
var _ctx: TurnContext = TurnContext.new()
var _running: bool = false

# ==================== 回调 ====================
## Callable(ctx: TurnContext, step: TurnStep) -> ITurnAction 或 null
var on_player_input: Callable = Callable()
## Callable(ctx: TurnContext, step: TurnStep) -> Array[ITurnAction]
var on_ai_decision: Callable = Callable()
## Callable(action: ITurnAction, result: int) -> void
var on_animate: Callable = Callable()
## Callable(results: Array[{action, result}]) -> void
var on_animate_batch: Callable = Callable()
## Callable(ctx: TurnContext) -> void
var on_phase_enter: Callable = Callable()
## Callable(ctx: TurnContext) -> void
var on_phase_exit: Callable = Callable()

var context: TurnContext:
	get: return _ctx
var is_running: bool:
	get: return _running

func configure(config: TurnSystemConfig) -> void:
	_order_resolver = config.order_resolver
	_action_budget = config.action_budget
	_resolution_policy = config.resolution_policy
	_phase_sequence = config.phase_sequence

func register_faction(faction) -> void:
	_factions.append(faction)

func execute_round() -> void:
	if _running:
		return
	_running = true

	_ctx.round_number += 1
	_ctx.factions = _factions.duplicate()
	_order_resolver.on_round_start(_ctx)
	round_started.emit(_ctx.round_number)

	var phases: Array = _phase_sequence.get_phases()
	for phase in phases:
		_ctx.current_phase_name = phase.phase_name
		phase_changed.emit(phase.phase_name)
		if on_phase_enter.is_valid():
			on_phase_enter.call(_ctx)

		if phase.is_automatic:
			if on_phase_exit.is_valid():
				on_phase_exit.call(_ctx)
			continue

		if phase.allow_actions:
			_execute_phase_actions()

		if on_phase_exit.is_valid():
			on_phase_exit.call(_ctx)

	round_ended.emit(_ctx.round_number)
	_running = false

func _execute_phase_actions() -> void:
	while true:
		var step = _order_resolver.get_next(_ctx)
		if step == null:
			break
		if step.unit != null:
			_execute_unit_step(step)
		elif step.faction != null:
			_execute_faction_step(step)
		elif step.is_simultaneous:
			_execute_simultaneous_step(step)

func _execute_unit_step(step: TurnStep) -> void:
	var unit = step.unit
	_ctx.active_unit = unit
	_action_budget.refill_budget(unit)
	unit.on_turn_start()
	unit_turn_started.emit(unit.unit_id)

	while _action_budget.can_act(unit):
		var action = _get_action(step)
		if action == null:
			break
		var result: int = _resolution_policy.submit(action, _ctx)
		_action_budget.spend(unit, action.cost)
		_order_resolver.on_action_resolved(_ctx, result)
		action_resolved.emit(unit.unit_id, action.action_name, result)
		if on_animate.is_valid():
			on_animate.call(action, result)

	unit.on_turn_end()
	unit_turn_ended.emit(unit.unit_id)
	_ctx.active_unit = null

func _execute_faction_step(step: TurnStep) -> void:
	var faction = step.faction
	_ctx.active_faction = faction
	faction_turn_started.emit(faction.faction_id)

	for unit in faction.get_active_units():
		_action_budget.refill_budget(unit)

	if faction.is_player_controlled and on_player_input.is_valid():
		for unit in faction.get_active_units():
			_ctx.active_unit = unit
			unit.on_turn_start()
			var action = on_player_input.call(_ctx, step)
			if action != null:
				var result: int = _resolution_policy.submit(action, _ctx)
				_action_budget.spend(unit, action.cost)
				_order_resolver.on_action_resolved(_ctx, result)
				action_resolved.emit(unit.unit_id, action.action_name, result)
				if on_animate.is_valid():
					on_animate.call(action, result)
			unit.on_turn_end()
	elif on_ai_decision.is_valid():
		var actions: Array = on_ai_decision.call(_ctx, step)
		if actions.size() > 0:
			var results: Array = []
			for action in actions:
				var result: int = _resolution_policy.submit(action, _ctx)
				results.append({"action": action, "result": result})
			_resolution_policy.resolve_all(_ctx)
			if on_animate_batch.is_valid():
				on_animate_batch.call(results)
			elif on_animate.is_valid():
				for r in results:
					on_animate.call(r.action, r.result)

	faction_turn_ended.emit(faction.faction_id)
	_ctx.active_faction = null

func _execute_simultaneous_step(step: TurnStep) -> void:
	for faction in _factions:
		_ctx.active_faction = faction
		if faction.is_player_controlled and on_player_input.is_valid():
			var action = on_player_input.call(_ctx, step)
			if action != null:
				_resolution_policy.submit(action, _ctx)
		elif on_ai_decision.is_valid():
			var actions: Array = on_ai_decision.call(_ctx, step)
			for action in actions:
				_resolution_policy.submit(action, _ctx)
	_resolution_policy.resolve_all(_ctx)
	_ctx.active_faction = null

func _get_action(step: TurnStep):
	var unit = step.unit
	var faction = null
	for f in _factions:
		if f.faction_id == unit.faction_id:
			faction = f
			break
	if faction == null:
		return null
	if faction.is_player_controlled and on_player_input.is_valid():
		return on_player_input.call(_ctx, step)
	if on_ai_decision.is_valid():
		var actions: Array = on_ai_decision.call(_ctx, step)
		return actions[0] if actions.size() > 0 else null
	return null

func reset() -> void:
	_ctx = TurnContext.new()
	_factions.clear()
	if _order_resolver != null:
		_order_resolver.reset()
	_running = false
