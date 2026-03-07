## 战斗视图管理器
## 管理战斗场景中所有角色的视觉表现
extends Node2D

var character_display_scene = preload("res://addons/player_input_module/scenes/character_display.tscn")
var damage_popup_script = preload("res://addons/player_input_module/ui/damage_popup.gd")
var character_displays: Dictionary = {}  # character -> CharacterDisplay

func _ready() -> void:
	# 连接所有角色的 HP 变化信号
	pass

## 设置战斗（创建所有角色的视觉表现）
func setup_battle(players: Array[Character], monsters: Array[Character]) -> void:
	# 清空现有显示
	for child in get_children():
		child.queue_free()
	character_displays.clear()

	# 创建玩家显示（左侧）
	var player_x_start = 150
	var player_spacing = 100
	for i in players.size():
		var display = character_display_scene.instantiate()
		display.position = Vector2(player_x_start + i * player_spacing, 350)
		add_child(display)
		display.setup(players[i])
		character_displays[players[i]] = display

		# 连接 HP 变化信号以显示伤害数字
		players[i].stats.hp_changed.connect(_on_character_hp_changed.bind(players[i]))

	# 创建怪物显示（右侧）
	var monster_x_start = 700
	var monster_spacing = 100
	for i in monsters.size():
		var display = character_display_scene.instantiate()
		display.position = Vector2(monster_x_start + i * monster_spacing, 350)
		add_child(display)
		display.setup(monsters[i])
		character_displays[monsters[i]] = display

		# 连接 HP 变化信号以显示伤害数字
		monsters[i].stats.hp_changed.connect(_on_character_hp_changed.bind(monsters[i]))

## HP 变化回调 - 显示伤害数字
func _on_character_hp_changed(old_hp: int, new_hp: int, character: Character) -> void:
	if character not in character_displays:
		return

	var display = character_displays[character]
	var damage = old_hp - new_hp

	if damage > 0:
		# 受到伤害
		damage_popup_script.show_damage(self, display.position + Vector2(0, -50), damage, false)
	elif damage < 0:
		# 治疗
		damage_popup_script.show_damage(self, display.position + Vector2(0, -50), -damage, true)

## 高亮当前行动角色
func highlight_character(character: Character) -> void:
	# 取消所有高亮
	for display in character_displays.values():
		display.set_highlight(false)

	# 高亮指定角色
	if character in character_displays:
		character_displays[character].set_highlight(true)

## 清除所有高亮
func clear_highlights() -> void:
	for display in character_displays.values():
		display.set_highlight(false)
