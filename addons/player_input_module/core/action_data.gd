## 行动数据类
## 封装玩家输入的行动数据
class_name ActionData
extends RefCounted

## 行动类型 ("attack", "defend", "skill", "item")
var action_type: String

## 行动者
var actor: Character

## 目标（可选，防御行动无目标）
var target: Character = null

## 技能ID（可选，技能行动时使用）
var skill_id: String = ""

## 物品ID（可选，物品行动时使用）
var item_id: String = ""

## 额外数据
var metadata: Dictionary = {}

func _init(p_action_type: String, p_actor: Character, p_target: Character = null) -> void:
	action_type = p_action_type
	actor = p_actor
	target = p_target

## 转换为字典格式
func to_dict() -> Dictionary:
	return {
		"action_type": action_type,
		"actor": actor,
		"target": target,
		"skill_id": skill_id,
		"item_id": item_id,
		"metadata": metadata
	}

func _to_string() -> String:
	var target_name = target.character_name if target else "none"
	return "ActionData(type=%s, actor=%s, target=%s)" % [
		action_type,
		actor.character_name if actor else "null",
		target_name
	]
