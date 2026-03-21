extends Node2D

## 战斗舞台场景脚本
## 直接使用 tscn 中配置的角色节点，不动态生成

@onready var player_positions_node: Node2D = $PlayerPositions
@onready var monster_positions_node: Node2D = $MonsterPositions

var battle_manager: BattleManager
var players: Array[Character] = []
var monsters: Array[Character] = []
var character_displays: Dictionary = {}  # Character -> display Node2D
var damage_popup_script = preload("res://addons/player_input_module/ui/damage_popup.gd")

func _ready():
	print("=== 战斗舞台初始化 ===")

	# 创建战斗管理器
	battle_manager = BattleManager.new()
	add_child(battle_manager)
	battle_manager.character_turn_started.connect(_on_character_turn_started)
	battle_manager.battle_ended.connect(_on_battle_ended)

	# 创建角色数据
	players = [
		Player.new("player_001", "战士"),
		Player.new("player_002", "法师"),
		Player.new("player_003", "弓箭手"),
		Player.new("player_004", "牧师"),
	]

	monsters = [
		Monster.new("monster_001", "哥布林", Monster.AIType.AGGRESSIVE),
		Monster.new("monster_002", "兽人", Monster.AIType.DEFENSIVE),
		Monster.new("monster_003", "骷髅", Monster.AIType.RANDOM),
		Monster.new("monster_004", "史莱姆", Monster.AIType.AGGRESSIVE),
	]

	# 绑定 tscn 中已有的角色节点
	_bind_displays(player_positions_node, players)
	_bind_displays(monster_positions_node, monsters)

	# 开始战斗
	await get_tree().create_timer(0.5).timeout
	battle_manager.setup_battle(players, monsters)
	battle_manager.start_battle()

## 遍历 Marker2D 下的角色节点，调用 setup() 绑定数据
func _bind_displays(positions_node: Node2D, characters: Array[Character]) -> void:
	var i := 0
	for marker in positions_node.get_children():
		if not marker is Marker2D:
			continue
		# Marker2D 的第一个子节点就是角色 display
		for child in marker.get_children():
			if child.has_method("setup") and i < characters.size():
				child.setup(characters[i])
				character_displays[characters[i]] = child
				characters[i].stats.hp_changed.connect(_on_character_hp_changed.bind(characters[i]))
				i += 1
				break

## HP 变化回调 - 显示伤害数字
func _on_character_hp_changed(old_hp: int, new_hp: int, character: Character) -> void:
	if character not in character_displays:
		return
	var display = character_displays[character]
	var damage = old_hp - new_hp
	if damage > 0:
		damage_popup_script.show_damage(self, display.global_position + Vector2(0, -50), damage, false)
	elif damage < 0:
		damage_popup_script.show_damage(self, display.global_position + Vector2(0, -50), -damage, true)

## 高亮当前行动角色
func _on_character_turn_started(character: Character) -> void:
	for display in character_displays.values():
		display.set_highlight(false)
	if character in character_displays:
		character_displays[character].set_highlight(true)

## 战斗结束
func _on_battle_ended(result: String) -> void:
	print("战斗结束: %s" % result)
	for display in character_displays.values():
		display.set_highlight(false)
