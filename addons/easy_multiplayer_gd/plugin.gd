@tool
extends EditorPlugin

## EasyMultiplayer 编辑器插件入口。
## 负责插件的启用和禁用生命周期管理。


const AUTOLOAD_NAME = "EasyMultiplayer"
const AUTOLOAD_PATH = "res://addons/easy_multiplayer_gd/easy_multiplayer.gd"


## 插件启用时调用
func _enter_tree() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	print("[EasyMultiplayer] Plugin enabled. Autoload '%s' registered." % AUTOLOAD_NAME)


## 插件禁用时调用
func _exit_tree() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
	print("[EasyMultiplayer] Plugin disabled. Autoload '%s' removed." % AUTOLOAD_NAME)
