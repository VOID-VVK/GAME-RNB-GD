class_name BattleManager
extends Node

## 战斗管理器
## 使用 TurnBasedSystem 插件实现 Plan-Resolve 模式战斗

# ==================== 信号 ====================
signal battle_started
signal battle_ended(result: String)  # "victory" 或 "defeat"
signal character_turn_started(character: Character)  # 角色回合开始

# ==================== 组件 ====================
var player_input_controller: PlayerInputController
var players: Array[Character] = []
var monsters: Array[Character] = []

# ==================== 战斗状态 ====================
var planned_actions: Array[BaseAction] = []
var is_battle_active: bool = false
var _current_action_data: ActionData = null

# ==================== 初始化 ====================
func _ready() -> void:
	# 创建玩家输入控制器
	player_input_controller = PlayerInputController.new()
	add_child(player_input_controller)

	# 连接信号
	player_input_controller.input_completed.connect(_on_player_input_completed)

## 设置战斗
func setup_battle(p_players: Array[Character], p_monsters: Array[Character]) -> void:
	players = p_players
	monsters = p_monsters

	print("=== 战斗初始化完成 ===")
	print("玩家阵营: %d 人" % players.size())
	print("怪物阵营: %d 只" % monsters.size())

## 开始战斗（手动管理回合循环）
func start_battle() -> void:
	is_battle_active = true
	battle_started.emit()
	print("\n=== 战斗开始 ===")

	var round_number = 1
	while is_battle_active:
		await _execute_round(round_number)
		round_number += 1

		# 检查战斗是否结束
		if _check_battle_end():
			break

		# 回合间隔
		await get_tree().create_timer(0.5).timeout

## 执行单个回合
func _execute_round(round_number: int) -> void:
	print("\n--- 第 %d 回合开始 ---" % round_number)
	planned_actions.clear()

	# Planning 阶段：收集所有行动
	print("\n>>> 阶段切换: Planning <<<")
	await _planning_phase()

	# Resolution 阶段：执行所有行动
	print("\n>>> 阶段切换: Resolution <<<")
	_resolution_phase()

	print("--- 第 %d 回合结束 ---\n" % round_number)

## Planning 阶段：收集所有行动
func _planning_phase() -> void:
	print("进入计划阶段 - 收集玩家行动")

	# 收集玩家行动
	for player in players:
		if player.stats.is_alive:
			var action = await _get_player_action(player)
			if action:
				planned_actions.append(action)

	# 收集怪物行动
	print("收集怪物 AI 行动")
	for monster in monsters:
		if monster.stats.is_alive:
			var action = _get_monster_action(monster)
			if action:
				planned_actions.append(action)

	print("计划阶段完成 - 收集到 %d 个行动" % planned_actions.size())

## Resolution 阶段：执行所有行动
func _resolution_phase() -> void:
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

## 获取单个玩家的行动（使用 PlayerInputController）
func _get_player_action(player: Character) -> BaseAction:
	print("[%s] 等待玩家输入..." % player.character_name)

	# 发送角色回合开始信号
	character_turn_started.emit(player)

	var valid_targets = monsters.filter(func(m): return m.stats.is_alive)
	if valid_targets.is_empty():
		return null

	# 创建输入上下文
	var context = InputContext.new(
		player,
		["attack", "defend"],  # 可用行动类型
		valid_targets
	)

	# 请求玩家输入
	player_input_controller.request_input(context)

	# 等待输入完成
	_current_action_data = null
	await player_input_controller.input_completed

	# 将 ActionData 转换为 BaseAction
	var action = _convert_action_data_to_action(_current_action_data)

	if action:
		print("[%s] 选择了行动: %s" % [player.character_name, action.action_name])

	return action

## 玩家输入完成回调
func _on_player_input_completed(action_data: ActionData) -> void:
	_current_action_data = action_data

## 将 ActionData 转换为 BaseAction
func _convert_action_data_to_action(data: ActionData) -> BaseAction:
	if not data:
		return null

	match data.action_type:
		"attack":
			return AttackAction.new(data.actor, data.target)
		"defend":
			return DefendAction.new(data.actor)
		_:
			push_error("Unknown action type: " + data.action_type)
			return null

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
