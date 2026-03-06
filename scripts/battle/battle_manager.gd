class_name BattleManager
extends Node

## 战斗管理器
## 使用 TurnBasedSystem 插件实现 Plan-Resolve 模式战斗

# ==================== 信号 ====================
signal battle_started
signal battle_ended(result: String)  # "victory" 或 "defeat"

# ==================== 组件 ====================
var turn_system: TurnSystemNode
var players: Array[Character] = []
var monsters: Array[Character] = []

# ==================== 战斗状态 ====================
var planned_actions: Array[BaseAction] = []
var is_battle_active: bool = false
var current_player_index: int = 0

# ==================== 初始化 ====================
func _ready() -> void:
	# 创建回合制系统节点
	turn_system = TurnSystemNode.new()
	add_child(turn_system)

	# 连接信号
	turn_system.round_started.connect(_on_round_started)
	turn_system.round_ended.connect(_on_round_ended)
	turn_system.phase_changed.connect(_on_phase_changed)

## 设置战斗
func setup_battle(p_players: Array[Character], p_monsters: Array[Character]) -> void:
	players = p_players
	monsters = p_monsters

	# 使用 simultaneous 模板（Plan-Resolve 模式）
	turn_system.configure(TurnTemplates.simultaneous())

	# 设置回调 - 在 Planning 阶段收集行动
	turn_system.on_player_input = _collect_player_action
	turn_system.on_ai_decision = _collect_ai_actions
	# 设置动画回调 - 在 Resolution 阶段执行
	turn_system.on_animate_batch = _execute_actions_batch

	# 注册阵营
	var player_faction = SimpleFaction.new("player", players, true)
	var monster_faction = SimpleFaction.new("monster", monsters, false)
	turn_system.register_faction(player_faction)
	turn_system.register_faction(monster_faction)

	print("=== 战斗初始化完成 ===")
	print("玩家阵营: %d 人" % players.size())
	print("怪物阵营: %d 只" % monsters.size())

## 开始战斗
func start_battle() -> void:
	is_battle_active = true
	battle_started.emit()
	print("\n=== 战斗开始 ===")
	turn_system.execute_round()

# ==================== 回合制信号处理 ====================

func _on_round_started(round_number: int) -> void:
	print("\n--- 第 %d 回合开始 ---" % round_number)
	planned_actions.clear()
	current_player_index = 0

func _on_round_ended(round_number: int) -> void:
	print("--- 第 %d 回合结束 ---\n" % round_number)

	# 检查战斗是否结束
	if _check_battle_end():
		return

	# 继续下一回合
	await get_tree().create_timer(0.5).timeout
	turn_system.execute_round()

func _on_phase_changed(phase_name: String) -> void:
	print("\n>>> 阶段切换: %s <<<" % phase_name)

	if phase_name == "Resolution":
		_execute_resolution_phase()

# ==================== Planning 阶段：收集行动 ====================

## 收集单个玩家的行动
func _collect_player_action(ctx: TurnContext, step: TurnStep) -> BaseAction:
	# 在 simultaneous 模式下，这个回调会被调用一次
	# 我们需要为所有玩家收集行动
	print("进入计划阶段 - 收集玩家行动")

	for player in players:
		if player.stats.is_alive:
			var action = _get_player_action(player)
			if action:
				planned_actions.append(action)

	# 返回 null，因为我们在 Resolution 阶段执行
	return null

## 获取单个玩家的行动（简化版：随机选择）
func _get_player_action(player: Character) -> BaseAction:
	print("[%s] 正在选择行动..." % player.character_name)

	var valid_targets = monsters.filter(func(m): return m.stats.is_alive)
	if valid_targets.is_empty():
		return null

	# 80% 概率攻击，20% 概率防御
	if randf() < 0.8:
		var target = valid_targets[randi() % valid_targets.size()]
		print("[%s] 选择攻击 [%s]" % [player.character_name, target.character_name])
		return AttackAction.new(player, target)
	else:
		print("[%s] 选择防御" % player.character_name)
		return DefendAction.new(player)

## 收集所有怪物的行动
func _collect_ai_actions(ctx: TurnContext, step: TurnStep) -> Array:
	print("收集怪物 AI 行动")

	for monster in monsters:
		if monster.stats.is_alive:
			var action = _get_monster_action(monster)
			if action:
				planned_actions.append(action)

	print("计划阶段完成 - 收集到 %d 个行动" % planned_actions.size())
	# 返回空数组，防止在 Planning 阶段执行
	return []

## 获取单个怪物的行动
func _get_monster_action(monster: Monster) -> BaseAction:
	var valid_targets = players.filter(func(p): return p.stats.is_alive)
	if valid_targets.is_empty():
		return null

	var target = monster._select_target(valid_targets)
	if target:
		print("[%s] AI 选择攻击 [%s]" % [monster.character_name, target.character_name])
		return AttackAction.new(monster, target)

	return null

# ==================== Resolution 阶段：执行行动 ====================

func _execute_resolution_phase() -> void:
	print("\n进入执行阶段 - 按速度排序并执行所有行动")

	# 按速度值排序（initiative 从高到低）
	planned_actions.sort_custom(func(a, b):
		return a.actor.initiative > b.actor.initiative
	)

	# 依次执行每个行动
	for action in planned_actions:
		if action.actor.stats.is_alive:
			print("\n[%s] 执行行动: %s" % [action.actor.character_name, action.action_name])
			action.execute()

	print("\n执行阶段完成")

func _execute_actions_batch(results: Array) -> void:
	# 这个回调在 simultaneous 模式下不会被调用
	# 我们在 _execute_resolution_phase 中手动执行
	pass

# ==================== 战斗结束判断 ====================

func _check_battle_end() -> bool:
	var alive_players = players.filter(func(p): return p.stats.is_alive)
	var alive_monsters = monsters.filter(func(m): return m.stats.is_alive)

	if alive_players.is_empty():
		print("\n=== 战斗结束：怪物胜利 ===")
		is_battle_active = false
		battle_ended.emit("defeat")
		return true

	if alive_monsters.is_empty():
		print("\n=== 战斗结束：玩家胜利 ===")
		is_battle_active = false
		battle_ended.emit("victory")
		return true

	return false
