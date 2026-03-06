extends Node

## EasyMultiplayer Autoload 单例。统一 API 入口，组合所有模块。
##
## 管理连接生命周期（ConnectionState 状态机）、版本校验、主动退出通知。
## 组合 TransportBase、DiscoveryBase、HeartbeatManager、MessageChannel、RoomHost、RoomClient。
##
## 所有事件通过 Godot Signal 暴露，不依赖外部 EventBus。
## 使用者通过此单例访问所有网络功能。

# ── 版本校验内部通道 ──

## 版本校验使用的内部消息通道
const VERSION_CHANNEL: String = "__version"

## 版本校验消息前缀
const MSG_VERSION: String = "ver:"

## 版本校验通过消息前缀
const MSG_VERSION_OK: String = "ver_ok:"

## 版本不匹配消息前缀
const MSG_VERSION_MISMATCH: String = "ver_mismatch:"

# ── 主动退出内部通道 ──

## 主动退出使用的内部消息通道
const QUIT_CHANNEL: String = "__quit"

## 主动退出消息前缀
const MSG_QUIT: String = "quit:"

# ── 配置 ──

## 插件配置资源。可在 Inspector 中编辑或代码中动态修改
@export var config: EasyMultiplayerConfig = EasyMultiplayerConfig.new()

## 使用者设置的游戏版本号，连接时自动交换校验
var game_version: String = "1.0.0"

# ── 模块实例 ──

var _transport: TransportBase = null
var _discovery: DiscoveryBase = null
var _heartbeat: HeartbeatManager = null
var _message_channel: MessageChannel = null
var _room_host: RoomHost = null
var _room_client: RoomClient = null

## 传输层实例
var transport: TransportBase:
	get: return _transport

## 发现层实例
var discovery: DiscoveryBase:
	get: return _discovery

## 心跳管理器
var heartbeat: HeartbeatManager:
	get: return _heartbeat

## 消息通道
var message_channel: MessageChannel:
	get: return _message_channel

## 房间主机
var room_host: RoomHost:
	get: return _room_host

## 房间客户端
var room_client: RoomClient:
	get: return _room_client

# ── 连接状态 ──

var _state: ConnectionState.State = ConnectionState.State.DISCONNECTED

## 当前连接状态
var state: ConnectionState.State:
	get: return _state
	set(value):
		if _state == value:
			return
		var old = _state
		_state = value
		print("[EasyMultiplayer] 连接状态: ", old, " → ", value)
		state_changed.emit(old, value)

## 当前连接的对端 peer ID 集合
var _connected_peers: Dictionary = {}  # HashSet 用 Dictionary 模拟

## 标记对端是否主动退出（用于区分主动退出和意外断线）
var _gracefully_quit_peers: Dictionary = {}

## Joining 超时计时器（秒）
var _joining_timer: float = 0.0

## Joining 超时阈值（秒）
const JOINING_TIMEOUT: float = 10.0

## 版本校验超时计时器（秒）
var _version_check_timer: float = 0.0

## 版本校验超时阈值（秒）
const VERSION_CHECK_TIMEOUT: float = 5.0

## 是否正在等待版本校验结果
var _waiting_version_check: bool = false

## 是否为服务端
var is_server: bool:
	get: return _transport.is_server if _transport != null else false

## 本机唯一标识符
var unique_id: int:
	get: return _transport.unique_id if _transport != null else 0

## 是否已连接（网络层）。Host 端处于 Hosting 状态也视为已连接
var is_network_connected: bool:
	get: return _state == ConnectionState.State.CONNECTED or _state == ConnectionState.State.HOSTING

## 是否正在重连
var is_reconnecting: bool:
	get: return _state == ConnectionState.State.RECONNECTING

## 已连接的对端 ID 列表
var connected_peers: Array:
	get: return _connected_peers.keys()

# ── Godot 信号：连接模块 ──

## 连接状态发生转换时触发
signal state_changed(old_state: ConnectionState.State, new_state: ConnectionState.State)

## 对端连接成功时触发
signal peer_joined(peer_id: int)

## 对端断开连接时触发
signal peer_left(peer_id: int)

## Client 连接 Host 成功时触发
signal connection_succeeded()

## Client 连接 Host 失败时触发
signal connection_failed()

