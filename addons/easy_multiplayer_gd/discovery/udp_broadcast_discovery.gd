class_name UdpBroadcastDiscovery
extends DiscoveryBase

## 基于 UDP 广播的默认房间发现实现。
##
## Host 端通过 start_broadcast() 定期向局域网广播房间信息，
## Client 端通过 start_listening() 监听广播并维护可用房间列表。
##
## 广播间隔、超时阈值等参数从 EasyMultiplayerConfig 读取。
## 使用 call_deferred() 将异步接收回调切回主线程，确保线程安全。
##
## Magic 标识为 EASYMULTI_V1，与千棋世界的 QIANQI_V1 区分，避免广播冲突。

## 配置引用，广播端口、间隔、超时等参数从此读取
var _config: EasyMultiplayerConfig = EasyMultiplayerConfig.new()

## 本实例唯一标识，用于过滤自身广播
var _instance_id: String = ""

# ── 广播端（Host） ──

var _broadcaster: PacketPeerUDP = null
var _broadcast_timer: float = 0.0
var _broadcast_info: RoomInfo = null

# ── 监听端（Client） ──

var _listener: PacketPeerUDP = null
var _listener_thread: Thread = null

# ── 本机 IP 过滤 ──

var _local_ips: Dictionary = {}  # HashSet 用 Dictionary 模拟
var _local_ips_collected: bool = false

func _init() -> void:
	# 生成实例 ID（8 位随机字符串）
	_instance_id = _generate_instance_id()


func _generate_instance_id() -> String:
	var chars = "0123456789abcdef"
	var result = ""
	for i in range(8):
		result += chars[randi() % chars.length()]
	return result


## 设置配置。应在使用前调用
func set_config(config: EasyMultiplayerConfig) -> void:
	_config = config


# ── 广播端 API ──

func start_broadcast(info: RoomInfo) -> void:
	if is_broadcasting:
		stop_broadcast()

	_broadcast_info = info
	# 确保 Magic 正确
	_broadcast_info.magic = "EASYMULTI_V1"
	_broadcast_info.instance_id = _instance_id

	_broadcaster = PacketPeerUDP.new()
	_broadcaster.set_broadcast_enabled(true)
	is_broadcasting = true
	_broadcast_timer = 0.0
	print("[UdpBroadcastDiscovery] 开始广播房间: ", info.host_name, " (", info.game_type, "), 端口: ", _config.broadcast_port)


func stop_broadcast() -> void:
	is_broadcasting = false
	if _broadcaster != null:
		_broadcaster.close()
		_broadcaster = null
	_broadcast_info = null
	print("[UdpBroadcastDiscovery] 已停止广播")


# ── 监听端 API ──

func start_listening() -> void:
	if is_listening:
		stop_listening()

	_collect_local_ips()

	_listener = PacketPeerUDP.new()
	var err = _listener.bind(_config.broadcast_port)
	if err != OK:
		push_error("[UdpBroadcastDiscovery] 启动监听失败: " + str(err))
		_listener = null
		return

	_listener.set_broadcast_enabled(true)
	is_listening = true
	rooms.clear()

	# 启动后台线程接收 UDP 数据
	_listener_thread = Thread.new()
	_listener_thread.start(_udp_receive_thread)

	print("[UdpBroadcastDiscovery] 开始监听房间广播, 端口: ", _config.broadcast_port)


func stop_listening() -> void:
	is_listening = false

	# 停止线程
	if _listener_thread != null and _listener_thread.is_alive():
		_listener_thread.wait_to_finish()
		_listener_thread = null

	if _listener != null:
		_listener.close()
		_listener = null

	rooms.clear()
	print("[UdpBroadcastDiscovery] 已停止监听")


# ── Node 生命周期 ──

func _process(delta: float) -> void:
	# Host 端定期广播
	if is_broadcasting and _broadcast_info != null and _broadcaster != null:
		_broadcast_timer += delta
		if _broadcast_timer >= _config.broadcast_interval:
			_broadcast_timer = 0.0
			_send_broadcast()

	# Client 端清理超时房间
	if is_listening:
		_cleanup_stale_rooms()


