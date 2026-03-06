class_name RoomClient
extends Node

## 房间客户端逻辑。负责搜索房间、加入房间、管理准备状态。
##
## 客户端状态机：Idle → Searching → Joining → InRoom → GameStarting。
## 通过 DiscoveryBase 搜索局域网房间，通过 TransportBase 连接到主机。
##
## 与千棋世界的 RoomClient 不同，此实现不依赖 EventBus 和 Godot RPC，
## 所有房间控制消息通过 MessageChannel 传输，保持与 TransportBase 抽象的一致性。

# ── 内部消息通道标识（与 RoomHost 一致） ──

## 房间内部控制消息通道
const ROOM_CHANNEL: String = "__room_ctrl"

# ── 消息类型前缀（与 RoomHost 一致） ──

const MSG_GUEST_READY: String = "guest_ready:"
const MSG_HOST_READY: String = "host_ready:"
const MSG_GAME_START: String = "game_start:"
const MSG_ROOM_INFO: String = "room_info:"

# ── 依赖 ──

var _transport: TransportBase = null
var _discovery: DiscoveryBase = null
var _message_channel: MessageChannel = null

# ── 状态 ──

var _state: ConnectionState.ClientState = ConnectionState.ClientState.IDLE

## 当前客户端状态
var state: ConnectionState.ClientState:
	get: return _state
	set(value):
		if _state == value:
			return
		var old = _state
		_state = value
		print("[RoomClient] 客户端状态: ", old, " → ", value)
		client_state_changed.emit(old, value)

## 当前加入的房间信息
var current_room: RoomInfo = null

## 当前房间的 Host IP
var current_host_ip: String = ""

## 本地准备状态
var is_ready: bool = false

## 房主准备状态
var host_ready: bool = false

# ── Godot 信号 ──

## 客户端状态转换时触发
signal client_state_changed(old_state: ConnectionState.ClientState, new_state: ConnectionState.ClientState)

## 成功加入房间时触发
signal join_succeeded(room_name: String, game_type: String)

## 加入房间失败时触发
signal join_failed(reason: String)

## 房主准备状态变更时触发
signal host_ready_changed(ready: bool)

## 收到游戏开始通知时触发
signal game_starting(game_type: String)

## 与房间断开连接时触发
signal disconnected_from_room(reason: String)


# ── 初始化 ──

## 设置依赖。应在使用前调用
func setup(transport: TransportBase, discovery: DiscoveryBase, message_channel: MessageChannel) -> void:
	# 清理旧绑定
	if _transport != null:
		_transport.connection_succeeded.disconnect(_on_connection_succeeded)
		_transport.connection_failed.disconnect(_on_connection_failed)
		_transport.peer_disconnected.disconnect(_on_peer_disconnected)
	if _message_channel != null:
		_message_channel.message_received.disconnect(_on_message_received)

	_transport = transport
	_discovery = discovery
	_message_channel = message_channel

	_transport.connection_succeeded.connect(_on_connection_succeeded)
	_transport.connection_failed.connect(_on_connection_failed)
	_transport.peer_disconnected.connect(_on_peer_disconnected)
	_message_channel.message_received.connect(_on_message_received)


# ── 公共 API ──

## 开始搜索局域网房间
func start_searching() -> void:
	if state != ConnectionState.ClientState.IDLE:
		push_error("[RoomClient] 无法搜索：当前状态不允许")
		return

	if _discovery != null:
		_discovery.start_listening()
	state = ConnectionState.ClientState.SEARCHING
	print("[RoomClient] 开始搜索房间")


## 停止搜索
func stop_searching() -> void:
	if _discovery != null:
		_discovery.stop_listening()
	if state == ConnectionState.ClientState.SEARCHING:
		state = ConnectionState.ClientState.IDLE


## 获取当前发现的房间列表
func get_discovered_rooms() -> Dictionary:
	if _discovery != null:
		return _discovery.get_rooms()
	return {}


## 加入指定房间
func join_room(host_ip: String, port: int) -> Error:
	if _transport == null:
		push_error("[RoomClient] 未初始化，请先调用 setup()")
		return ERR_UNCONFIGURED

	if state != ConnectionState.ClientState.SEARCHING and state != ConnectionState.ClientState.IDLE:
		push_error("[RoomClient] 无法加入：当前状态不允许")
		return ERR_ALREADY_IN_USE

	# 停止搜索
	if _discovery != null:
		_discovery.stop_listening()

	# 查找房间信息
	var key = host_ip + ":" + str(port)
	var rooms = get_discovered_rooms()
	if rooms.has(key):
		var discovered_room = rooms[key]
		current_room = discovered_room.info
	else:
		current_room = RoomInfo.new()
		current_room.port = port

	current_host_ip = host_ip
	is_ready = false
	host_ready = false

	var error = _transport.create_client(host_ip, port)
	if error != OK:
		push_error("[RoomClient] 加入房间失败: ", error)
		state = ConnectionState.ClientState.IDLE
		join_failed.emit(str(error))
		return error

	state = ConnectionState.ClientState.JOINING
	print("[RoomClient] 正在加入房间 ", host_ip, ":", port)
	return OK