## 版本校验通过时触发
signal version_verified(remote_version: String)

## 版本不匹配时触发
signal version_mismatch(local_version: String, remote_version: String)

## 对端主动退出时触发
signal peer_graceful_quit(peer_id: int, reason: String)

## 重连成功后需要全量同步时触发
signal full_sync_requested(peer_id: int)


# ── Node 生命周期 ──

## 节点就绪时初始化所有模块
func _ready() -> void:
	# 创建传输层
	_transport = ENetTransport.new()

	# 创建发现层
	_discovery = UdpBroadcastDiscovery.new()
	_discovery.set_config(config)
	add_child(_discovery)

	# 创建心跳管理器
	_heartbeat = HeartbeatManager.new()
	_heartbeat.setup(_transport, config)
	add_child(_heartbeat)

	# 创建消息通道
	_message_channel = MessageChannel.new()
	_message_channel.set_transport(_transport)
	_message_channel.rpc_min_interval_ms = config.rpc_min_interval_ms

	# 创建房间模块
	_room_host = RoomHost.new()
	_room_host.setup(_transport, _discovery, _message_channel, config, game_version)
	add_child(_room_host)

	_room_client = RoomClient.new()
	_room_client.setup(_transport, _discovery, _message_channel)
	add_child(_room_client)

	# 绑定传输层事件
	_transport.peer_connected.connect(_on_transport_peer_connected)
	_transport.peer_disconnected.connect(_on_transport_peer_disconnected)
	_transport.connection_succeeded.connect(_on_transport_connection_succeeded)
	_transport.connection_failed.connect(_on_transport_connection_failed)

	# 绑定心跳事件
	_heartbeat.peer_timed_out.connect(_on_heartbeat_peer_timed_out)
	_heartbeat.peer_reconnected.connect(_on_heartbeat_peer_reconnected)
	_heartbeat.reconnect_timed_out.connect(_on_heartbeat_reconnect_timed_out)
	_heartbeat.reconnect_failed.connect(_on_heartbeat_reconnect_failed)
	_heartbeat.full_sync_requested.connect(_on_heartbeat_full_sync_requested)

	# 绑定消息通道事件（处理版本校验和主动退出）
	_message_channel.message_received.connect(_on_internal_message_received)

	# 绑定房间模块状态事件，同步 EasyMultiplayer 连接状态
	_room_host.room_state_changed.connect(_on_room_host_state_changed)
	_room_client.client_state_changed.connect(_on_room_client_state_changed)

	# 确保 EasyMultiplayer 的 _process 在 SceneMultiplayer 之前执行，
	# 先消费所有数据包，防止 SceneMultiplayer 抢先消费导致 poll() 收不到数据
	process_priority = -2147483648  # int.MinValue

	print("[EasyMultiplayer] 初始化完成")


## 每帧驱动传输层事件循环和超时检查
func _process(delta: float) -> void:
	_transport.poll()

	# Joining 超时检查
	if _state == ConnectionState.State.JOINING:
		_joining_timer += delta
		if _joining_timer >= JOINING_TIMEOUT:
			push_error("[EasyMultiplayer] Joining 超时 (10s)")
			_joining_timer = 0.0
			disconnect_all()
			connection_failed.emit()

	# 版本校验超时检查
	if _waiting_version_check:
		_version_check_timer += delta
		if _version_check_timer >= VERSION_CHECK_TIMEOUT:
			push_error("[EasyMultiplayer] 版本校验超时 (5s)")
			_waiting_version_check = false
			_version_check_timer = 0.0
			disconnect_all()
			connection_failed.emit()


## 节点退出场景树时清理所有资源
func _exit_tree() -> void:
	disconnect_all()

	if _transport != null:
		_transport.peer_connected.disconnect(_on_transport_peer_connected)
		_transport.peer_disconnected.disconnect(_on_transport_peer_disconnected)
		_transport.connection_succeeded.disconnect(_on_transport_connection_succeeded)
		_transport.connection_failed.disconnect(_on_transport_connection_failed)

	if _heartbeat != null:
		_heartbeat.peer_timed_out.disconnect(_on_heartbeat_peer_timed_out)
		_heartbeat.peer_reconnected.disconnect(_on_heartbeat_peer_reconnected)
		_heartbeat.reconnect_timed_out.disconnect(_on_heartbeat_reconnect_timed_out)
		_heartbeat.reconnect_failed.disconnect(_on_heartbeat_reconnect_failed)
		_heartbeat.full_sync_requested.disconnect(_on_heartbeat_full_sync_requested)

	if _message_channel != null:
		_message_channel.message_received.disconnect(_on_internal_message_received)

	if _room_host != null:
		_room_host.room_state_changed.disconnect(_on_room_host_state_changed)
	if _room_client != null:
		_room_client.client_state_changed.disconnect(_on_room_client_state_changed)

	if _transport != null:
		_transport.cleanup()