func _exit_tree() -> void:
	stop_broadcast()
	stop_listening()


# ── 内部逻辑 ──

func _send_broadcast() -> void:
	if _broadcaster == null or _broadcast_info == null:
		return

	# 序列化为 JSON
	var data = {
		"Magic": _broadcast_info.magic,
		"HostName": _broadcast_info.host_name,
		"GameType": _broadcast_info.game_type,
		"PlayerCount": _broadcast_info.player_count,
		"MaxPlayers": _broadcast_info.max_players,
		"Port": _broadcast_info.port,
		"Version": _broadcast_info.version,
		"InstanceId": _broadcast_info.instance_id,
		"Metadata": _broadcast_info.metadata
	}
	var json = JSON.stringify(data)
	var packet = json.to_utf8_buffer()

	# 发送广播
	_broadcaster.set_dest_address("255.255.255.255", _config.broadcast_port)
	var err = _broadcaster.put_packet(packet)
	if err != OK:
		push_error("[UdpBroadcastDiscovery] 广播发送失败: " + str(err))


## 后台线程：接收 UDP 数据
func _udp_receive_thread() -> void:
	while is_listening and _listener != null:
		if _listener.get_available_packet_count() > 0:
			var packet = _listener.get_packet()
			var ip = _listener.get_packet_ip()
			var json_str = packet.get_string_from_utf8()

			# 简单的 Magic 检查，避免不必要的反序列化
			if "EASYMULTI_V1" in json_str:
				call_deferred("_handle_room_found", ip, json_str)

		OS.delay_msec(50)  # 避免 CPU 占用过高


## 收集本机所有 IP 地址
func _collect_local_ips() -> void:
	if _local_ips_collected:
		return

	_local_ips.clear()
	_local_ips["127.0.0.1"] = true
	_local_ips["::1"] = true

	# 获取本机所有网络接口的 IP
	var addresses = IP.get_local_addresses()
	for addr in addresses:
		_local_ips[addr] = true

	_local_ips_collected = true


## 在主线程中处理发现的房间。由 call_deferred 调用
func _handle_room_found(ip: String, json_str: String) -> void:
	var json = JSON.new()
	var parse_result = json.parse(json_str)
	if parse_result != OK:
		push_error("[UdpBroadcastDiscovery] 反序列化房间信息失败")
		return

	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return

	if not data.has("Magic") or data["Magic"] != "EASYMULTI_V1":
		return

	# 过滤自身广播（用实例 ID 而非 IP，支持同机多实例测试）
	if data.has("InstanceId") and data["InstanceId"] == _instance_id:
		return

	# 构建 RoomInfo
	var info = RoomInfo.new()
	info.magic = data.get("Magic", "")
	info.host_name = data.get("HostName", "")
	info.game_type = data.get("GameType", "")
	info.player_count = data.get("PlayerCount", 1)
	info.max_players = data.get("MaxPlayers", 2)
	info.port = data.get("Port", 27015)
	info.version = data.get("Version", "1.0.0")
	info.instance_id = data.get("InstanceId", "")
	info.metadata = data.get("Metadata", {})

	var key = ip + ":" + str(info.port)
	var is_new = not rooms.has(key)

	var room = RoomInfo.DiscoveredRoom.new()
	room.info = info
	room.host_ip = ip
	room.last_seen = Time.get_unix_time_from_system()

	rooms[key] = room

	if is_new:
		print("[UdpBroadcastDiscovery] 发现房间: ", info.host_name, " @ ", ip, ":", info.port)
		room_found.emit(room)

	room_list_updated.emit()


## 清理超时未收到广播的房间
func _cleanup_stale_rooms() -> void:
	var now = Time.get_unix_time_from_system()
	var stale_keys = []

	for key in rooms.keys():
		var room = rooms[key]
		if now - room.last_seen > _config.room_timeout:
			stale_keys.append(key)

	for key in stale_keys:
		rooms.erase(key)
		print("[UdpBroadcastDiscovery] 房间超时移除: ", key)
		room_lost.emit(key)

	if stale_keys.size() > 0:
		room_list_updated.emit()
