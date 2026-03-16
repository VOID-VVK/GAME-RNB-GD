# 玩家输入卡住问题修复记录

**日期**: 2026-03-16
**问题**: 玩家选择行动后游戏卡住，无法继续操作

## 问题分析

### 根本原因
BattleManager 在 `_get_player_action()` 方法中使用 `await player_input_controller.input_completed` 等待玩家输入完成，但由于以下两个 bug，该信号永远不会触发，导致 await 永远卡住。

### 发现的 Bug

#### Bug 1: TargetSelector 键盘快捷键失效
**文件**: `addons/player_input_module/ui/target_selector.gd`
**位置**: 第 40 行和第 69 行

**问题描述**:
- 按钮创建时使用 `.bind(target)` 绑定目标对象
- 但从未调用 `set_meta("target", target)` 存储引用
- 导致键盘快捷键处理函数无法通过 `get_meta("target")` 获取目标对象

**影响**: 键盘快捷键（数字键 1-9）无法选择目标

**修复**:
```gdscript
button.set_meta("target", target)  # 添加这一行
button.pressed.connect(_on_target_button_pressed.bind(target))
```

#### Bug 2: UI 初始化时机问题（主要问题）
**文件**: `addons/player_input_module/core/player_input_controller.gd`
**位置**: 第 42 行和第 66-77 行

**问题描述**:
1. `_ready()` 中使用 `call_deferred("_initialize_ui")` 延迟初始化 UI
2. `_initialize_ui()` 实例化 BattleUI 并连接信号
3. `request_input()` 只等待一帧就假设 UI 已初始化完成
4. 如果信号连接未完成，整个信号链路会断裂

**信号链路**:
```
用户点击按钮
→ ActionPanel.action_selected.emit()
→ BattleUI._on_action_selected() → BattleUI.action_selected.emit()
→ PlayerInputController._on_action_selected()
→ BattleUI.show_target_selector()
→ 用户点击目标
→ TargetSelector.target_selected.emit()
→ BattleUI._on_target_selected() → BattleUI.target_selected.emit()
→ PlayerInputController._on_target_selected()
→ PlayerInputController._complete_input()
→ PlayerInputController.input_completed.emit()  ← BattleManager 在这里等待
```

**影响**: 如果信号连接未完成，`input_completed` 信号永远不会触发，BattleManager 的 await 永远卡住

**修复**:
```gdscript
func _ready() -> void:
    # 同步初始化 UI（不使用 call_deferred）
    _initialize_ui()

func _initialize_ui() -> void:
    var battle_ui_scene = load("res://addons/player_input_module/scenes/battle_ui.tscn")
    if battle_ui_scene:
        _battle_ui = battle_ui_scene.instantiate()
        add_child(_battle_ui)

        # 等待 BattleUI 完全 ready
        if not _battle_ui.is_node_ready():
            await _battle_ui.ready

        # 连接 UI 信号
        if _battle_ui.has_signal("action_selected"):
            _battle_ui.action_selected.connect(_on_action_selected)
        # ... 其他信号连接
```

## 修复内容

### 1. TargetSelector.gd
- 添加 `button.set_meta("target", target)` 存储目标引用
- 添加调试日志追踪按钮点击和信号发送

### 2. PlayerInputController.gd
- 移除 `call_deferred`，改为同步初始化
- 添加 `await _battle_ui.ready` 确保 UI 完全初始化
- 简化 `request_input()` 的检查逻辑
- 添加详细的调试日志追踪信号流

### 3. BattleUI.gd
- 添加调试日志追踪信号转发

## 调试日志

修复后的代码在关键节点添加了调试日志：

```
[PlayerInputController] Connected action_selected signal
[PlayerInputController] Connected target_selected signal
[PlayerInputController] Connected input_cancelled signal
[PlayerInputController] UI initialized successfully
[PlayerInputController] Requesting input for <角色名>
[PlayerInputController] Action panel displayed
[PlayerInputController] Action selected: attack
[TargetSelector] Target button pressed: <目标名>
[TargetSelector] target_selected signal emitted
[BattleUI] Received target_selected from TargetSelector: <目标名>
[BattleUI] target_selected signal forwarded
[PlayerInputController] Received target_selected signal: <目标名>
[PlayerInputController] Target selected: <目标名>
[PlayerInputController] Input completed: <ActionData>
[PlayerInputController] Emitting input_completed signal
[PlayerInputController] input_completed signal emitted
```

## 验证方法

运行游戏并观察控制台输出：
1. 确认所有信号连接成功
2. 确认信号链路完整（从 action_selected 到 input_completed）
3. 确认 BattleManager 的 await 能够正常恢复执行

## 经验教训

1. **避免使用 call_deferred 初始化关键组件**：如果后续代码依赖初始化完成，应该使用同步初始化或明确的 await
2. **信号连接时机很重要**：确保在使用信号前，所有连接都已完成
3. **添加调试日志**：在信号密集的代码中，详细的日志可以快速定位问题
4. **测试异步流程**：await 和信号的组合容易出现时机问题，需要仔细测试

## 相关文件

- `scripts/battle/battle_manager.gd` - 战斗管理器，使用 await 等待玩家输入
- `addons/player_input_module/core/player_input_controller.gd` - 玩家输入控制器
- `addons/player_input_module/ui/battle_ui.gd` - 战斗 UI 根容器
- `addons/player_input_module/ui/action_panel.gd` - 行动选择面板
- `addons/player_input_module/ui/target_selector.gd` - 目标选择器
