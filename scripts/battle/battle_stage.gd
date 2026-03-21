extends Node2D

## 战斗舞台场景脚本
## Marker2D 定义站位，运行时加载角色场景并绑定数据
## 玩家每局随机分配站位

@onready var player_positions_node: Node2D = $PlayerPositions
@onready var monster_positions_node: Node2D = $MonsterPositions

var battle_manager: BattleManager
var players: Array[Character] = []
var monsters: Array[Character] = []
var character_displays: Dictionary = {}  # Character -> display Node2D
var damage_popup_script = preload("res://addons/player_input_module/ui/damage_popup.gd")

## 玩家场景（顺序对应 players 数组）
const PLAYER_SCENES: Array[String] = [
	"res://scenes/players/man.tscn",
	"res://scenes/players/sor.tscn",
	"res://scenes/players/shang.tscn",
	"res://scenes/players/pois.tscn",
]

## 怪物场景（顺序对应 monsters 数组）
const MONSTER_SCENES: Array[String] = [
	"res://scenes/monsters/zombie1.tscn",
	"res://scenes/monsters/zombie2.tscn",
	"res://scenes/monsters/fire1.tscn",
	"res://scenes/monsters/zombie3.tscn",
]

func _ready():
	print("=== 战斗舞台初始化 ===")

	# 创建战斗管理器
	battle_manager = BattleManager.new()
	add_child(battle_manager)
	battle_manager.character_turn_started.connect(_on_character_turn_started)
	battle_manager.battle_ended.connect(_on_battle_ended)

	# 创建角色数据
	players = [
		Player.new("player_001", "战士"),
		Player.new("player_002", "法师"),
		Player.new("player_003", "弓箭手"),
		Player.new("player_004", "牧师"),
	]

	monsters = [
		Monster.new("monster_001", "哥布林", Monster.AIType.AGGRESSIVE),
		Monster.new("monster_002", "兽人", Monster.AIType.DEFENSIVE),
		Monster.new("monster_003", "骷髅", Monster.AIType.RANDOM),
		Monster.new("monster_004", "史莱姆", Monster.AIType.AGGRESSIVE),
	]

	# 收集 Marker2D 站位
	var player_markers := _get_markers(player_positions_node)
	var monster_markers := _get_markers(monster_positions_node)

	# 玩家随机分配站位
	var player_indices := range(player_markers.size())
	player_indices.shuffle()

	# 加载场景并绑定
	for i in players.size():
		var marker = player_markers[player_indices[i]]
		var display = load(PLAYER_SCENES[i]).instantiate()
		marker.add_child(display)
		display.setup(players[i])
		character_displays[players[i]] = display
		players[i].stats.hp_changed.connect(_on_character_hp_changed.bind(players[i]))

	for i in monsters.size():
		var marker = monster_markers[i]
		var display = load(MONSTER_SCENES[i]).instantiate()
		marker.add_child(display)
		display.setup(monsters[i])
		character_displays[monsters[i]] = display
		monsters[i].stats.hp_changed.connect(_on_character_hp_changed.bind(monsters[i]))

	# 开始战斗
	await get_tree().create_timer(0.5).timeout
	battle_manager.setup_battle(players, monsters)
	battle_manager.start_battle()

## 收集节点下所有 Marker2D
func _get_markers(parent: Node2D) -> Array[Marker2D]:
	var markers: Array[Marker2D] = []
	for child in parent.get_children():
		if child is Marker2D:
			markers.append(child)
	return markers

## HP 变化回调 - 显示伤害数字
func _on_character_hp_changed(old_hp: int, new_hp: int, character: Character) -> void:
	if character not in character_displays:
		return
	var display = character_displays[character]
	var damage = old_hp - new_hp
	if damage > 0:
		damage_popup_script.show_damage(self, display.global_position + Vector2(0, -50), damage, false)
	elif damage < 0:
		damage_popup_script.show_damage(self, display.global_position + Vector2(0, -50), -damage, true)

## 高亮当前行动角色
func _on_character_turn_started(character: Character) -> void:
	for display in character_displays.values():
		display.set_highlight(false)
	if character in character_displays:
		character_displays[character].set_highlight(true)

## 战斗结束
func _on_battle_ended(result: String) -> void:
	print("战斗结束: %s" % result)
	for display in character_displays.values():
		display.set_highlight(false)
	await get_tree().create_timer(2.0).timeout
	if result == "victory":
		get_tree().change_scene_to_file("res://scenes/dungeon.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/town.tscn")
