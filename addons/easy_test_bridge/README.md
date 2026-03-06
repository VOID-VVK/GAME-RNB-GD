# EasyTestBridge (GDScript)

零继承、注解驱动的 Godot 4 测试框架，纯 GDScript 实现。

## 功能

### 单元测试
- `#@test` 注解自动发现测试方法
- Tag 过滤（`#@test(tag="chess")`）
- 超时控制（`#@test(timeout=5000)`）
- 静态断言库（`TestAssert`）
- 异步测试工具（`TestContext`）
- 启动时自动运行（`run_tests_on_start`）

### E2E 测试（新增）
- 网络对战游戏的端到端测试
- JSON 格式的测试数据播放
- 游戏适配器接口（支持任意游戏）
- 预留智能测试数据生成（Minimax/MCTS/Claude API）
- 详见 [e2e/README.md](e2e/README.md)

## 安装

将 `addons/easy_test_bridge/` 复制到项目的 `addons/` 目录。

在 `project.godot` 中注册 autoload：

```ini
[autoload]
TestRunner="*res://addons/easy_test_bridge/test_runner.gd"
```

## 快速开始

在 `tests/` 目录下创建测试文件：

```gdscript
# tests/test_example.gd
extends RefCounted

#@test(tag="example")
func test_addition():
    TestAssert.are_equal(4, 2 + 2)

#@test(tag="example")
func test_array_contains():
    var arr := [1, 2, 3]
    TestAssert.array_contains(arr, 2)
```

运行游戏，测试自动执行，输出：

```
[TestRunner] 发现 2 个测试方法（1 个文件）
[TestRunner] PASS: test_addition (0ms)
[TestRunner] PASS: test_array_contains (0ms)
[TestRunner] 测试完成: 2 总计, 2 通过, 0 失败 (1ms)
```

## 断言 API

| 方法 | 说明 |
|------|------|
| `TestAssert.is_true(value, msg)` | 值为 true |
| `TestAssert.is_false(value, msg)` | 值为 false |
| `TestAssert.are_equal(expected, actual, msg)` | 相等 |
| `TestAssert.are_not_equal(expected, actual, msg)` | 不相等 |
| `TestAssert.is_null(value, msg)` | 值为 null |
| `TestAssert.is_not_null(value, msg)` | 值不为 null |
| `TestAssert.is_in_range(value, min, max, msg)` | 值在范围内 |
| `TestAssert.array_contains(arr, item, msg)` | 数组包含元素 |
| `TestAssert.array_not_contains(arr, item, msg)` | 数组不包含元素 |
| `TestAssert.fail(msg)` | 显式失败 |

## 目录结构

```
addons/easy_test_bridge/
  plugin.cfg              插件配置
  easy_test_bridge.gd     EditorPlugin 入口
  test_runner.gd          单元测试运行器（Autoload）
  test_assert.gd          静态断言库
  test_context.gd         异步测试工具
  e2e/                    E2E 测试模块
    test_data_player.gd   测试数据播放器
    game_adapter.gd       游戏适配器接口
    test_runner_base.gd   测试运行器基类
    test_generator.gd     测试生成器接口
    README.md             E2E 模块文档
```

## License

MIT
