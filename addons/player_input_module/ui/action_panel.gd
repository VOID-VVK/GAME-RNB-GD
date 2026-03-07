## 行动选择面板
## 显示行动按钮（攻击、防御等）
extends PanelContainer

## 信号
signal action_selected(action_type: String)

## UI 节点
@onready var button_container: HBoxContainer = $MarginContainer/VBoxContainer/ButtonContainer
@onready var prompt_label: Label = $MarginContainer/VBoxContainer/PromptLabel

## 行动类型到显示文本的映射
const ACTION_LABELS = {
	"attack": "攻击 (A)",
	"defend": "防御 (D)",
	"skill": "技能 (S)",
	"item": "物品 (I)",
	"flee": "逃跑 (R)"
}

func _ready() -> void:
	visible = false

## 显示可用行动
func show_actions(available_actions: Array[String], actor: Character) -> void:
	# 清空现有按钮
	for child in button_container.get_children():
		child.queue_free()

	# 更新提示文本
	if prompt_label:
		prompt_label.text = "[%s] 选择行动..." % actor.character_name

	# 动态生成按钮
	for action_type in available_actions:
		var button = Button.new()
		button.text = ACTION_LABELS.get(action_type, action_type.capitalize())
		button.custom_minimum_size = Vector2(120, 50)
		button.pressed.connect(_on_action_button_pressed.bind(action_type))
		button_container.add_child(button)

	visible = true

## 按钮点击回调
func _on_action_button_pressed(action_type: String) -> void:
	action_selected.emit(action_type)

## 处理键盘快捷键
func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_A:
				_emit_if_available("attack")
			KEY_D:
				_emit_if_available("defend")
			KEY_S:
				_emit_if_available("skill")
			KEY_I:
				_emit_if_available("item")
			KEY_R:
				_emit_if_available("flee")

func _emit_if_available(action_type: String) -> void:
	# 检查按钮是否存在
	for button in button_container.get_children():
		if button is Button and ACTION_LABELS.get(action_type, "") in button.text:
			action_selected.emit(action_type)
			break
