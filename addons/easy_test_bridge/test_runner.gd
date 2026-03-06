extends Node
## 测试运行器 — 发现并执行带 #@test 注解的测试方法（Autoload）

## 测试结果结构: {name: String, passed: bool, time_ms: int, error: String}
var _results: Array = []
var _test_entries: Array = []  # {file: String, method: String, tag: String, timeout: int}
var _running: bool = false

## 启动时自动运行测试
@export var run_tests_on_start: bool = true


func _ready() -> void:
	if run_tests_on_start:
		call_deferred("_auto_run")


func _auto_run() -> void:
	discover()
	run_all()


## 递归发现测试目录下所有带 #@test 注解的方法
func discover(test_dir: String = "res://tests/") -> void:
	_test_entries.clear()
	var files := _scan_gd_files(test_dir)
	for file_path in files:
		var source := FileAccess.get_file_as_string(file_path)
		if source == "":
			continue
		var annotations := _parse_test_annotations(source)
		for ann in annotations:
			_test_entries.append({
				"file": file_path,
				"method": ann["method"],
				"tag": ann["tag"],
				"timeout": ann["timeout"],
			})
	print("[TestRunner] 发现 %d 个测试方法（%d 个文件）" % [_test_entries.size(), files.size()])


## 运行所有已发现的测试，可按 tag 过滤
func run_all(tag_filter: String = "") -> void:
	if _running:
		push_warning("[TestRunner] 测试已在运行中")
		return
	_running = true
	_results.clear()
	var total_start := Time.get_ticks_msec()

	for entry in _test_entries:
		# tag 过滤
		if tag_filter != "" and entry["tag"] != tag_filter:
			continue
		var test_name: String = entry["method"]
		var start := Time.get_ticks_msec()

		# 重置断言状态
		TestAssert.reset()

		# 加载脚本并创建实例
		var script: GDScript = load(entry["file"]) as GDScript
		if script == null:
			_results.append({"name": test_name, "passed": false, "time_ms": 0, "error": "无法加载 %s" % entry["file"]})
			print("[TestRunner] FAIL: %s - 无法加载脚本" % test_name)
			continue

		var instance = script.new()

		# 调用测试方法
		if instance.has_method(test_name):
			instance.call(test_name)
		else:
			_results.append({"name": test_name, "passed": false, "time_ms": 0, "error": "方法不存在: %s" % test_name})
			print("[TestRunner] FAIL: %s - 方法不存在" % test_name)
			# 清理实例
			if instance is Node:
				instance.queue_free()
			continue

		var elapsed := Time.get_ticks_msec() - start

		# 检查断言结果
		if TestAssert._failed:
			_results.append({"name": test_name, "passed": false, "time_ms": elapsed, "error": TestAssert._failure_message})
			print("[TestRunner] FAIL: %s - %s (%dms)" % [test_name, TestAssert._failure_message, elapsed])
		else:
			_results.append({"name": test_name, "passed": true, "time_ms": elapsed, "error": ""})
			print("[TestRunner] PASS: %s (%dms)" % [test_name, elapsed])

		# 清理实例
		if instance is Node:
			instance.queue_free()

	var total_elapsed := Time.get_ticks_msec() - total_start
	var passed := _results.filter(func(r): return r["passed"]).size()
	var failed := _results.size() - passed
	print("[TestRunner] 测试完成: %d 总计, %d 通过, %d 失败 (%dms)" % [_results.size(), passed, failed, total_elapsed])
	_running = false


## 解析源码中的 #@test 注解，返回 [{method, tag, timeout}]
func _parse_test_annotations(source: String) -> Array:
	var results: Array = []
	var lines := source.split("\n")
	for i in range(lines.size()):
		var line := lines[i].strip_edges()
		if not line.begins_with("#@test"):
			continue
		# 解析注解参数
		var tag := ""
		var timeout := 5000
		var paren_start := line.find("(")
		if paren_start != -1:
			var paren_end := line.find(")", paren_start)
			if paren_end != -1:
				var params_str := line.substr(paren_start + 1, paren_end - paren_start - 1)
				# 解析 key=value 对
				for param in params_str.split(","):
					var kv := param.strip_edges().split("=")
					if kv.size() == 2:
						var key := kv[0].strip_edges()
						var val := kv[1].strip_edges().trim_prefix("\"").trim_suffix("\"")
						if key == "tag":
							tag = val
						elif key == "timeout":
							timeout = int(val)
		# 查找下一个 func 行
		for j in range(i + 1, mini(i + 5, lines.size())):
			var func_line := lines[j].strip_edges()
			if func_line.begins_with("func "):
				var name_end := func_line.find("(")
				if name_end != -1:
					var method_name := func_line.substr(5, name_end - 5).strip_edges()
					results.append({"method": method_name, "tag": tag, "timeout": timeout})
				break
	return results


## 递归扫描目录下所有 .gd 文件
func _scan_gd_files(dir_path: String) -> Array:
	var files: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("[TestRunner] 无法打开目录: %s" % dir_path)
		return files
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := dir_path.path_join(file_name)
		if dir.current_is_dir():
			files.append_array(_scan_gd_files(full_path))
		elif file_name.ends_with(".gd"):
			files.append(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	return files
