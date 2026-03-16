## 玩家输入控制器
## 提供标准的输入请求接口，管理输入流程状态机
class_name PlayerInputController
extends Node

## 输入完成信号
signal input_completed(action_data: ActionData)

## 输入取消信号
signal input_cancelled()

## 状态枚举
enum State {
	IDLE,                    # 空闲状态
	WAITING_FOR_ACTION,      # 等待选择行动类型
	WAITING_FOR_TARGET,      # 等待选择目标
	COMPLETED                # 输入完成
}

## 当前状态
var _state: State = State.IDLE

## 当前输入上下文
var _current_context: InputContext = null

## 当前选择的行动类型
var _selected_action_type: String = ""

## UI 根容器
var _battle_ui: Node = null

## 配置选项
var _config: Dictionary = {
	"layout": "classic",
	"show_turn_order": false,
	"show_status_panels": false,
	"enable_shortcuts": true,
}

func _ready() -> void:
	# 同步初始化 UI（不使用 call_deferred）
	_initialize_ui()

func _initialize_ui() -> void:
	# 加载 BattleUI 场景
	var battle_ui_scene = load("res://addons/player_input_module/scenes/battle_ui.tscn")
	if battle_ui_scene:
		_battle_ui = battle_ui_scene.instantiate()
		add_child(_battle_ui)

		# 等待 BattleUI 完全 ready
		if not _battle_ui.is_node_ready():
			await _battle_ui.ready

		# 连接 UI 信号
		if _battle_ui.has_signal("action_selected"):
			_battle_ui.action_selected.connect(_on_action_selected)
		if _battle_ui.has_signal("target_selected"):
			_battle_ui.target_selected.connect(_on_target_selected)
		if _battle_ui.has_signal("input_cancelled"):
			_battle_ui.input_cancelled.connect(_on_input_cancelled)

		# 初始隐藏 UI
		_battle_ui.hide_all()
		print("[PlayerInputController] UI initialized successfully")
	else:
		push_error("[PlayerInputController] Failed to load BattleUI scene")

## 请求玩家输入
func request_input(context: InputContext) -> void:
	if _state != State.IDLE:
		push_warning("[PlayerInputController] Already waiting for input (state=%s), ignoring request" % State.keys()[_state])
		return

	if not _battle_ui:
		push_error("[PlayerInputController] UI not initialized, cannot request input")
		return

	_current_context = context
	_state = State.WAITING_FOR_ACTION
	_selected_action_type = ""

	print("[PlayerInputController] Requesting input for %s" % context.actor.character_name)

	# 显示行动选择面板
	_battle_ui.show_action_panel(context.available_actions, context.actor)
	print("[PlayerInputController] Action panel displayed")

## 取消当前输入
func cancel_input() -> void:
	if _state == State.IDLE:
		return

	print("[PlayerInputController] Input cancelled")
	_reset_state()
	input_cancelled.emit()

## 配置控制器
func configure(config: Dictionary) -> void:
	_config.merge(config, true)
	print("[PlayerInputController] Configuration updated: %s" % str(_config))

## 设置 UI 主题
func set_ui_theme(theme: Theme) -> void:
	if _battle_ui and _battle_ui.has_method("set_theme"):
		_battle_ui.set_theme(theme)

## 行动选择回调
func _on_action_selected(action_type: String) -> void:
	if _state != State.WAITING_FOR_ACTION:
		return

	_selected_action_type = action_type
	print("[PlayerInputController] Action selected: %s" % action_type)

	# 如果是防御行动，不需要选择目标
	if action_type == "defend":
		_complete_input(null)
		return

	# 显示目标选择器
	_state = State.WAITING_FOR_TARGET
	if _battle_ui:
		_battle_ui.show_target_selector(_current_context.valid_targets, action_type)

## 目标选择回调
func _on_target_selected(target: Character) -> void:
	if _state != State.WAITING_FOR_TARGET:
		print("[PlayerInputController] WARNING: Received target_selected but state is %s, ignoring" % State.keys()[_state])
		return

	print("[PlayerInputController] Target selected: %s" % target.character_name)
	_complete_input(target)

## 输入取消回调
func _on_input_cancelled() -> void:
	cancel_input()

## 完成输入
func _complete_input(target: Character) -> void:
	# 构造 ActionData
	var action_data = ActionData.new(_selected_action_type, _current_context.actor, target)

	print("[PlayerInputController] Input completed: %s" % str(action_data))

	# 隐藏 UI
	if _battle_ui:
		_battle_ui.hide_all()

	# 先重置状态（在发送信号之前，避免信号处理中的新请求被拒绝）
	_reset_state()

	# 发送信号
	input_completed.emit(action_data)

## 重置状态
func _reset_state() -> void:
	_state = State.IDLE
	_current_context = null
	_selected_action_type = ""

	if _battle_ui:
		_battle_ui.hide_all()
