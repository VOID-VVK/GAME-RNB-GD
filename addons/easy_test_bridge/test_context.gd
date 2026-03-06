class_name TestContext extends RefCounted
## 异步测试工具 — 提供帧等待和时间等待


## 等待指定帧数
static func wait_frames(tree: SceneTree, count: int) -> void:
	for i in count:
		await tree.process_frame


## 等待指定秒数
static func wait_seconds(tree: SceneTree, seconds: float) -> void:
	await tree.create_timer(seconds).timeout
