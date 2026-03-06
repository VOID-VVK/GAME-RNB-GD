extends Node2D

## 战斗舞台场景脚本
## 管理战斗场景的可视化和战斗逻辑

var battle_manager: BattleManager
var players: Array[Character] = []
var monsters: Array[Character] = []

func _ready():
	print("=== 战斗舞台初始化 ===")

	# 创建战斗管理器
	battle_manager = BattleManager.new()
	add_child(battle_manager)

	# 创建 4 个玩家
	players = [
		Player.new("player_001", "战士"),
		Player.new("player_002", "法师"),
		Player.new("player_003", "弓箭手"),
		Player.new("player_004", "牧师"),
	]

	# 创建 4 个怪物
	monsters = [
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

	# 设置并开始战斗
	await get_tree().create_timer(0.5).timeout
	battle_manager.setup_battle(players, monsters)
	battle_manager.start_battle()
