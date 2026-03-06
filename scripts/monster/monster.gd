class_name Monster
extends Character

## 怪物类
## 组合 Character，添加怪物特有逻辑

enum AIType {
	AGGRESSIVE,  # 激进型：优先攻击血量最低的目标
	DEFENSIVE,   # 防御型：优先攻击威胁最高的目标
	RANDOM       # 随机型：随机选择目标
}

var ai_type: AIType = AIType.AGGRESSIVE

func _init(p_unit_id: String, p_name: String, p_ai_type: AIType = AIType.AGGRESSIVE) -> void:
	# 创建怪物属性（较低的基础属性）
	var monster_stats = CharacterStats.new(80, 15, 3, 12)
	super(p_unit_id, "monster", p_name, monster_stats)
	ai_type = p_ai_type

## 怪物 AI 行为
func execute_ai(targets: Array[Character]) -> void:
	if not stats.is_alive:
		return

	var target = _select_target(targets)
	if target:
		attack_target(target)

## 根据 AI 类型选择目标
func _select_target(targets: Array[Character]) -> Character:
	var valid_targets = targets.filter(func(t): return t.stats.is_alive)
	if valid_targets.is_empty():
		return null

	match ai_type:
		AIType.AGGRESSIVE:
			# 选择血量最低的目标
			valid_targets.sort_custom(func(a, b): return a.stats.current_hp < b.stats.current_hp)
			return valid_targets[0]
		AIType.DEFENSIVE:
			# 选择攻击力最高的目标
			valid_targets.sort_custom(func(a, b): return a.stats.attack > b.stats.attack)
			return valid_targets[0]
		AIType.RANDOM:
			# 随机选择
			return valid_targets[randi() % valid_targets.size()]
		_:
			return valid_targets[0]
