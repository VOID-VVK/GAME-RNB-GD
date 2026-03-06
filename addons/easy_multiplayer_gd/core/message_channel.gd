class_name MessageChannel
extends RefCounted

## 通用消息通道。提供统一的消息收发接口，替代散落的业务 RPC。
##
## 插件不解析消息内容，只负责投递。使用者通过 string channel 标识逻辑通道
## （如 "move"、"chat"、"sync"），自行定义消息格式。
##
## 支持 Reliable（可靠，保证送达且按序）和 Unreliable（不可靠，适合高频低优先数据）两种模式。
## 内置 RPC 频率限制，超过频率的消息会被静默丢弃并打印警告日志。

## 消息通道使用的内部传输通道编号（避免与心跳通道 255 冲突）
const TRANSPORT_CHANNEL: int = 0

# ── 依赖 ──

var _transport: TransportBase = null

# ── 频率限制 ──

## 每通道最小发送间隔（毫秒），0 表示不限制
var rpc_min_interval_ms: float = 100.0

## 记录每个逻辑通道上次发送时间（毫秒）
var _channel_last_send_time: Dictionary = {}

# ── 信号 ──

## 收到消息时触发
## peer_id: 发送方对端 ID
## channel: 逻辑通道标识
## data: 消息载荷
signal message_received(peer_id: int, channel: String, data: PackedByteArray)


# ── 初始化 ──

## 设置传输层引用。应在使用前调用
func set_transport(transport: TransportBase) -> void:
	if _transport != null:
		_transport.data_received.disconnect(_on_data_received)

	_transport = transport
	_transport.data_received.connect(_on_data_received)


# ── 公共 API ──

## 发送可靠消息（PackedByteArray 载荷）。保证送达且按序
func send_reliable(peer_id: int, channel: String, data: PackedByteArray) -> void:
	if not _check_rate_limit(channel):
		return
	var packet = _pack_message(channel, data)
	_transport.send_reliable(peer_id, TRANSPORT_CHANNEL, packet)


## 发送可靠消息（String 载荷，自动 UTF-8 编码）
func send_reliable_string(peer_id: int, channel: String, data: String) -> void:
	send_reliable(peer_id, channel, data.to_utf8_buffer())


## 发送不可靠消息。不保证送达，适合高频低优先数据
func send_unreliable(peer_id: int, channel: String, data: PackedByteArray) -> void:
	if not _check_rate_limit(channel):
		return
	var packet = _pack_message(channel, data)
	_transport.send_unreliable(peer_id, TRANSPORT_CHANNEL, packet)


## 广播消息给所有已连接对端
## channel: 逻辑通道标识
## data: 消息载荷
## reliable: 是否使用可靠传输，默认 true
func broadcast(channel: String, data: PackedByteArray, reliable: bool = true) -> void:
	if not _check_rate_limit(channel):
		return
	var packet = _pack_message(channel, data)

	# peer_id = 0 表示广播给所有对端
	if reliable:
		_transport.send_reliable(0, TRANSPORT_CHANNEL, packet)
	else:
		_transport.send_unreliable(0, TRANSPORT_CHANNEL, packet)


## 重置频率限制计时器
func reset_rate_limits() -> void:
	_channel_last_send_time.clear()


# ── 内部逻辑 ──

## 检查指定通道是否超过频率限制
## 返回 true 表示放行，false 表示被限制
func _check_rate_limit(channel: String) -> bool:
	if rpc_min_interval_ms <= 0:
		return true

	var now_ms = Time.get_unix_time_from_system() * 1000.0
	if _channel_last_send_time.has(channel):
		var last_ms = _channel_last_send_time[channel]
		if now_ms - last_ms < rpc_min_interval_ms:
			print("[MessageChannel] 频率限制: 通道 \"", channel, "\" 被拒绝 (间隔 ", now_ms - last_ms, "ms < ", rpc_min_interval_ms, "ms)")
			return false

	_channel_last_send_time[channel] = now_ms
	return true


## 将逻辑通道名和数据打包为传输包
## 格式：[channelNameLength:2bytes][channelName:UTF8][data]
func _pack_message(channel: String, data: PackedByteArray) -> PackedByteArray:
	var channel_bytes = channel.to_utf8_buffer()
	var channel_len = channel_bytes.size()

	var packet = PackedByteArray()
	# 小端序编码 uint16
	packet.append(channel_len & 0xFF)
	packet.append((channel_len >> 8) & 0xFF)
	packet.append_array(channel_bytes)
	packet.append_array(data)

	return packet


## 从传输包中解析逻辑通道名和数据
## 返回 [channel: String, data: PackedByteArray]，解析失败返回 null
func _unpack_message(packet: PackedByteArray) -> Array:
	if packet.size() < 2:
		return []

	# 小端序解码 uint16
	var channel_len = packet[0] | (packet[1] << 8)
	if packet.size() < 2 + channel_len:
		return []

	var channel_bytes = packet.slice(2, 2 + channel_len)
	var channel = channel_bytes.get_string_from_utf8()
	var data_offset = 2 + channel_len
	var data = packet.slice(data_offset)

	return [channel, data]


## 传输层数据接收回调。解析消息并触发 message_received 信号
func _on_data_received(peer_id: int, transport_channel: int, raw_data: PackedByteArray) -> void:
	# 只处理消息通道的数据，忽略心跳等其他通道
	if transport_channel != TRANSPORT_CHANNEL:
		return

	var result = _unpack_message(raw_data)
	if result.is_empty():
		push_error("[MessageChannel] 收到无法解析的消息包 (peerId=", peer_id, ", len=", raw_data.size(), ")")
		return

	var channel = result[0]
	var data = result[1]
	message_received.emit(peer_id, channel, data)
