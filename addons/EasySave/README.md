# EasySave-GD

Godot 4.x GDScript 存档插件 — 基于 Resource 序列化的槽位存档系统。

## 特性

- **槽位管理**: 多槽位存档/读档/删除
- **Resource 序列化**: 利用 Godot 原生 Resource 系统，自动序列化 `@export` 字段
- **跨场景传递**: `load_to_slot` + `consume_pending_load` 模式
- **信号通知**: `slot_saved` / `slot_loaded` 信号
- **零依赖**: 纯 GDScript，无第三方库

## 安装

### Godot Asset Library

在 Godot 编辑器中搜索 "EasySave" 并安装。

### 手动安装

将 `addons/EasySave/` 复制到项目的 `addons/` 目录，在 Project Settings → Plugins 中启用。

## 快速开始

### 1. 定义存档数据

```gdscript
# my_save.gd
class_name MySave
extends EasySaveData

@export var current_scene: String = ""
@export var player_level: int = 0
@export var player_pos: Vector2i = Vector2i.ZERO
```

### 2. 存档

```gdscript
var save := MySave.new()
save.current_scene = get_tree().current_scene.scene_file_path
save.player_level = 10
save.player_pos = Vector2i(5, 3)
EasySave.instance.save_to_slot(1, save)
```

### 3. 读档

```gdscript
var data := EasySave.instance.load_from_slot(1) as MySave
if data:
    print("Level: %d, Pos: %s" % [data.player_level, data.player_pos])
```

## API

| 方法 | 说明 |
|------|------|
| `save_to_slot(slot, data)` | 存档到指定槽位 |
| `load_from_slot(slot)` | 从槽位加载数据 |
| `load_to_slot(slot)` | 加载并暂存（跨场景用） |
| `consume_pending_load()` | 取出暂存数据（取一次清空） |
| `peek_slot(slot)` | 只读元数据 |
| `has_save(slot)` | 检查槽位是否有存档 |
| `delete_slot(slot)` | 删除槽位 |

## 配置

通过 `EasySaveConfig` Resource 配置：

- `slot_count` — 槽位数量（默认 3）
- `save_directory` — 存档目录（默认 `user://saves`）

## License

MIT
