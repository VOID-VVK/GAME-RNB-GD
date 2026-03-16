# 玩家输入系统信号链断裂修复总结

## 问题描述

游戏在第一个玩家选择行动和目标后卡住，BattleManager 的 `await player_input_controller.input_completed` 永远不会恢复。

## 根本原因

信号链存在三个问题：

### 1. 键盘快捷键 bug
**位置**: `addons/player_input_module/ui/target_selector.gd:40`

**问题**: 创建目标按钮时没有设置 metadata，导致键盘快捷键（1-9）无法获取目标对象。

**修复**: 在创建按钮时添加：
```gdscript
button.set_meta("target", target)
```

### 2. 信号连接时机问题
**位置**: `addons/player_input_module/core/player_input_controller.gd:40-42`

**问题**:
- `_ready()` 使用 `call_deferred("_initialize_ui")` 延迟初始化
- `request_input()` 只等待一帧
- 如果 UI 初始化还没完成，信号连接会失败

**修复**:
1. 改为同步初始化：`_ready()` 直接调用 `_initialize_ui()`
2. 在 `_initialize_ui()` 中等待 BattleUI 完全 ready：
```gdscript
if not _battle_ui.is_node_ready():
    await _battle_ui.ready
```
3. 移除 `request_input()` 中的等待逻辑

### 3. 状态重置时机问题（核心问题）
**位置**: `addons/player_input_module/core/player_input_controller.gd:143-162`

**问题**:
- `_complete_input()` 先发出 `input_completed` 信号，然后才调用 `_reset_state()`
- Godot 的信号是同步的，所以 BattleManager 的回调会立即执行
- 在回调中，BattleManager 会请求下一个玩家的输入
- 但此时 PlayerInputController 的状态还是 `COMPLETED`，不是 `IDLE`
- 导致新的 `request_input()` 被拒绝

**修复**: 在发出信号之前先重置状态：
```gdscript
func _complete_input(target: Character) -> void:
    var action_data = ActionData.new(_selected_action_type, _current_context.actor, target)

    # 隐藏 UI
    if _battle_ui:
        _battle_ui.hide_all()

    # 先重置状态（在发送信号之前）
    _reset_state()

    # 发送信号（此时状态已经是 IDLE，可以接受新的请求）
    input_completed.emit(action_data)
```

## 验证

创建了 `scripts/debug/auto_test.gd` 自动测试脚本，模拟玩家点击：
- 监听 `character_turn_started` 信号
- 自动选择攻击行动
- 自动选择第一个目标
- 验证信号链完整流转

测试结果：
- ✅ 信号连接成功
- ✅ 第一个玩家输入完成
- ✅ 第二个玩家输入请求成功（状态是 IDLE）
- ✅ 战斗流程正常进行

## 修改的文件

1. `/Users/void/Documents/GAME-RNB-GD/addons/player_input_module/ui/target_selector.gd`
   - 添加 `button.set_meta("target", target)`

2. `/Users/void/Documents/GAME-RNB-GD/addons/player_input_module/core/player_input_controller.gd`
   - 改为同步初始化 UI
   - 等待 BattleUI ready
   - 在发出信号前重置状态

3. `/Users/void/Documents/GAME-RNB-GD/scripts/debug/auto_test.gd` (新增)
   - 自动测试脚本

4. `/Users/void/Documents/GAME-RNB-GD/scenes/main.tscn`
   - 添加 AutoTest 节点

## 经验教训

1. **Godot 信号是同步的**：信号发出后，所有连接的回调会立即执行，然后才继续执行后续代码。
2. **状态管理要谨慎**：在发出可能触发新请求的信号之前，确保状态已经准备好接受新请求。
3. **初始化时机很重要**：使用 `call_deferred` 会导致初始化延迟，可能引发竞态条件。
4. **调试日志是关键**：详细的日志帮助我们快速定位问题（信号流、状态变化）。

## 后续建议

1. 考虑将 AutoTest 改为可配置的调试工具（通过环境变量或配置文件启用）
2. 添加更多的状态断言，确保状态转换的正确性
3. 考虑添加单元测试覆盖信号流