## 离开当前房间
func leave_room() -> void:
	if _transport != null:
		_transport.disconnect_all()
	current_room = null
	current_host_ip = ""
	is_ready = false
	host_ready = false
	state = ConnectionState.ClientState.IDLE
	print("[RoomClient] 已离开房间")


## 设置准备状态并通知 Host
func set_ready(ready: bool) -> void:
	if state != ConnectionState.ClientState.IN_ROOM:
		print("[RoomClient] 无法设置准备状态：不在房间中")
		return

	is_ready = ready
	print("[RoomClient] 准备状态: ", ready)

	# 通知 Host（server peer ID = 1）
	if _message_channel != null:
		var msg = (MSG_GUEST_READY + str(ready)).to_utf8_buffer()
		_message_channel.send_reliable(1, ROOM_CHANNEL, msg)


# ── Node 生命周期 ──

## 节点退出场景树时清理
func _exit_tree() -> void:
	if state == ConnectionState.ClientState.SEARCHING:
		stop_searching()
	elif state != ConnectionState.ClientState.IDLE:
		leave_room()

	if _transport != null:
		_transport.connection_succeeded.disconnect(_on_connection_succeeded)
		_transport.connection_failed.disconnect(_on_connection_failed)
		_transport.peer_disconnected.disconnect(_on_peer_disconnected)
	if _message_channel != null:
		_message_channel.message_received.disconnect(_on_message_received)


# ── 内部事件处理 ──

## 连接成功回调
func _on_connection_succeeded() -> void:
	if state != ConnectionState.ClientState.JOINING:
		return

	state = ConnectionState.ClientState.IN_ROOM
	var room_name = current_room.host_name if current_room != null else "未知房间"
	var game_type_str = current_room.game_type if current_room != null else ""
	print("[RoomClient] 已加入房间: ", room_name)
	join_succeeded.emit(room_name, game_type_str)


## 连接失败回调
func _on_connection_failed() -> void:
	if state != ConnectionState.ClientState.JOINING:
		return

	current_room = null
	current_host_ip = ""
	state = ConnectionState.ClientState.IDLE
	print("[RoomClient] 加入房间失败")
	join_failed.emit("连接超时或被拒绝")


## 对端断开回调。处理 Host 关闭房间的情况
func _on_peer_disconnected(peer_id: int) -> void:
	# Server peer ID = 1
	if peer_id != 1:
		return

	if state == ConnectionState.ClientState.IN_ROOM or state == ConnectionState.ClientState.GAME_STARTING:
		current_room = null
		current_host_ip = ""
		is_ready = false
		host_ready = false
		state = ConnectionState.ClientState.IDLE
		print("[RoomClient] 房主已关闭房间")
		disconnected_from_room.emit("房主已关闭房间")


## 消息接收处理。处理房间控制消息
func _on_message_received(peer_id: int, channel: String, data: PackedByteArray) -> void:
	if channel != ROOM_CHANNEL:
		return

	var msg = data.get_string_from_utf8()

	if msg.begins_with(MSG_HOST_READY):
		var ready_str = msg.substr(MSG_HOST_READY.length())
		var ready = ready_str == "true"
		host_ready = ready
		print("[RoomClient] 房主准备状态: ", ready)
		host_ready_changed.emit(ready)
	elif msg.begins_with(MSG_GAME_START):
		var game_type_str = msg.substr(MSG_GAME_START.length())
		print("[RoomClient] 游戏即将开始: ", game_type_str)
		state = ConnectionState.ClientState.GAME_STARTING
		game_starting.emit(game_type_str)
	elif msg.begins_with(MSG_ROOM_INFO):
		# 解析房间信息：roomName|gameType
		var info = msg.substr(MSG_ROOM_INFO.length())
		var parts = info.split("|", true, 1)
		if parts.size() >= 2 and current_room != null:
			current_room.host_name = parts[0]
			current_room.game_type = parts[1]
			print("[RoomClient] 收到房间信息: ", parts[0], " (", parts[1], ")")
