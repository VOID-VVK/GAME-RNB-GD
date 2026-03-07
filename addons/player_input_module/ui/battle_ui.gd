## 战斗 UI 根容器
## 管理所有子 UI 组件的显示/隐藏
extends CanvasLayer

## 信号
signal action_selected(action_type: String)
signal target_selected(target: Character)
signal input_cancelled()

## 子组件引用
@onready var action_panel: Control = $ActionPanel
@onready var target_selector: Control = $TargetSelector

func _ready() -> void:
	# 连接子组件信号
	if action_panel:
		action_panel.action_selected.connect(_on_action_selected)
	if target_selector:
		target_selector.target_selected.connect(_on_target_selected)
		target_selector.cancelled.connect(_on_input_cancelled)

	# 初始隐藏所有组件
	hide_all()

## 显示行动选择面板
func show_action_panel(available_actions: Array[String], actor: Character) -> void:
	hide_all()
	if action_panel:
		action_panel.show_actions(available_actions, actor)
		action_panel.visible = true

## 显示目标选择器
func show_target_selector(targets: Array[Character], action_type: String) -> void:
	if action_panel:
		action_panel.visible = false
	if target_selector:
		target_selector.show_targets(targets, action_type)
		target_selector.visible = true

## 隐藏所有组件
func hide_all() -> void:
	if action_panel:
		action_panel.visible = false
	if target_selector:
		target_selector.visible = false

## 行动选择回调
func _on_action_selected(action_type: String) -> void:
	action_selected.emit(action_type)

## 目标选择回调
func _on_target_selected(target: Character) -> void:
	target_selected.emit(target)

## 输入取消回调
func _on_input_cancelled() -> void:
	input_cancelled.emit()
