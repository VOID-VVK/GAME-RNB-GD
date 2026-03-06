class_name ENetTransport
extends TransportBase

## 基于 Godot ENetMultiplayerPeer 的默认传输层实现。
##
## 封装 Godot 的 ENetMultiplayerPeer，不设置 MultiplayerPeer 到 MultiplayerAPI，
## 通过握手包和数据包 senderId 驱动 peer 发现。
##
## 使用者需在每帧调用 poll() 以驱动事件循环（通常由 EasyMultiplayer 单例的 _process 调用）。

var _peer: ENetMultiplayerPeer = null

## 记住上次连接的地址，用于重连
var _last_address: String = ""

## 记住上次连接的端口，用于重连
var _last_port: int = 0

var _known_peers: Dictionary = {}  # HashSet 用 Dictionary 模拟

## 内部握手通道标识，服务器收到后触发 peer_connected，不传递给上层
const HANDSHAKE_CHANNEL: int = -2147483648  # int.MinValue

## 客户端上一帧的 ENet 连接状态，用于检测状态转换
var _prev_client_status: MultiplayerPeer.ConnectionStatus = MultiplayerPeer.CONNECTION_DISCONNECTED


## 清理资源
func cleanup() -> void:
	_known_peers.clear()


# ── 生命周期 ──

func create_host(port: int, max_clients: int) -> int:
	if status != TransportStatus.DISCONNECTED:
		push_error("[ENetTransport] 无法创建主机：当前状态不是 DISCONNECTED")
		return ERR_ALREADY_IN_USE

	_peer = ENetMultiplayerPeer.new()
	var error = _peer.create_server(port, max_clients)
	if error != OK:
		push_error("[ENetTransport] 创建主机失败: " + str(error))
		_peer = null
		return error

	_last_port = port
	is_server = true
	unique_id = 1
	status = TransportStatus.CONNECTED
	print("[ENetTransport] 主机已创建，端口: ", port, ", 最大客户端: ", max_clients)
	return OK


func create_client(address: String, port: int) -> int:
	if status != TransportStatus.DISCONNECTED:
		push_error("[ENetTransport] 无法连接：当前状态不是 DISCONNECTED")
		return ERR_ALREADY_IN_USE

	_peer = ENetMultiplayerPeer.new()
	var error = _peer.create_client(address, port)
	if error != OK:
		push_error("[ENetTransport] 连接失败: " + str(error))
		_peer = null
		return error

	_last_address = address
	_last_port = port
	is_server = false
	status = TransportStatus.CONNECTING
	_prev_client_status = MultiplayerPeer.CONNECTION_CONNECTING
	print("[ENetTransport] 正在连接 ", address, ":", port)
	return OK


func disconnect_all() -> void:
	if _peer == null:
		return

	_peer.close()
	_peer = null
	_known_peers.clear()
	is_server = false
	unique_id = 0
	status = TransportStatus.DISCONNECTED
	_prev_client_status = MultiplayerPeer.CONNECTION_DISCONNECTED
	print("[ENetTransport] 已断开连接")


func disconnect_peer(peer_id: int) -> void:
	if _peer == null:
		return
	_peer.disconnect_peer(peer_id)
	print("[ENetTransport] 已断开对端: ", peer_id)


# ── ENet 信号处理 ──

func _on_enet_peer_connected(id: int) -> void:
	_known_peers[id] = true
	print("[ENetTransport] 对端已连接 (信号): ", id)
	# 服务器端：立即通知上层（客户端连接由 connection_succeeded 通知）
	if is_server:
		peer_connected.emit(id)


func _on_enet_peer_disconnected(id: int) -> void:
	_known_peers.erase(id)
	print("[ENetTransport] 对端已断开 (信号): ", id)
	if is_server:
		peer_disconnected.emit(id)