# ── 公共 API：连接管理 ──

## 作为主机开始监听
func host(port: int = -1, max_clients: int = -1) -> Error:
	if _state != ConnectionState.State.DISCONNECTED:
		push_error("[EasyMultiplayer] 无法创建主机：当前状态不是 Disconnected")
		return ERR_ALREADY_IN_USE

	var actual_port = port if port > 0 else config.port
	var actual_max_clients = max_clients if max_clients > 0 else config.max_clients

	var error = _transport.create_host(actual_port, actual_max_clients)
	if error != OK:
		return error

	state = ConnectionState.State.HOSTING
	return OK


## 作为客户端连接到主机
func join(address: String, port: int = -1) -> Error:
	if _state != ConnectionState.State.DISCONNECTED:
		push_error("[EasyMultiplayer] 无法连接：当前状态不是 Disconnected")
		return ERR_ALREADY_IN_USE

	var actual_port = port if port > 0 else config.port

	var error = _transport.create_client(address, actual_port)
	if error != OK:
		return error

	state = ConnectionState.State.JOINING
	_joining_timer = 0.0
	return OK


## 断开连接并重置所有状态
func disconnect_all() -> void:
	if _heartbeat != null:
		_heartbeat.reset()
	if _discovery != null:
		_discovery.stop_broadcast()
		_discovery.stop_listening()
	if _transport != null:
		_transport.disconnect_all()
	if _message_channel != null:
		_message_channel.reset_rate_limits()

	_connected_peers.clear()
	_gracefully_quit_peers.clear()
	_joining_timer = 0.0
	_waiting_version_check = false
	_version_check_timer = 0.0

	state = ConnectionState.State.DISCONNECTED


# ── 公共 API：房间快捷方法 ──

## 创建房间（快捷方法，内部调用 RoomHost.create_room）
func create_room(room_name: String, game_type: String, port: int = -1) -> Error:
	return _room_host.create_room(room_name, game_type, port)


## 加入房间（快捷方法，内部调用 RoomClient.join_room）
func join_room(host_ip: String, port: int = -1) -> Error:
	var actual_port = port if port > 0 else config.port
	return _room_client.join_room(host_ip, actual_port)


# ── 公共 API：消息 ──

## 发送可靠消息（快捷方法）
func send_message(peer_id: int, channel: String, data: PackedByteArray) -> void:
	_message_channel.send_reliable(peer_id, channel, data)


## 发送可靠消息（string 重载）
func send_message_string(peer_id: int, channel: String, data: String) -> void:
	_message_channel.send_reliable(peer_id, channel, data.to_utf8_buffer())


## 广播消息给所有对端（快捷方法）
func broadcast_message(channel: String, data: PackedByteArray, reliable: bool = true) -> void:
	_message_channel.broadcast(channel, data, reliable)


# ── 公共 API：主动退出 ──

## 主动退出：先发通知再延迟断开，让对端区分主动退出与意外断线
func graceful_disconnect(reason: String = "quit") -> void:
	_send_graceful_quit(reason)
	await get_tree().create_timer(0.2).timeout
	disconnect_all()


# ── 版本校验 ──

## Client 连接后自动发送版本号给 Host
func _send_version_to_host() -> void:
	var msg = (MSG_VERSION + game_version).to_utf8_buffer()
	_message_channel.send_reliable(1, VERSION_CHANNEL, msg)
	_waiting_version_check = true
	_version_check_timer = 0.0


