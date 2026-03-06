class_name E2ETestRunnerBase
extends Node
## E2E 测试运行器基类
##
## 提供 E2E 测试的核心框架，项目需要继承此类并实现具体逻辑。
## 支持两种模式：
## - Host 模式：创建房间，执行 Player 0 的走子
## - Client 模式：加入房间，执行 Player 1 的走子

## 测试数据播放器
var test_data_player: E2ETestDataPlayer

## 游戏适配器（项目实现）
var game_adapter: E2EGameAdapter

## 游戏实例
var game: Object

## 测试结果
var test_result: Dictionary = {"success": false, "message": ""}

## 走子完成标志
var all_moves_completed: bool = false

## 走子完成后的等待时间（用于测试中间状态）
var completion_wait_time: float = 0.0

## 走子完成后的等待时长（默认 3 秒）
var completion_wait_duration: float = 3.0


## 初始化测试
## @param test_file: 测试数据文件路径
## @param adapter: 游戏适配器实例
## @return: 是否成功
func initialize_test(test_file: String, adapter: E2EGameAdapter) -> bool:
	if adapter == null:
		push_error("[E2ETestRunnerBase] 游戏适配器不能为空")
		return false

	game_adapter = adapter

	# 加载测试数据
	test_data_player = E2ETestDataPlayer.new()
	if not test_data_player.load_test_data(test_file):
		push_error("[E2ETestRunnerBase] 无法加载测试数据: %s" % test_file)
		return false

	# 创建游戏实例
	var game_id = test_data_player.get_game_id()
	var board_size = test_data_player.get_board_size()
	game = game_adapter.create_game(game_id, board_size)

	if game == null:
		push_error("[E2ETestRunnerBase] 无法创建游戏: %s" % game_id)
		return false

	print("[E2ETestRunnerBase] 测试初始化成功: %s" % game_id)
	return true


## 执行走子
## @param move: 走子数据
## @return: 走子结果
func execute_move(move: Dictionary) -> Dictionary:
	if game == null or game_adapter == null:
		return {"success": false, "error": "游戏未初始化"}

	return game_adapter.apply_move(game, move)


## 检查游戏结果
func check_game_result() -> void:
	if game == null or game_adapter == null:
		_fail("游戏未初始化")
		return

	var state = game_adapter.check_state(game)
	var expected = test_data_player.get_expected_result()

	print("[E2ETestRunnerBase] 当前状态: %s" % JSON.stringify(state))
	print("[E2ETestRunnerBase] 期望结果: %s" % JSON.stringify(expected))

	# 验证状态
	if not _verify_state(state, expected):
		_fail("游戏状态不符合期望")
		return

	_success("测试通过")


## 验证游戏状态是否符合期望
## @param state: 当前状态
## @param expected: 期望状态
## @return: 是否匹配
func _verify_state(state: Dictionary, expected: Dictionary) -> bool:
	# 检查 winner
	if expected.has("winner"):
		if state.get("winner", -2) != expected.winner:
			print("[E2ETestRunnerBase] ✗ winner 不匹配: 期望 %d, 实际 %d" % [
				expected.winner,
				state.get("winner", -2)
			])
			return false

	# 检查 state
	if expected.has("state"):
		if state.get("state", "") != expected.state:
			print("[E2ETestRunnerBase] ✗ state 不匹配: 期望 %s, 实际 %s" % [
				expected.state,
				state.get("state", "")
			])
			return false

	return true


## 测试成功
func _success(message: String) -> void:
	test_result = {"success": true, "message": message}
	print("[E2ETestRunnerBase] ✓ 测试通过: %s" % message)


## 测试失败
func _fail(message: String) -> void:
	test_result = {"success": false, "message": message}
	push_error("[E2ETestRunnerBase] ✗ 测试失败: %s" % message)


## 是否应该等待走子完成（可由子类重写）
func should_wait_for_completion() -> bool:
	return false  # 默认不等待


## 获取走子完成等待时长（可由子类重写）
func get_completion_wait_duration() -> float:
	return 3.0  # 默认 3 秒
