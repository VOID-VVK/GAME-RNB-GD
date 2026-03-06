# E2E 测试模块

为网络对战游戏提供端到端（E2E）测试支持。

## 功能特性

- **测试数据播放器** - 从 JSON 文件加载并回放测试数据
- **游戏适配器接口** - 支持任意游戏的 API 适配
- **测试运行器基类** - 提供 Host/Client 测试框架
- **智能生成器接口** - 预留智能测试数据生成（Minimax/MCTS/Claude API）

## 快速开始

### 1. 实现游戏适配器

```gdscript
# my_game_adapter.gd
class_name MyGameAdapter
extends E2EGameAdapter

func create_game(game_id: String, board_size: Dictionary = {}) -> Object:
    match game_id:
        "gomoku": return GomokuGame.new()
        "chess": return ChessGame.new()
        _: return null

func apply_move(game: Object, move: Dictionary) -> Dictionary:
    # 根据游戏 API 调用走子方法
    if move.has("pos"):
        return game.apply_move(Vector2i(move.pos.x, move.pos.y))
    elif move.has("from") and move.has("to"):
        return game.apply_move(
            Vector2i(move.from.x, move.from.y),
            Vector2i(move.to.x, move.to.y)
        )
    return {"success": false}

func check_state(game: Object) -> Dictionary:
    return game.check_state()
```

### 2. 准备测试数据

```json
{
  "game_id": "gomoku",
  "description": "横向五连获胜",
  "board_size": {"width": 15, "height": 15},
  "moves": [
    {"player": 0, "pos": {"x": 7, "y": 7}, "comment": "黑方落子中心"},
    {"player": 1, "pos": {"x": 7, "y": 8}, "comment": "白方应对"},
    ...
  ],
  "expected_result": {
    "winner": 0,
    "state": "finished",
    "reason": "horizontal_five"
  }
}
```

### 3. 创建测试运行器

```gdscript
# host_runner.gd
extends E2ETestRunnerBase

func _ready():
    var adapter = MyGameAdapter.new()
    var test_file = "res://tests/data/gomoku_test_01.json"

    if not initialize_test(test_file, adapter):
        get_tree().quit(1)
        return

    # 创建网络房间
    NetworkManager.create_room("test_room", test_data_player.get_game_id())
    NetworkManager.peer_joined.connect(_on_peer_joined)
    NetworkManager.move_received.connect(_on_move_received)

func _on_peer_joined(peer_id: int):
    # 开始执行 Player 0 的走子
    _execute_next_move()

func _execute_next_move():
    var move = test_data_player.get_next_move_for_player(0)
    if move.is_empty():
        all_moves_completed = true
        return

    var result = execute_move(move)
    if result.success:
        NetworkManager.send_move(move, result)
```

## 测试数据格式

### 基本结构

```json
{
  "game_id": "游戏ID",
  "description": "测试描述",
  "board_size": {"width": 15, "height": 15},
  "moves": [...],
  "expected_result": {...}
}
```

### 走子格式

不同游戏的走子格式不同，由游戏适配器处理：

```json
// 五子棋/井字棋（单点落子）
{"player": 0, "pos": {"x": 7, "y": 7}}

// 象棋/狼吃羊（起点到终点）
{"player": 0, "from": {"x": 0, "y": 0}, "to": {"x": 1, "y": 2}}
```

### 期望结果

```json
{
  "winner": 0,           // 获胜者（0/1/-1=平局）
  "state": "finished",   // 状态（finished/in_progress/draw）
  "reason": "horizontal_five"  // 原因（可选）
}
```

## 高级功能

### 测试中间状态

如果需要测试游戏的中间状态（而不是走到结束），可以重写 `should_wait_for_completion()`：

```gdscript
func should_wait_for_completion() -> bool:
    var expected = test_data_player.get_expected_result()
    return expected.get("state", "") == "in_progress"
```

### 智能测试数据生成（预留）

```gdscript
# 未来版本：智能生成器
class_name ChessTestGenerator
extends E2ETestGenerator

func generate_scenario(game_id: String, scenario: String, options: Dictionary = {}) -> Dictionary:
    var game = ChessGame.new()
    var ai = MinimaxEngine.new()  # 或 MCTS / Claude API

    # 目标：生成"将军"场景
    while not is_check(game):
        var best_move = ai.find_move_towards_goal(game, "check")
        game.apply_move(best_move)

    return {
        "game_id": game_id,
        "description": "AI 生成的将军场景",
        "moves": game.get_move_history(),
        "expected_result": {"state": "in_progress", "reason": "check"}
    }
```

## 架构设计

```
e2e/
├── test_data_player.gd      # 测试数据播放器（通用）
├── game_adapter.gd          # 游戏适配器接口（项目实现）
├── test_runner_base.gd      # 测试运行器基类（通用）
└── test_generator.gd        # 测试生成器接口（预留智能生成）
```

## 适用场景

- ✅ 棋牌游戏（五子棋、象棋、围棋、狼吃羊）
- ✅ 回合制游戏（卡牌、战棋）
- ✅ 需要测试中间状态的游戏
- ✅ 需要智能生成测试数据的复杂游戏

## License

MIT
