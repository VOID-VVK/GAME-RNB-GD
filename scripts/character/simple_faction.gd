class_name SimpleFaction
extends RefCounted

## 简单阵营实现
## 符合 ITurnFaction 鸭子类型约定

var faction_id: String
var order: int = 0
var is_player_controlled: bool = false
var units: Array = []

func _init(p_faction_id: String, p_units: Array = [], p_is_player: bool = false) -> void:
	faction_id = p_faction_id
	units = p_units
	is_player_controlled = p_is_player

func get_active_units() -> Array:
	return units.filter(func(u): return u.is_active)