## Host 处理收到的版本号
func _handle_version_check(peer_id: int, remote_version: String) -> void:
	if remote_version == game_version:
		print("[EasyMultiplayer] 版本校验通过: ", remote_version)
		# 回复确认
		var msg = (MSG_VERSION_OK + game_version).to_utf8_buffer()
		_message_channel.send_reliable(peer_id, VERSION_CHANNEL, msg)
		version_verified.emit(remote_version)
	else:
		push_error("[EasyMultiplayer] 版本不匹配！本地=", game_version, ", 对端=", remote_version)
		# 通知 Client 版本不匹配
		var msg = (MSG_VERSION_MISMATCH + game_version).to_utf8_buffer()
		_message_channel.send_reliable(peer_id, VERSION_CHANNEL, msg)
		version_mismatch.emit(game_version, remote_version)

		# 延迟 300ms 后踢出，让消息先送达
		await get_tree().create_timer(0.3).timeout
		_transport.disconnect_peer(peer_id)


# ── 主动退出通知 ──

## 发送主动退出通知给所有对端
func _send_graceful_quit(reason: String) -> void:
	print("[EasyMultiplayer] 发送主动退出通知: reason=", reason)
	var msg = (MSG_QUIT + reason).to_utf8_buffer()
	_message_channel.broadcast(QUIT_CHANNEL, msg)


# ── 传输层事件处理 ──

## 对端连接事件
func _on_transport_peer_connected(peer_id: int) -> void:
	_connected_peers[peer_id] = true
	print("[EasyMultiplayer] OnTransportPeerConnected: peer_id=", peer_id, ", _connected_peers.size()=", _connected_peers.size())

	# 如果在重连状态，由心跳管理器处理
	if _state == ConnectionState.State.RECONNECTING:
		return

	if _state == ConnectionState.State.HOSTING:
		state = ConnectionState.State.CONNECTED
		_heartbeat.track_peer(peer_id)
		_heartbeat.start()

	peer_joined.emit(peer_id)


## 对端断开事件
func _on_transport_peer_disconnected(peer_id: int) -> void:
	_connected_peers.erase(peer_id)

	# 如果对端是主动退出，不进入重连
	if _gracefully_quit_peers.has(peer_id):
		_gracefully_quit_peers.erase(peer_id)
		print("[EasyMultiplayer] 对端 ", peer_id, " 主动退出，跳过重连")
		peer_left.emit(peer_id)

		if _transport.is_server and _connected_peers.is_empty():
			state = ConnectionState.State.HOSTING
		elif not _transport.is_server:
			disconnect_all()
		return

	peer_left.emit(peer_id)

	# 如果在 Connected 状态且不是主动退出，由心跳管理器处理重连
	# （心跳管理器的 _on_transport_peer_disconnected 会触发重连逻辑）
	if _state == ConnectionState.State.CONNECTED:
		state = ConnectionState.State.RECONNECTING
	elif _state == ConnectionState.State.HOSTING and _connected_peers.is_empty():
		# 保持 Hosting 状态
		pass
	elif not _transport.is_server and _state != ConnectionState.State.RECONNECTING:
		disconnect_all()


## Client 连接成功事件
func _on_transport_connection_succeeded() -> void:
	print("[EasyMultiplayer] OnTransportConnectionSucceeded: State=", _state)
	if _state == ConnectionState.State.RECONNECTING:
		return  # 由心跳管理器处理

	if _state == ConnectionState.State.JOINING:
		_joining_timer = 0.0
		state = ConnectionState.State.CONNECTED
		_connected_peers[1] = true  # Server peer ID = 1
		_heartbeat.track_peer(1)
		_heartbeat.start()

		connection_succeeded.emit()

		# 自动发送版本校验
		call_deferred("_send_version_to_host")


## Client 连接失败事件
func _on_transport_connection_failed() -> void:
	if _state == ConnectionState.State.RECONNECTING:
		return  # 由心跳管理器处理

	state = ConnectionState.State.DISCONNECTED
	connection_failed.emit()


# ── 心跳事件处理 ──

## 对端心跳超时
func _on_heartbeat_peer_timed_out(peer_id: int) -> void:
	if _state == ConnectionState.State.CONNECTED:
		state = ConnectionState.State.RECONNECTING


## 对端重连成功
func _on_heartbeat_peer_reconnected(peer_id: int) -> void:
	_connected_peers[peer_id] = true
	state = ConnectionState.State.CONNECTED


## Host 端重连等待超时
func _on_heartbeat_reconnect_timed_out() -> void:
	disconnect_all()


