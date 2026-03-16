extends Node

# 自动测试脚本：模拟玩家点击

var battle_manager: BattleManager
var player_input_controller: PlayerInputController
var auto_play_enabled = false

func _ready():
	await get_tree().process_frame
	await get_tree().process_frame  # 等待 Main 的 _ready 完成

	# 查找 BattleManager（动态创建的子节点）
	var main = get_parent()
	if main and main.has_method("get"):
		battle_manager = main.battle_manager

	if not battle_manager:
		print("[AutoTest] ERROR: BattleManager not found")
		return

	player_input_controller = battle_manager.player_input_controller
	if not player_input_controller:
		print("[AutoTest] ERROR: PlayerInputController not found")
		return

	print("[AutoTest] Auto-play enabled, will simulate player input")

	# 监听回合开始
	battle_manager.character_turn_started.connect(_on_character_turn_started)

func _on_character_turn_started(character: Character):
	if not auto_play_enabled:
		return

	# 只为玩家角色自动操作
	if character.faction_id != "player":
		return

	print("[AutoTest] Auto-playing for %s" % character.character_name)

	# 等待 UI 显示
	await get_tree().create_timer(0.5).timeout

	# 模拟选择攻击
	print("[AutoTest] Simulating attack selection")
	player_input_controller._on_action_selected("attack")

	# 等待目标选择器显示
	await get_tree().create_timer(0.5).timeout

	# 获取第一个目标
	var battle_ui = player_input_controller._battle_ui
	if battle_ui and battle_ui.target_selector:
		var target_selector = battle_ui.target_selector
		var buttons = target_selector.target_container.get_children()
		if buttons.size() > 0:
			var first_button = buttons[0]
			var target = first_button.get_meta("target") if first_button.has_meta("target") else null
			if target:
				print("[AutoTest] Simulating target selection: %s" % target.character_name)
				player_input_controller._on_target_selected(target)
			else:
				print("[AutoTest] ERROR: No target metadata found")
		else:
			print("[AutoTest] ERROR: No target buttons found")
	else:
		print("[AutoTest] ERROR: Cannot access target selector")
