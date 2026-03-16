extends Node2D

## 迷宫场景 - 随机遇敌

var steps: int = 0
var encounter_chance: float = 0.2  # 每步 20% 遇敌概率
var min_steps_before_encounter: int = 3  # 至少走3步才可能遇敌

@onready var steps_label: Label = $UI/StepsLabel

func _ready():
	print("=== 进入迷宫 ===")
	update_steps_label()

func _input(event: InputEvent) -> void:
	# 检测移动输入
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or \
	   event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		on_player_move()

func on_player_move() -> void:
	steps += 1
	update_steps_label()
	print("走了 %d 步" % steps)

	# 检查是否触发遇敌
	if steps >= min_steps_before_encounter:
		if randf() < encounter_chance:
			trigger_encounter()

func update_steps_label() -> void:
	if steps_label:
		steps_label.text = "步数: %d" % steps

func trigger_encounter() -> void:
	print("遇到怪物！进入战斗")
	# 切换到战斗场景
	get_tree().change_scene_to_file("res://scenes/battle.tscn")
