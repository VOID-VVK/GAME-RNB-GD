class_name TurnSystemConfig

## 四维组合配置 — 定义一个回合制系统的完整行为
## 各策略对象遵循鸭子类型约定（无接口）

var order_resolver  ## ITurnOrderResolver
var action_budget   ## IActionBudget
var resolution_policy  ## IResolutionPolicy
var phase_sequence  ## ITurnPhaseSequence

func _init(
	p_order_resolver,
	p_action_budget,
	p_resolution_policy,
	p_phase_sequence,
) -> void:
	order_resolver = p_order_resolver
	action_budget = p_action_budget
	resolution_policy = p_resolution_policy
	phase_sequence = p_phase_sequence
