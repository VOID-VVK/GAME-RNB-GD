class_name CharacterStats
extends RefCounted

## 人物属性组件
## 管理角色的基础属性（HP、攻击、防御、速度）

signal hp_changed(old_value: int, new_value: int)
signal died()

## 基础属性
var max_hp: int = 100
var attack: int = 10
var defense: int = 5
var speed: int = 10

## 当前状态
var current_hp: int:
	set(value):
		var old_hp = current_hp
		current_hp = clampi(value, 0, max_hp)
		if old_hp != current_hp:
			hp_changed.emit(old_hp, current_hp)
			if current_hp == 0 and old_hp > 0:
				died.emit()

## 计算属性
var is_alive: bool:
	get:
		return current_hp > 0

var hp_percent: float:
	get:
		return float(current_hp) / float(max_hp) if max_hp > 0 else 0.0

func _init(p_max_hp: int = 100, p_attack: int = 10, p_defense: int = 5, p_speed: int = 10) -> void:
	max_hp = p_max_hp
	attack = p_attack
	defense = p_defense
	speed = p_speed
	current_hp = max_hp

## 受到伤害
func take_damage(damage: int) -> void:
	var actual_damage = maxi(damage - defense, 0)
	current_hp -= actual_damage

## 恢复生命
func heal(amount: int) -> void:
	current_hp += amount