func poll() -> void:
	if _peer == null or status == TransportStatus.DISCONNECTED:
		return

	_peer.poll()

	# 客户端：通过轮询 ENet 连接状态检测连接成功/失败
	if not is_server:
		var current_status = _peer.get_connection_status()

		if _prev_client_status != current_status:
			if _prev_client_status == MultiplayerPeer.CONNECTION_CONNECTING and \
			   current_status == MultiplayerPeer.CONNECTION_CONNECTED:
				_prev_client_status = current_status
				unique_id = _peer.get_unique_id()
				status = TransportStatus.CONNECTED
				_known_peers[1] = true  # 服务器 peer ID = 1（信号可能已添加，Dictionary 幂等）
				print("[ENetTransport] 已连接到服务器, UniqueId=", unique_id)
				# 发送握手包，让服务器发现此客户端
				send_reliable(1, HANDSHAKE_CHANNEL, PackedByteArray([0x01]))
				connection_succeeded.emit()
			elif current_status == MultiplayerPeer.CONNECTION_DISCONNECTED:
				_prev_client_status = current_status
				if status == TransportStatus.CONNECTING:
					push_error("[ENetTransport] 连接服务器失败")
					_peer = null
					status = TransportStatus.DISCONNECTED
					connection_failed.emit()
					return
				else:
					print("[ENetTransport] 与服务器的连接已断开")
					status = TransportStatus.DISCONNECTED
					peer_disconnected.emit(1)  # 服务器 peer ID = 1
					return
			else:
				_prev_client_status = current_status

	# 读取并消费所有数据包，防止 Godot RPC 系统处理自定义包
	while _peer != null and _peer.get_available_packet_count() > 0:
		var sender_id = _peer.get_packet_peer()
		var raw_packet = _peer.get_packet()

		if raw_packet == null or raw_packet.size() < 4:
			continue

		var parsed = _parse_packet(raw_packet)
		var channel = parsed[0]
		var data = parsed[1]

		if channel == HANDSHAKE_CHANNEL:
			# 握手包兜底：若信号未触发，服务器通过此包发现新客户端
			if is_server and not _known_peers.has(sender_id):
				_known_peers[sender_id] = true
				print("[ENetTransport] 对端已连接 (握手兜底): ", sender_id)
				peer_connected.emit(sender_id)
			# 握手包不传递给上层
		else:
			# 普通数据包：若服务器收到未知 peer 的包，也触发 peer_connected（兜底）
			if is_server and not _known_peers.has(sender_id):
				_known_peers[sender_id] = true
				print("[ENetTransport] 对端已连接 (首包兜底): ", sender_id)
				peer_connected.emit(sender_id)
			data_received.emit(sender_id, channel, data)

	# 服务器端：检测整体连接断开（安全兜底）
	if is_server and _peer != null:
		var server_status = _peer.get_connection_status()
		if server_status == MultiplayerPeer.CONNECTION_DISCONNECTED:
			print("[ENetTransport] 服务器连接已断开，通知所有已知对端")
			var snapshot = _known_peers.keys()
			_known_peers.clear()
			status = TransportStatus.DISCONNECTED
			for pid in snapshot:
				peer_disconnected.emit(pid)


# ── 数据发送 ──

func send_reliable(peer_id: int, channel: int, data: PackedByteArray) -> void:
	if _peer == null or status != TransportStatus.CONNECTED:
		return
	_peer.set_transfer_mode(MultiplayerPeer.TRANSFER_MODE_RELIABLE)
	var packet = _build_packet(channel, data)
	_send_packet(peer_id, packet)


func send_unreliable(peer_id: int, channel: int, data: PackedByteArray) -> void:
	if _peer == null or status != TransportStatus.CONNECTED:
		return
	_peer.set_transfer_mode(MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)
	var packet = _build_packet(channel, data)
	_send_packet(peer_id, packet)


func _send_packet(peer_id: int, packet: PackedByteArray) -> void:
	if _peer == null:
		return
	_peer.set_target_peer(peer_id)
	var err = _peer.put_packet(packet)
	if err != OK:
		push_error("[ENetTransport] put_packet 失败 (peer=", peer_id, "): ", err)


# ── 辅助方法 ──

func _build_packet(channel: int, data: PackedByteArray) -> PackedByteArray:
	var packet = PackedByteArray()
	# 小端序编码 int32
	packet.append(channel & 0xFF)
	packet.append((channel >> 8) & 0xFF)
	packet.append((channel >> 16) & 0xFF)
	packet.append((channel >> 24) & 0xFF)
	packet.append_array(data)
	return packet


func _parse_packet(packet: PackedByteArray) -> Array:
	if packet.size() < 4:
		return [0, packet]
	# 小端序解码 int32
	var channel = packet[0] | (packet[1] << 8) | (packet[2] << 16) | (packet[3] << 24)
	# 处理负数（符号扩展）
	if channel & 0x80000000:
		channel = channel - 0x100000000
	var data = packet.slice(4)
	return [channel, data]


## 获取上次连接的地址（用于重连）
func get_last_address() -> String:
	return _last_address


## 获取上次连接的端口（用于重连）
func get_last_port() -> int:
	return _last_port

