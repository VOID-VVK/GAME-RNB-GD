extends Node2D

## 城镇场景

func _ready():
	print("=== 进入城镇 ===")

## 进入迷宫按钮回调
func _on_enter_dungeon_button_pressed() -> void:
	print("进入迷宫 - 切换到迷宫场景")
	get_tree().change_scene_to_file("res://scenes/dungeon.tscn")
