## 伤害数字弹出组件
## 在角色上方显示伤害数字动画
extends Label

var damage: int = 0
var is_heal: bool = false

func _ready() -> void:
	# 设置文本
	if is_heal:
		text = "+%d" % damage
		modulate = Color(0.3, 1.0, 0.3)  # 绿色表示治疗
	else:
		text = "-%d" % damage
		modulate = Color(1.0, 0.3, 0.3)  # 红色表示伤害

	# 播放动画
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 50, 1.0)
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	tween.finished.connect(queue_free)

## 显示伤害
static func show_damage(parent: Node, pos: Vector2, dmg: int, heal: bool = false) -> void:
	var popup = Label.new()
	popup.set_script(load("res://addons/player_input_module/ui/damage_popup.gd"))
	popup.position = pos
	popup.damage = dmg
	popup.is_heal = heal

	# 设置字体大小
	popup.add_theme_font_size_override("font_size", 24)

	parent.add_child(popup)
