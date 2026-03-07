## 角色显示组件
## 在战斗场景中显示角色的视觉表现
extends Node2D

@onready var sprite: ColorRect = $Sprite
@onready var name_label: Label = $NameLabel
@onready var hp_bar_container: Control = $HPBarContainer

var character: Character = null
var hp_bar_scene = preload("res://addons/player_input_module/scenes/hp_bar.tscn")
var hp_bar: Control = null

func _ready() -> void:
	if character:
		setup(character)

## 设置角色
func setup(p_character: Character) -> void:
	character = p_character

	# 设置名称
	if name_label:
		name_label.text = character.character_name

	# 设置颜色（玩家蓝色，怪物红色）
	if sprite:
		if character is Player:
			sprite.color = Color(0.2, 0.5, 1.0)  # 蓝色
		else:
			sprite.color = Color(1.0, 0.3, 0.3)  # 红色

	# 创建 HP 条
	if hp_bar_container and hp_bar_scene:
		hp_bar = hp_bar_scene.instantiate()
		hp_bar_container.add_child(hp_bar)
		hp_bar.setup(character)

## 高亮显示（当前行动角色）
func set_highlight(enabled: bool) -> void:
	if sprite:
		if enabled:
			sprite.modulate = Color(1.5, 1.5, 1.5)
		else:
			sprite.modulate = Color(1.0, 1.0, 1.0)
