extends Node2D

var battle_manager: BattleManager
var battle_view: Node2D

func _ready():
	print("=== 游戏启动 ===")

	# 创建战斗视图
	var BattleView = load("res://scripts/battle/battle_view.gd")
	battle_view = BattleView.new()
	add_child(battle_view)

	# 创建战斗管理器
	battle_manager = BattleManager.new()
	add_child(battle_manager)

	# 连接信号
	battle_manager.character_turn_started.connect(_on_character_turn_started)

	# 创建 4 个玩家
	var players: Array[Character] = [
		Player.new("player_001", "战士"),
		Player.new("player_002", "法师"),
		Player.new("player_003", "弓箭手"),
		Player.new("player_004", "牧师"),
	]

	# 创建 4 个怪物
	var monsters: Array[Character] = [
		Monster.new("monster_001", "哥布林", Monster.AIType.AGGRESSIVE),
		Monster.new("monster_002", "兽人", Monster.AIType.DEFENSIVE),
		Monster.new("monster_003", "骷髅", Monster.AIType.RANDOM),
		Monster.new("monster_004", "史莱姆", Monster.AIType.AGGRESSIVE),
	]

	print("\n=== 角色创建完成 ===")
	print("玩家阵营:")
	for player in players:
		print("  [%s] HP: %d/%d, 攻击: %d, 防御: %d, 速度: %d" % [
			player.character_name,
			player.stats.current_hp,
			player.stats.max_hp,
			player.stats.attack,
			player.stats.defense,
			player.stats.speed
		])

	print("\n怪物阵营:")
	for monster in monsters:
		print("  [%s] HP: %d/%d, 攻击: %d, 防御: %d, 速度: %d" % [
			monster.character_name,
			monster.stats.current_hp,
			monster.stats.max_hp,
			monster.stats.attack,
			monster.stats.defense,
			monster.stats.speed
		])

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
