extends Node

## Character 模块单元测试

func _ready() -> void:
	print("=== 开始 Character 模块测试 ===\n")

	test_character_stats()
	test_character_creation()
	test_combat()
	test_player_creation()
	test_monster_ai()

	print("\n=== 所有测试完成 ===")
	get_tree().quit()

## 测试 CharacterStats 组件
func test_character_stats() -> void:
	print("--- 测试 CharacterStats ---")

	var stats = CharacterStats.new(100, 20, 5, 10)
	assert(stats.max_hp == 100, "max_hp 应为 100")
	assert(stats.current_hp == 100, "初始 current_hp 应等于 max_hp")
	assert(stats.is_alive, "初始状态应为存活")
	assert(stats.hp_percent == 1.0, "初始 hp_percent 应为 1.0")

	# 测试受伤
	stats.take_damage(30)
	assert(stats.current_hp == 75, "受到 30 伤害后应剩余 75 HP (30 - 5 防御 = 25 实际伤害)")
	assert(stats.hp_percent == 0.75, "hp_percent 应为 0.75")

	# 测试治疗
	stats.heal(20)
	assert(stats.current_hp == 95, "治疗 20 后应为 95 HP")

	# 测试死亡
	var died_flag = {"triggered": false}
	stats.died.connect(func(): died_flag.triggered = true)
	stats.take_damage(200)
	assert(stats.current_hp == 0, "受到致命伤害后 HP 应为 0")
	assert(not stats.is_alive, "死亡后 is_alive 应为 false")
	assert(died_flag.triggered, "died 信号应被触发")

	print("✓ CharacterStats 测试通过\n")

## 测试 Character 创建
func test_character_creation() -> void:
	print("--- 测试 Character 创建 ---")

	var stats = CharacterStats.new(100, 15, 5, 12)
	var character = Character.new("char_001", "test_faction", "测试角色", stats)

	assert(character.unit_id == "char_001", "unit_id 应正确设置")
	assert(character.faction_id == "test_faction", "faction_id 应正确设置")
	assert(character.character_name == "测试角色", "character_name 应正确设置")
	assert(character.initiative == 12, "initiative 应基于 speed")
	assert(character.is_active, "初始状态应为 active")

	print("✓ Character 创建测试通过\n")

## 测试战斗逻辑
func test_combat() -> void:
	print("--- 测试战斗逻辑 ---")

	var attacker_stats = CharacterStats.new(100, 20, 5, 10)
	var attacker = Character.new("atk_001", "faction_a", "攻击者", attacker_stats)

	var defender_stats = CharacterStats.new(100, 10, 8, 10)
	var defender = Character.new("def_001", "faction_b", "防御者", defender_stats)

	# 攻击一次
	attacker.attack_target(defender)
	assert(defender.stats.current_hp == 88, "防御者应受到 12 伤害 (20 - 8 = 12)")

	# 测试死亡后无法攻击
	defender.stats.current_hp = 0
	assert(not defender.is_active, "死亡后应变为 inactive")
	defender.attack_target(attacker)
	assert(attacker.stats.current_hp == 100, "死亡角色无法造成伤害")

	print("✓ 战斗逻辑测试通过\n")

## 测试 Player 创建
func test_player_creation() -> void:
	print("--- 测试 Player 创建 ---")

	var player = Player.new("player_001", "勇者")

	assert(player.faction_id == "player", "玩家 faction_id 应为 'player'")
	assert(player.stats.max_hp == 150, "玩家应有较高的 HP")
	assert(player.stats.attack == 20, "玩家应有较高的攻击力")

	print("✓ Player 创建测试通过\n")

## 测试 Monster AI
func test_monster_ai() -> void:
	print("--- 测试 Monster AI ---")

	var monster = Monster.new("monster_001", "哥布林", Monster.AIType.AGGRESSIVE)
	assert(monster.faction_id == "monster", "怪物 faction_id 应为 'monster'")

	# 创建多个目标
	var target1 = Player.new("p1", "玩家1")
	target1.stats.current_hp = 50

	var target2 = Player.new("p2", "玩家2")
	target2.stats.current_hp = 100

	var targets: Array[Character] = [target1, target2]

	# 激进型 AI 应选择血量最低的目标
	monster.execute_ai(targets)
	assert(target1.stats.current_hp < 50, "激进型 AI 应攻击血量最低的目标")

	print("✓ Monster AI 测试通过\n")
