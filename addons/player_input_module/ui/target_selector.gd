## 目标选择器
## 显示可选目标列表
extends PanelContainer

## 信号
signal target_selected(target: Character)
signal cancelled()

## UI 节点
@onready var target_container: VBoxContainer = $MarginContainer/VBoxContainer/TargetContainer
@onready var prompt_label: Label = $MarginContainer/VBoxContainer/PromptLabel
@onready var cancel_button: Button = $MarginContainer/VBoxContainer/CancelButton

func _ready() -> void:
	visible = false
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)

## 显示目标列表
func show_targets(targets: Array[Character], action_type: String) -> void:
	# 清空现有按钮
	for child in target_container.get_children():
		child.queue_free()

	# 更新提示文本
	if prompt_label:
		var action_text = "攻击" if action_type == "attack" else "使用"
		prompt_label.text = "选择%s目标..." % action_text

	# 动态生成目标按钮
	for i in targets.size():
		var target = targets[i]
		var button = Button.new()
		button.text = "%s (HP: %d/%d)" % [
			target.character_name,
			target.stats.current_hp,
			target.stats.max_hp
		]
		button.custom_minimum_size = Vector2(200, 50)
		button.pressed.connect(_on_target_button_pressed.bind(target))

		# 添加快捷键提示
		if i < 9:
			button.text += " [%d]" % (i + 1)

		target_container.add_child(button)

	visible = true

## 目标按钮点击回调
func _on_target_button_pressed(target: Character) -> void:
	target_selected.emit(target)

## 取消按钮回调
func _on_cancel_pressed() -> void:
	cancelled.emit()

## 处理键盘快捷键
func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# 数字键 1-9 选择目标
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var index = event.keycode - KEY_1
			var buttons = target_container.get_children()
			if index < buttons.size() and buttons[index] is Button:
				var target = buttons[index].get_meta("target") if buttons[index].has_meta("target") else null
				if target:
					target_selected.emit(target)
		# ESC 取消
		elif event.keycode == KEY_ESCAPE:
			cancelled.emit()
