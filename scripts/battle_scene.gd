extends Node2D

## 战斗场景 - 使用现有的战斗系统

var battle_manager: BattleManager
var battle_view: Node2D

func _ready():
	print("=== 进入战斗 ===")

	# 创建战斗视图
	var BattleView = load("res://scripts/battle/battle_view.gd")
	battle_view = BattleView.new()
	add_child(battle_view)

	# 创建战斗管理器
	battle_manager = BattleManager.new()
	add_child(battle_manager)

	# 连接信号
	battle_manager.character_turn_started.connect(_on_character_turn_started)
	battle_manager.battle_ended.connect(_on_battle_ended)

	# 创建玩家队伍
	var players: Array[Character] = [
		Player.new("player_001", "战士"),
		Player.new("player_002", "法师"),
		Player.new("player_003", "弓箭手"),
		Player.new("player_004", "牧师"),
	]

	# 创建怪物队伍
	var monsters: Array[Character] = [
		Monster.new("monster_001", "哥布林", Monster.AIType.AGGRESSIVE),
		Monster.new("monster_002", "兽人", Monster.AIType.DEFENSIVE),
	]

	# 设置战斗视图
	battle_view.setup_battle(players, monsters)

	# 设置并开始战斗
	await get_tree().create_timer(0.5).timeout
	battle_manager.setup_battle(players, monsters)
	battle_manager.start_battle()

## 角色回合开始回调
func _on_character_turn_started(character: Character) -> void:
	if battle_view:
		battle_view.highlight_character(character)

## 战斗结束回调
func _on_battle_ended(result: String) -> void:
	print("战斗结束: %s" % result)
	await get_tree().create_timer(2.0).timeout

	if result == "victory":
		print("胜利！返回迷宫")
		get_tree().change_scene_to_file("res://scenes/dungeon.tscn")
	else:
		print("失败！返回城镇")
		get_tree().change_scene_to_file("res://scenes/town.tscn")
