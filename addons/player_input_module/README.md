# Player Input Module

模块化的玩家输入控制系统，用于回合制游戏。提供信号驱动的输入接口和可定制的 UI 组件。

## 特性

- ✅ **完全解耦** - 与战斗系统零耦合，可独立开发和测试
- ✅ **信号驱动** - 通过标准信号接口通信
- ✅ **可复用** - 可在多个项目中复用
- ✅ **可配置** - 支持多种 UI 风格和布局模式
- ✅ **键盘快捷键** - 支持快捷键操作（A=攻击, D=防御, 1-9=选择目标）

## 安装

1. 将 `addons/player_input_module/` 目录复制到你的项目中
2. （可选）在项目设置中启用插件

## 快速开始

### 基本用法

```gdscript
# 1. 创建控制器实例
var player_input: PlayerInputController = PlayerInputController.new()
add_child(player_input)

# 2. 连接信号
player_input.input_completed.connect(_on_input_completed)

# 3. 请求玩家输入
func request_player_action(actor: Character, targets: Array[Character]):
    var context = InputContext.new(
        actor,
        ["attack", "defend"],  # 可用行动类型
        targets                # 有效目标列表
    )
    player_input.request_input(context)

    # 等待输入完成
    var action_data = await player_input.input_completed
    return action_data

# 4. 处理输入结果
func _on_input_completed(action_data: ActionData):
    print("玩家选择: %s" % action_data.action_type)
    print("目标: %s" % action_data.target.character_name if action_data.target else "无")
```

### 配置选项

```gdscript
# 配置 UI 风格
player_input.configure({
    "layout": "modern",           # "classic", "modern", "minimal"
    "show_turn_order": true,      # 是否显示行动顺序条
    "show_status_panels": true,   # 是否显示角色状态面板
    "enable_shortcuts": true,     # 是否启用键盘快捷键
})

# 设置自定义主题
var custom_theme = preload("res://themes/my_theme.tres")
player_input.set_ui_theme(custom_theme)
```

## API 文档

### InputContext

输入请求的上下文数据。

**属性：**
- `actor: Character` - 当前行动角色
- `available_actions: Array[String]` - 可用行动类型
- `valid_targets: Array[Character]` - 有效目标列表
- `metadata: Dictionary` - 额外数据

### ActionData

玩家输入的行动数据。

**属性：**
- `action_type: String` - 行动类型 ("attack", "defend", "skill", "item")
- `actor: Character` - 行动者
- `target: Character` - 目标（可选）
- `skill_id: String` - 技能ID（可选）
- `item_id: String` - 物品ID（可选）
- `metadata: Dictionary` - 额外数据

### PlayerInputController

核心控制器。

**信号：**
- `input_completed(action_data: ActionData)` - 输入完成
- `input_cancelled()` - 输入取消

**方法：**
- `request_input(context: InputContext)` - 请求玩家输入
- `cancel_input()` - 取消当前输入
- `configure(config: Dictionary)` - 配置控制器
- `set_ui_theme(theme: Theme)` - 设置 UI 主题

## 键盘快捷键

- **A** - 攻击
- **D** - 防御
- **S** - 技能
- **I** - 物品
- **R** - 逃跑
- **1-9** - 选择目标
- **ESC** - 取消

## 扩展

### 添加新的行动类型

```gdscript
# 1. 在 available_actions 中添加新类型
var context = InputContext.new(
    actor,
    ["attack", "defend", "skill", "item"],  # 新增 skill 和 item
    targets
)

# 2. 在 ActionPanel 中会自动生成对应按钮

# 3. 在你的战斗管理器中处理新的 action_type
func convert_action_data(data: ActionData) -> BaseAction:
    match data.action_type:
        "attack":
            return AttackAction.new(data.actor, data.target)
        "defend":
            return DefendAction.new(data.actor)
        "skill":
            return SkillAction.new(data.actor, data.target, data.skill_id)
        "item":
            return ItemAction.new(data.actor, data.target, data.item_id)
```

### 替换输入源

```gdscript
# 网络输入
class_name NetworkInputController
extends PlayerInputController

func request_input(context: InputContext) -> void:
    send_to_network(context)
    var response = await network_response_received
    input_completed.emit(response)

# AI 输入
class_name AIInputController
extends PlayerInputController

func request_input(context: InputContext) -> void:
    var action_data = ai_decide(context)
    input_completed.emit(action_data)
```

## 许可证

MIT License

## 作者

GAME-RNB-GD Team
