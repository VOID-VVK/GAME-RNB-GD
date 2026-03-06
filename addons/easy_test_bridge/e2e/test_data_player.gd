class_name E2ETestDataPlayer
extends RefCounted
## E2E 测试数据播放器
##
## 从 JSON 文件加载测试数据，按照预定义的走子序列回放。
## 适用于网络对战游戏的 E2E 测试。

var test_data: Dictionary = {}
var current_move_index: int = 0


## 加载测试数据文件
func load_test_data(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		push_error("[E2ETestDataPlayer] 测试数据文件不存在: %s" % file_path)
		return false

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[E2ETestDataPlayer] 无法打开测试数据文件: %s" % file_path)
		return false

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("[E2ETestDataPlayer] JSON 解析失败: %s (行 %d)" % [
			json.get_error_message(),
			json.get_error_line()
		])
		return false

	test_data = json.data
	current_move_index = 0

	print("[E2ETestDataPlayer] 加载测试数据: %s (%d 步)" % [
		test_data.get("description", ""),
		test_data.get("moves", []).size()
	])
	return true


## 获取游戏 ID
func get_game_id() -> String:
	return test_data.get("game_id", "")


## 获取棋盘大小
func get_board_size() -> Dictionary:
	return test_data.get("board_size", {})


## 获取总步数
func get_total_moves() -> int:
	return test_data.get("moves", []).size()


## 是否还有下一步
func has_next_move() -> bool:
	return current_move_index < get_total_moves()


## 获取下一步走子（不移动索引）
func peek_next_move() -> Dictionary:
	if not has_next_move():
		return {}

	var moves = test_data.get("moves", [])
	return moves[current_move_index]


## 获取下一步走子并移动索引
func get_next_move() -> Dictionary:
	var move = peek_next_move()
	if not move.is_empty():
		current_move_index += 1
	return move


## 获取指定玩家的下一步走子
func get_next_move_for_player(player_id: int) -> Dictionary:
	while has_next_move():
		var move = peek_next_move()
		if move.get("player", -1) == player_id:
			current_move_index += 1
			return move
		else:
			# 跳过其他玩家的走子
			current_move_index += 1

	return {}


## 获取期望的游戏结果
func get_expected_result() -> Dictionary:
	return test_data.get("expected_result", {})


## 重置回放索引
func reset() -> void:
	current_move_index = 0
