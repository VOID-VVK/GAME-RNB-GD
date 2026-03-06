class_name E2EGameAdapter
extends RefCounted
## E2E 游戏适配器接口
##
## 项目需要实现此接口，以适配不同游戏的 API。
## 这样 E2E 测试框架就可以支持任意游戏。

## 创建游戏实例
## @param game_id: 游戏 ID（如 "gomoku", "chess", "wolf_sheep"）
## @param board_size: 棋盘大小（可选）
## @return: 游戏实例对象
func create_game(game_id: String, board_size: Dictionary = {}) -> Object:
	push_error("[E2EGameAdapter] create_game() 必须由子类实现")
	return null


## 应用走子
## @param game: 游戏实例
## @param move: 走子数据（格式由游戏决定）
## @return: 走子结果 {success: bool, ...}
func apply_move(game: Object, move: Dictionary) -> Dictionary:
	push_error("[E2EGameAdapter] apply_move() 必须由子类实现")
	return {"success": false, "error": "未实现"}


## 检查游戏状态
## @param game: 游戏实例
## @return: 游戏状态 {finished: bool, winner: int, ...}
func check_state(game: Object) -> Dictionary:
	push_error("[E2EGameAdapter] check_state() 必须由子类实现")
	return {"finished": false}


## 获取游戏状态的字符串表示（用于调试）
## @param game: 游戏实例
## @return: 状态字符串
func get_state_string(game: Object) -> String:
	# 默认实现：返回 check_state 的 JSON
	var state = check_state(game)
	return JSON.stringify(state)
