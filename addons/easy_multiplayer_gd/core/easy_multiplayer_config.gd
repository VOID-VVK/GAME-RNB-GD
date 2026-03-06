class_name EasyMultiplayerConfig
extends Resource

## EasyMultiplayer 配置资源类。
## 所有可配置参数通过 Resource 暴露，支持 Inspector 编辑和 .tres 文件持久化。

# ── 连接 ──

## ENet 监听/连接端口
@export var port: int = 27015

## 最大客户端数
@export var max_clients: int = 1

# ── 心跳 ──

## 心跳 Ping 发送间隔（秒）
@export var heartbeat_interval: float = 3.0

## 判定对端断线的超时阈值（秒）
@export var disconnect_timeout: float = 10.0

# ── 重连 ──

## Host 端等待对端重连的上限时间（秒）
@export var reconnect_timeout: float = 30.0

## Client 端最大重连尝试次数
@export var max_reconnect_attempts: int = 20

## Client 端每次重连尝试的间隔（秒）
@export var reconnect_retry_interval: float = 3.0

# ── 消息 ──

## 消息通道每通道最小发送间隔（毫秒），0 表示不限制
@export var rpc_min_interval_ms: float = 100.0

# ── 兜底检查 ──

## 兜底连接检查间隔（秒）。GameSession 和 NetworkLobby 使用此值定期检查连接状态
@export var fallback_check_interval: float = 10.0

## 进入场景后的兜底检查宽限期（秒）。在此期间不执行兜底检查，避免场景切换期间误触发
@export var fallback_grace_period: float = 5.0

# ── 发现 ──

## UDP 广播端口
@export var broadcast_port: int = 27016

## 广播发送间隔（秒）
@export var broadcast_interval: float = 1.0

## 房间超时移除阈值（秒）。超过此时间未收到广播的房间将被移除
@export var room_timeout: float = 5.0
