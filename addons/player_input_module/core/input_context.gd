## 输入上下文数据类
## 封装输入请求的所有上下文信息
class_name InputContext
extends RefCounted

## 当前行动角色
var actor: Character

## 可用行动类型 (e.g., ["attack", "defend", "skill", "item"])
var available_actions: Array[String]

## 有效目标列表
var valid_targets: Array[Character]

## 额外数据（如技能列表、物品列表）
var metadata: Dictionary = {}

func _init(p_actor: Character, p_actions: Array[String], p_targets: Array[Character]) -> void:
	actor = p_actor
	available_actions = p_actions
	valid_targets = p_targets

func _to_string() -> String:
	return "InputContext(actor=%s, actions=%s, targets=%d)" % [
		actor.character_name if actor else "null",
		str(available_actions),
		valid_targets.size()
	]
