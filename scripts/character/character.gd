class_name Character
extends RefCounted

## 人物核心类
## 实现 ITurnUnit 鸭子类型约定，作为玩家和怪物的基础

## ITurnUnit 必需字段
var unit_id: String
var faction_id: String
var initiative: int
var atb_gauge: float = 0.0
var is_active: bool = true

## 属性组件
var stats: CharacterStats

## 角色名称
var character_name: String

func _init(p_unit_id: String, p_faction_id: String, p_name: String, p_stats: CharacterStats) -> void:
	unit_id = p_unit_id
	faction_id = p_faction_id
	character_name = p_name
	stats = p_stats
	initiative = stats.speed  # 先攻值基于速度

	# 监听死亡事件
	stats.died.connect(_on_died)

## ITurnUnit 必需方法：回合开始
func on_turn_start() -> void:
	print("[%s] 回合开始 - HP: %d/%d" % [character_name, stats.current_hp, stats.max_hp])
	# 通知所有状态效果节点（后续实现）

## ITurnUnit 必需方法：回合结束
func on_turn_end() -> void:
	print("[%s] 回合结束" % character_name)
	# 通知所有状态效果节点（后续实现）

## 攻击目标
func attack_target(target: Character) -> void:
	if not stats.is_alive:
		print("[%s] 已死亡，无法攻击" % character_name)
		return

	print("[%s] 攻击 [%s]，造成 %d 伤害" % [character_name, target.character_name, stats.attack])
	target.stats.take_damage(stats.attack)

## 死亡处理
func _on_died() -> void:
	is_active = false
	print("[%s] 已死亡" % character_name)
