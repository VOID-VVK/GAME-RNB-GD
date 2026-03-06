class_name E2ETestGenerator
extends RefCounted
## E2E 测试数据生成器接口
##
## 用于生成 E2E 测试数据。支持两种模式：
## 1. 手工设计模式（V1）：AI 辅助设计，硬编码走子序列
## 2. 智能生成模式（V2）：内置智能决策引擎（Minimax/MCTS/Claude API）

## 生成测试场景
## @param game_id: 游戏 ID
## @param scenario: 场景名称（如 "horizontal_win", "check", "trapped"）
## @param options: 生成选项（可选）
## @return: 测试数据 Dictionary，格式与 JSON 测试数据一致
func generate_scenario(game_id: String, scenario: String, options: Dictionary = {}) -> Dictionary:
	push_error("[E2ETestGenerator] generate_scenario() 必须由子类实现")
	return {}


## 验证生成的测试数据是否合法
## @param test_data: 测试数据
## @return: {valid: bool, error: String}
func validate_test_data(test_data: Dictionary) -> Dictionary:
	# 默认实现：基本验证
	if not test_data.has("game_id"):
		return {"valid": false, "error": "缺少 game_id"}

	if not test_data.has("moves"):
		return {"valid": false, "error": "缺少 moves"}

	if not test_data.has("expected_result"):
		return {"valid": false, "error": "缺少 expected_result"}

	return {"valid": true, "error": ""}


## 保存测试数据到文件
## @param test_data: 测试数据
## @param file_path: 文件路径
## @return: 是否成功
func save_test_data(test_data: Dictionary, file_path: String) -> bool:
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("[E2ETestGenerator] 无法创建文件: %s" % file_path)
		return false

	file.store_string(JSON.stringify(test_data, "\t"))
	file.close()

	print("[E2ETestGenerator] 测试数据已保存: %s" % file_path)
	return true
