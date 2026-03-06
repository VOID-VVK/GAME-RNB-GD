class_name HeartbeatManager
extends Node

## 心跳管理器。负责 Ping/Pong 心跳检测、RTT 计算、网络质量分级、
## 断线检测和客户端自动重连。
##
## 心跳使用 Unreliable 通道发送，避免阻塞可靠通道。
## 超时阈值远大于发送间隔（默认 10s vs 3s），至少容忍连续 3 次丢包。
##
## 客户端断线后自动尝试重连，最大重试次数和间隔从 EasyMultiplayerConfig 读取。
## Host 端仅等待对端重连，不主动发起。

# ── 心跳协议通道 ──

## 心跳 Ping/Pong 使用的内部通道编号
const HEARTBEAT_CHANNEL: int = 255

## Ping 包标识字节
static var PING_PAYLOAD: PackedByteArray = PackedByteArray([0x01])

## Pong 包标识字节
static var PONG_PAYLOAD: PackedByteArray = PackedByteArray([0x02])

# ── 依赖 ──

var _transport: TransportBase = null
var _config: EasyMultiplayerConfig = EasyMultiplayerConfig.new()

# ── 心跳状态 ──

var _active: bool = false
var _heartbeat_timer: float = 0.0
var _last_pong_received: float = 0.0

# ── RTT 追踪 ──

## 上次发送 Ping 的时间戳（毫秒）
var _last_ping_sent_ms: float = 0.0

## 当前 RTT（毫秒），-1 表示未测量
var rtt_ms: float = -1.0

## 当前网络质量
var quality: ConnectionState.NetQuality = ConnectionState.NetQuality.GOOD

# ── 重连状态（Host 端等待） ──

var _waiting_reconnect: bool = false
var _disconnected_elapsed: float = 0.0

# ── 客户端自动重连状态 ──

var _client_auto_reconnecting: bool = false
var _reconnect_attempts: int = 0
var _reconnect_retry_timer: float = 0.0

## 重连已等待的秒数
var reconnect_elapsed: float:
	get: return _disconnected_elapsed

# ── 已跟踪的对端 ──

var _tracked_peers: Dictionary = {}  # HashSet 用 Dictionary 模拟

# ── 信号 ──

## 网络质量等级变化时触发
signal net_quality_changed(quality: ConnectionState.NetQuality, rtt_ms: float)

## 对端心跳超时时触发
signal peer_timed_out(peer_id: int)

## 对端重连成功时触发
signal peer_reconnected(peer_id: int)

## Host 端重连等待超时时触发
signal reconnect_timed_out()

## Client 端自动重连全部失败时触发
signal reconnect_failed()

## 重连成功后需要全量同步时触发
signal full_sync_requested(peer_id: int)


# ── 初始化 ──

## 设置传输层和配置。应在使用前调用
func setup(transport: TransportBase, config: EasyMultiplayerConfig) -> void:
	# 清理旧的事件绑定
	if _transport != null:
		_transport.data_received.disconnect(_on_data_received)
		_transport.peer_connected.disconnect(_on_transport_peer_connected)
		_transport.peer_disconnected.disconnect(_on_transport_peer_disconnected)
		_transport.connection_succeeded.disconnect(_on_transport_connection_succeeded)
		_transport.connection_failed.disconnect(_on_transport_connection_failed)

	_transport = transport
	_config = config

	_transport.data_received.connect(_on_data_received)
	_transport.peer_connected.connect(_on_transport_peer_connected)
	_transport.peer_disconnected.connect(_on_transport_peer_disconnected)
	_transport.connection_succeeded.connect(_on_transport_connection_succeeded)
	_transport.connection_failed.connect(_on_transport_connection_failed)


# ── 公共 API ──

## 启动心跳检测。在连接建立后调用
func start() -> void:
	_active = true
	_heartbeat_timer = 0.0
	_last_pong_received = Time.get_unix_time_from_system()
	_last_ping_sent_ms = 0.0
	rtt_ms = -1.0
	quality = ConnectionState.NetQuality.GOOD
	print("[HeartbeatManager] 心跳已启动")


## 停止心跳检测
func stop() -> void:
	_active = false
	_heartbeat_timer = 0.0
	print("[HeartbeatManager] 心跳已停止")


## 添加需要跟踪心跳的对端
func track_peer(peer_id: int) -> void:
	_tracked_peers[peer_id] = true


## 移除对端跟踪
func untrack_peer(peer_id: int) -> void:
	_tracked_peers.erase(peer_id)


## 重置所有状态
func reset() -> void:
	stop()
	_waiting_reconnect = false
	_disconnected_elapsed = 0.0
	_client_auto_reconnecting = false
	_reconnect_attempts = 0
	_reconnect_retry_timer = 0.0
	_tracked_peers.clear()
	rtt_ms = -1.0
	quality = ConnectionState.NetQuality.GOOD


