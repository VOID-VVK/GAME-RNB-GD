class_name TestAssert extends RefCounted
## 静态断言库 — 失败时设置状态，由 TestRunner 检查

# 断言状态
static var _failed: bool = false
static var _failure_message: String = ""


## 重置断言状态（每个测试前调用）
static func reset() -> void:
	_failed = false
	_failure_message = ""


## 值为 true
static func is_true(value: bool, msg: String = "") -> void:
	if _failed:
		return
	if not value:
		_set_failure(msg if msg != "" else "期望 true，实际 false")


## 值为 false
static func is_false(value: bool, msg: String = "") -> void:
	if _failed:
		return
	if value:
		_set_failure(msg if msg != "" else "期望 false，实际 true")


## 相等
static func are_equal(expected: Variant, actual: Variant, msg: String = "") -> void:
	if _failed:
		return
	if expected != actual:
		var detail := "期望 %s，实际 %s" % [str(expected), str(actual)]
		_set_failure(msg if msg != "" else detail)


## 不相等
static func are_not_equal(expected: Variant, actual: Variant, msg: String = "") -> void:
	if _failed:
		return
	if expected == actual:
		var detail := "期望不等于 %s，但相等" % str(actual)
		_set_failure(msg if msg != "" else detail)


## 值为 null
static func is_null(value: Variant, msg: String = "") -> void:
	if _failed:
		return
	if value != null:
		_set_failure(msg if msg != "" else "期望 null，实际 %s" % str(value))


## 值不为 null
static func is_not_null(value: Variant, msg: String = "") -> void:
	if _failed:
		return
	if value == null:
		_set_failure(msg if msg != "" else "期望非 null，实际为 null")


## 值在范围内 [min_val, max_val]
static func is_in_range(value: float, min_val: float, max_val: float, msg: String = "") -> void:
	if _failed:
		return
	if value < min_val or value > max_val:
		var detail := "期望 %s 在 [%s, %s] 范围内" % [str(value), str(min_val), str(max_val)]
		_set_failure(msg if msg != "" else detail)


## 数组包含元素
static func array_contains(arr: Array, item: Variant, msg: String = "") -> void:
	if _failed:
		return
	if not arr.has(item):
		_set_failure(msg if msg != "" else "数组不包含 %s" % str(item))


## 数组不包含元素
static func array_not_contains(arr: Array, item: Variant, msg: String = "") -> void:
	if _failed:
		return
	if arr.has(item):
		_set_failure(msg if msg != "" else "数组不应包含 %s" % str(item))


## 显式失败
static func fail(msg: String = "Explicit fail") -> void:
	if _failed:
		return
	_set_failure(msg)


# ---- 内部 ----

static func _set_failure(msg: String) -> void:
	_failed = true
	_failure_message = msg
	push_error("[TestAssert] %s" % msg)
