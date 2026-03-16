## 角色显示组件
## 在战斗场景中显示角色的视觉表现
extends Node2D

@onready var sprite: Sprite2D = $Sprite
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

	# 加载精灵纹理
	if sprite:
		var texture_path = _get_character_texture_path(character)
		if texture_path and ResourceLoader.exists(texture_path):
			sprite.texture = load(texture_path)
		else:
			# 如果找不到纹理，使用默认颜色（作为后备）
			push_warning("找不到角色纹理: " + texture_path)

	# 创建 HP 条
	if hp_bar_container and hp_bar_scene:
		hp_bar = hp_bar_scene.instantiate()
		hp_bar_container.add_child(hp_bar)
		hp_bar.setup(character)

## 根据角色获取纹理路径
func _get_character_texture_path(char: Character) -> String:
	if char is Player:
		# 根据玩家名称映射到精灵
		match char.character_name:
			"战士":
				return "res://assets/sprites/heros/man_1/man_idle.png"
			"法师":
				return "res://assets/sprites/heros/girl_sor/sor_idle_0.png"
			"弓箭手":
				return "res://assets/sprites/heros/girl_shang/idle-new2_0.png"
			"牧师":
				return "res://assets/sprites/heros/girl_pois/pois_idle_0.png"
			_:
				return "res://assets/sprites/heros/man_1/man_idle.png"
	else:
		# 怪物使用统一的精灵
		return "res://assets/sprites/monster/monster_fire_blue_0.png"

## 高亮显示（当前行动角色）
func set_highlight(enabled: bool) -> void:
	if sprite:
		if enabled:
			sprite.modulate = Color(1.5, 1.5, 1.5)
		else:
			sprite.modulate = Color(1.0, 1.0, 1.0)