## 强制取消重连等待
func cancel_reconnect() -> void:
	_waiting_reconnect = false
	_client_auto_reconnecting = false
	_disconnected_elapsed = 0.0
	_reconnect_attempts = 0
	print("[HeartbeatManager] 重连已取消")


# ── Node 生命周期 ──

func _process(delta: float) -> void:
	_process_heartbeat(delta)
	_process_reconnect_timer(delta)
	_process_client_auto_reconnect(delta)


func _exit_tree() -> void:
	reset()
	if _transport != null:
		_transport.data_received.disconnect(_on_data_received)
		_transport.peer_connected.disconnect(_on_transport_peer_connected)
		_transport.peer_disconnected.disconnect(_on_transport_peer_disconnected)
		_transport.connection_succeeded.disconnect(_on_transport_connection_succeeded)
		_transport.connection_failed.disconnect(_on_transport_connection_failed)


# ── 心跳处理 ──

## 处理心跳发送和超时检测
func _process_heartbeat(delta: float) -> void:
	if not _active or _transport == null or _transport.status != TransportBase.TransportStatus.CONNECTED:
		return

	_heartbeat_timer += delta
	if _heartbeat_timer >= _config.heartbeat_interval:
		_heartbeat_timer = 0.0
		_send_ping()
		_check_timeout()


## 向所有跟踪的对端发送 Ping
func _send_ping() -> void:
	if _transport == null or _transport.status != TransportBase.TransportStatus.CONNECTED:
		return

	_last_ping_sent_ms = Time.get_unix_time_from_system() * 1000.0

	for peer_id in _tracked_peers.keys():
		_transport.send_unreliable(peer_id, HEARTBEAT_CHANNEL, PING_PAYLOAD)


## 检查是否有对端心跳超时
func _check_timeout() -> void:
	var time_since_last_pong = Time.get_unix_time_from_system() - _last_pong_received
	if time_since_last_pong > _config.disconnect_timeout:
		print("[HeartbeatManager] 心跳超时 (", time_since_last_pong, "s)")
		_handle_timeout()


## 处理心跳超时：停止心跳，进入重连等待或启动客户端自动重连
func _handle_timeout() -> void:
	if _waiting_reconnect or _client_auto_reconnecting:
		return

	stop()

	# 通知所有跟踪的对端超时
	for peer_id in _tracked_peers.keys():
		peer_timed_out.emit(peer_id)

	if _transport != null and _transport.is_server:
		# Host 端：进入重连等待
		_waiting_reconnect = true
		_disconnected_elapsed = 0.0
		print("[HeartbeatManager] Host 进入重连等待状态")
	else:
		# Client 端：启动自动重连
		_start_client_auto_reconnect()


# ── 重连计时（Host 端） ──

## Host 端重连等待计时。超时后触发 reconnect_timed_out
func _process_reconnect_timer(delta: float) -> void:
	if not _waiting_reconnect:
		return

	_disconnected_elapsed += delta

	if _disconnected_elapsed >= _config.reconnect_timeout:
		print("[HeartbeatManager] 重连等待超时")
		_waiting_reconnect = false
		_disconnected_elapsed = 0.0
		reconnect_timed_out.emit()


# ── 客户端自动重连 ──

## 启动客户端自动重连流程
func _start_client_auto_reconnect() -> void:
	if not (_transport is ENetTransport):
		push_error("[HeartbeatManager] 自动重连仅支持 ENetTransport")
		reconnect_failed.emit()
		return

	var enet_transport = _transport as ENetTransport
	if enet_transport.get_last_address().is_empty():
		push_error("[HeartbeatManager] 无法自动重连：缺少上次连接地址")
		reconnect_failed.emit()
		return

	_client_auto_reconnecting = true
	_reconnect_attempts = 0
	_reconnect_retry_timer = 0.0  # 立即尝试第一次
	_disconnected_elapsed = 0.0

	print("[HeartbeatManager] Client 开始自动重连 (最多 ", _config.max_reconnect_attempts, " 次, 间隔 ", _config.reconnect_retry_interval, "s)")


