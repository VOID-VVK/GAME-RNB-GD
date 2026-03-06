class_name BaseAction
extends RefCounted

## 战斗行动基类
## 实现 ITurnAction 鸭子类型约定

## ITurnAction 必需字段
var action_name: String
var cost: int = 1
var actor: Character

## 目标（可选，某些行动如防御不需要目标）
var target: Character = null

func _init(p_action_name: String, p_actor: Character, p_target: Character = null) -> void:
	action_name = p_action_name
	actor = p_actor
	target = p_target

## ITurnAction 必需方法：执行行动
## 返回 TurnEnums.ActionResult
func execute() -> int:
	push_error("BaseAction.execute() 必须由子类实现")
	return TurnEnums.ActionResult.FAILED
