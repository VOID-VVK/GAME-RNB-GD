class_name Player
extends Character

## 玩家类
## 组合 Character，添加玩家特有逻辑

func _init(p_unit_id: String, p_name: String) -> void:
	# 创建玩家属性（较高的基础属性）
	var player_stats = CharacterStats.new(150, 20, 8, 15)
	super(p_unit_id, "player", p_name, player_stats)

## 玩家特有行为可在此扩展
func execute_action(action_type: String, target: Character = null) -> void:
	match action_type:
		"attack":
			if target:
				attack_target(target)
		"defend":
			print("[%s] 进入防御姿态" % character_name)
			# 后续可添加防御状态效果
		_:
			print("[%s] 未知行动: %s" % [character_name, action_type])
