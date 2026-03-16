extends Node2D

## 主菜单场景

func _ready():
	print("=== 游戏启动 - 主菜单 ===")

## 开始游戏按钮回调
func _on_start_button_pressed() -> void:
	print("开始游戏 - 切换到城镇场景")
	get_tree().change_scene_to_file("res://scenes/town.tscn")
