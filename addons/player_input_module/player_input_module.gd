@tool
extends EditorPlugin

func _enter_tree() -> void:
	print("[PlayerInputModule] Plugin enabled")

func _exit_tree() -> void:
	print("[PlayerInputModule] Plugin disabled")
