# GAME-RNB-GD

一个使用 Godot GDScript 开发的回合制游戏。

## 插件

项目集成了以下插件：

- **TurnBasedSystem-GD**: 回合制系统核心
- **EasyMultiplayer-GD**: 多人联机支持
- **EasySave-GD**: 存档系统
- **EasyTestBridge-GD**: 测试框架

## 项目结构

```
GAME-RNB-GD/
├── addons/              # 插件目录
├── scenes/              # 场景文件
│   └── main.tscn       # 主场景
├── scripts/             # 脚本文件
│   └── main.gd         # 主脚本
├── tests/               # 测试文件
├── assets/              # 资源文件
│   ├── sprites/        # 精灵图
│   ├── sounds/         # 音效
│   └── fonts/          # 字体
└── project.godot       # 项目配置
```

## 开发

使用 Godot 4.3+ 打开项目即可开始开发。

## 测试

使用 `/test` skill 运行测试。
