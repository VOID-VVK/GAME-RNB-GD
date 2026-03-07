## HP 条组件
## 显示在角色上方的 HP 条
extends Control

@onready var hp_bar: ProgressBar = $ProgressBar
@onready var hp_label: Label = $HPLabel

var character: Character = null

func _ready() -> void:
	if character:
		setup(character)

## 设置角色
func setup(p_character: Character) -> void:
	character = p_character

	# 连接 HP 变化信号
	if character.stats.hp_changed.is_connected(_on_hp_changed):
		character.stats.hp_changed.disconnect(_on_hp_changed)
	character.stats.hp_changed.connect(_on_hp_changed)

	# 初始化显示
	_update_display()

## HP 变化回调
func _on_hp_changed(old_hp: int, new_hp: int) -> void:
	_update_display()

## 更新显示
func _update_display() -> void:
	if not character:
		return

	var current_hp = character.stats.current_hp
	var max_hp = character.stats.max_hp

	# 更新进度条
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp

	# 更新文本
	if hp_label:
		hp_label.text = "%d/%d" % [current_hp, max_hp]
