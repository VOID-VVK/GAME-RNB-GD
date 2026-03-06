class_name DiscoveryBase
extends Node

## 房间发现层抽象基类。所有发现实现（UDP 广播、Lobby 服务器等）均需继承此类。
##
## 广播端（Host）通过 start_broadcast() 定期发送房间信息，
## 监听端（Client）通过 start_listening() 接收并维护可用房间列表。
##
## 超时时间和广播间隔通过 EasyMultiplayerConfig 配置，不再硬编码。

# ── 事件 ──

## 发现新房间时触发
signal room_found(room: RoomInfo.DiscoveredRoom)

## 房间超时消失时触发。参数为房间键（"ip:port"）
signal room_lost(room_key: String)

## 房间列表发生变化时触发（新增、更新或移除）
signal room_list_updated()

# ── 属性 ──

## 当前是否正在广播
var is_broadcasting: bool = false:
	get: return is_broadcasting

## 当前是否正在监听
var is_listening: bool = false:
	get: return is_listening

## 当前发现的房间列表。键为 "ip:port" 格式
var rooms: Dictionary = {}:
	get: return rooms

# ── 广播端（Host） ──

## 开始广播房间信息
## info: 要广播的房间信息
func start_broadcast(info: RoomInfo) -> void:
	push_error("DiscoveryBase.start_broadcast() 必须被子类实现")

## 停止广播
func stop_broadcast() -> void:
	push_error("DiscoveryBase.stop_broadcast() 必须被子类实现")

# ── 监听端（Client） ──

## 开始监听房间广播
func start_listening() -> void:
	push_error("DiscoveryBase.start_listening() 必须被子类实现")

## 停止监听
func stop_listening() -> void:
	push_error("DiscoveryBase.stop_listening() 必须被子类实现")