## Client 端重连全部失败
func _on_heartbeat_reconnect_failed() -> void:
	disconnect_all()


## 重连后全量同步请求
func _on_heartbeat_full_sync_requested(peer_id: int) -> void:
	full_sync_requested.emit(peer_id)


# ── 内部消息处理 ──

## 处理版本校验和主动退出等内部消息
func _on_internal_message_received(peer_id: int, channel: String, data: PackedByteArray) -> void:
	if channel == VERSION_CHANNEL:
		_handle_version_message(peer_id, data)
	elif channel == QUIT_CHANNEL:
		_handle_quit_message(peer_id, data)


## 处理版本校验消息
func _handle_version_message(peer_id: int, data: PackedByteArray) -> void:
	var msg = data.get_string_from_utf8()

	if msg.begins_with(MSG_VERSION) and _transport.is_server:
		# Host 收到 Client 的版本号
		var remote_version = msg.substr(MSG_VERSION.length())
		_handle_version_check(peer_id, remote_version)
	elif msg.begins_with(MSG_VERSION_OK) and not _transport.is_server:
		# Client 收到版本校验通过
		_waiting_version_check = false
		var host_version = msg.substr(MSG_VERSION_OK.length())
		print("[EasyMultiplayer] Host 版本确认: ", host_version)
		version_verified.emit(host_version)
	elif msg.begins_with(MSG_VERSION_MISMATCH) and not _transport.is_server:
		# Client 收到版本不匹配
		_waiting_version_check = false
		var host_version = msg.substr(MSG_VERSION_MISMATCH.length())
		push_error("[EasyMultiplayer] 版本不匹配！Host=", host_version, ", 本地=", game_version)
		version_mismatch.emit(game_version, host_version)
		# Host 会延迟踢出，Client 不需要主动断开


## 处理主动退出消息
func _handle_quit_message(peer_id: int, data: PackedByteArray) -> void:
	var msg = data.get_string_from_utf8()

	if msg.begins_with(MSG_QUIT):
		var reason = msg.substr(MSG_QUIT.length())
		print("[EasyMultiplayer] 收到对端 ", peer_id, " 主动退出通知: reason=", reason)
		_gracefully_quit_peers[peer_id] = true
		peer_graceful_quit.emit(peer_id, reason)


# ── 房间模块状态同步 ──

## 同步 RoomHost 状态到 EasyMultiplayer 连接状态
func _on_room_host_state_changed(old_state: RoomState.State, new_state: RoomState.State) -> void:
	# RoomState.WAITING = 1：房间已创建并等待玩家，同步为 HOSTING
	if new_state == RoomState.State.WAITING and _state == ConnectionState.State.DISCONNECTED:
		state = ConnectionState.State.HOSTING
	# RoomState.CLOSED = 4：房间已关闭，同步为 DISCONNECTED
	elif new_state == RoomState.State.CLOSED and _state != ConnectionState.State.DISCONNECTED:
		state = ConnectionState.State.DISCONNECTED


## 同步 RoomClient 状态到 EasyMultiplayer 连接状态
func _on_room_client_state_changed(old_state: ConnectionState.ClientState, new_state: ConnectionState.ClientState) -> void:
	# ClientState.JOINING = 2：正在加入房间，同步为 JOINING
	if new_state == ConnectionState.ClientState.JOINING and _state == ConnectionState.State.DISCONNECTED:
		state = ConnectionState.State.JOINING
		_joining_timer = 0.0
	# ClientState.IDLE = 0：回到空闲（加入失败），仅当 RoomClient 是从 JOINING 状态退回时才重置。
	# 注意：SEARCHING → IDLE（StopSearching）不应影响 EasyMP 的 JOINING 状态。
	elif new_state == ConnectionState.ClientState.IDLE and old_state == ConnectionState.ClientState.JOINING \
			and _state == ConnectionState.State.JOINING:
		print("[EasyMultiplayer] OnRoomClientStateChanged: RoomClient JOINING→IDLE，重置为 DISCONNECTED")
		state = ConnectionState.State.DISCONNECTED
	else:
		print("[EasyMultiplayer] OnRoomClientStateChanged: ", old_state, " → ", new_state, "，EasyMP.State=", _state, "（无操作）")