## 每帧检查是否需要执行客户端自动重连尝试
func _process_client_auto_reconnect(delta: float) -> void:
	if not _client_auto_reconnecting or _transport == null:
		return

	_disconnected_elapsed += delta
	_reconnect_retry_timer -= delta
	if _reconnect_retry_timer > 0:
		return

	_reconnect_retry_timer = _config.reconnect_retry_interval
	_reconnect_attempts += 1

	print("[HeartbeatManager] Client 自动重连尝试 ", _reconnect_attempts, "/", _config.max_reconnect_attempts)

	if not (_transport is ENetTransport):
		return

	var enet_transport = _transport as ENetTransport

	# 临时解绑事件回调，防止 disconnect_all() 触发的事件导致重复进入重连逻辑
	_transport.peer_disconnected.disconnect(_on_transport_peer_disconnected)
	_transport.connection_failed.disconnect(_on_transport_connection_failed)

	# 先断开旧连接
	_transport.disconnect_all()

	# 确保 disconnect_all() 后状态为 DISCONNECTED
	if _transport.status != TransportBase.TransportStatus.DISCONNECTED:
		push_error("[HeartbeatManager] disconnect_all() 后状态未重置为 DISCONNECTED，中止重连")
		_transport.peer_disconnected.connect(_on_transport_peer_disconnected)
		_transport.connection_failed.connect(_on_transport_connection_failed)
		_on_client_auto_reconnect_failed()
		return

	# 重新绑定事件回调
	_transport.peer_disconnected.connect(_on_transport_peer_disconnected)
	_transport.connection_failed.connect(_on_transport_connection_failed)

	# 尝试重新连接
	var error = _transport.create_client(enet_transport.get_last_address(), enet_transport.get_last_port())
	if error != OK:
		push_error("[HeartbeatManager] 重连创建连接失败: ", error)
		if _reconnect_attempts >= _config.max_reconnect_attempts:
			_on_client_auto_reconnect_failed()
	# 连接结果由 _on_transport_connection_succeeded / _on_transport_connection_failed 处理


## 客户端自动重连全部失败
func _on_client_auto_reconnect_failed() -> void:
	print("[HeartbeatManager] Client 自动重连全部失败")
	_client_auto_reconnecting = false
	_reconnect_attempts = 0
	_disconnected_elapsed = 0.0
	if _transport != null:
		_transport.disconnect_all()
	reconnect_failed.emit()


# ── 传输层事件处理 ──

## 处理收到的数据，识别心跳 Ping/Pong 包
func _on_data_received(peer_id: int, channel: int, data: PackedByteArray) -> void:
	if channel != HEARTBEAT_CHANNEL or data.size() < 1:
		return

	if data[0] == PING_PAYLOAD[0]:
		# 收到 Ping，回复 Pong
		if _transport != null:
			_transport.send_unreliable(peer_id, HEARTBEAT_CHANNEL, PONG_PAYLOAD)
	elif data[0] == PONG_PAYLOAD[0]:
		# 收到 Pong，更新 RTT
		_last_pong_received = Time.get_unix_time_from_system()

		var now_ms = _last_pong_received * 1000.0
		if _last_ping_sent_ms > 0:
			rtt_ms = now_ms - _last_ping_sent_ms
			var old_quality = quality

			if rtt_ms < 100:
				quality = ConnectionState.NetQuality.GOOD
			elif rtt_ms < 300:
				quality = ConnectionState.NetQuality.WARNING
			else:
				quality = ConnectionState.NetQuality.BAD

			if quality != old_quality:
				print("[HeartbeatManager] 网络质量变更: ", old_quality, " → ", quality, " (RTT=", rtt_ms, "ms)")
				net_quality_changed.emit(quality, rtt_ms)


## 传输层对端连接事件。处理重连成功场景
func _on_transport_peer_connected(peer_id: int) -> void:
	if _waiting_reconnect:
		# Host 端：对端重连成功
		print("[HeartbeatManager] 对端重连成功: ", peer_id)
		_waiting_reconnect = false
		_disconnected_elapsed = 0.0
		track_peer(peer_id)
		start()
		peer_reconnected.emit(peer_id)
		full_sync_requested.emit(peer_id)


## 传输层对端断开事件
func _on_transport_peer_disconnected(peer_id: int) -> void:
	untrack_peer(peer_id)

	if _active and _transport != null and _transport.is_server:
		# Host 端：对端断开，进入重连等待
		stop()
		_waiting_reconnect = true
		_disconnected_elapsed = 0.0
		peer_timed_out.emit(peer_id)
		print("[HeartbeatManager] 对端断开 (", peer_id, ")，Host 进入重连等待")


## 客户端连接成功回调。处理自动重连成功场景
func _on_transport_connection_succeeded() -> void:
	if _client_auto_reconnecting:
		print("[HeartbeatManager] Client 自动重连成功（第 ", _reconnect_attempts, " 次尝试）")
		_client_auto_reconnecting = false
		_reconnect_attempts = 0
		_reconnect_retry_timer = 0.0
		_disconnected_elapsed = 0.0

		# 重新跟踪 server peer
		track_peer(1)
		start()

		peer_reconnected.emit(1)
		full_sync_requested.emit(1)


## 客户端连接失败回调。处理自动重连中的失败
func _on_transport_connection_failed() -> void:
	if _client_auto_reconnecting:
		print("[HeartbeatManager] Client 重连尝试 ", _reconnect_attempts, "/", _config.max_reconnect_attempts, " 失败")
		if _reconnect_attempts >= _config.max_reconnect_attempts:
			_on_client_auto_reconnect_failed()
		# 否则等待下次 _process_client_auto_reconnect 重试
