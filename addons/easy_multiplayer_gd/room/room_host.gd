class_name RoomHost
extends Node

## 房间主机逻辑。负责创建房间、广播、等待客人加入、管理准备状态和开始游戏。
##
## 支持多人（不限于 1 个 Guest），通过 _guests 字典跟踪所有客人的准备状态。
## 房间状态机：Idle → Waiting → Ready → Playing → Closed。
##
## 与千棋世界的 RoomHost 不同，此实现不依赖 EventBus，
## 所有事件通过 Godot Signal 暴露。准备状态通过 MessageChannel 传输，
## 而非 Godot RPC，保持与 TransportBase 抽象的一致性。

# ── 内部消息通道标识 ──

## 房间内部控制消息通道
const ROOM_CHANNEL: String = "__room_ctrl"

# ── 消息类型前缀 ──

const MSG_GUEST_READY: String = "guest_ready:"
const MSG_HOST_READY: String = "host_ready:"
const MSG_GAME_START: String = "game_start:"
const MSG_ROOM_INFO: String = "room_info:"

# ── 依赖 ──

var _transport: TransportBase = null
var _discovery: DiscoveryBase = null
var _message_channel: MessageChannel = null
var _config: EasyMultiplayerConfig = EasyMultiplayerConfig.new()

# ── 状态 ──

var _state: RoomState.State = RoomState.State.IDLE

## 当前房间状态
var state: RoomState.State:
	get: return _state
	set(value):
		if _state == value:
			return
		var old = _state
		_state = value
		print("[RoomHost] 房间状态: ", old, " → ", value)
		room_state_changed.emit(old, value)

## 房间名称
var room_name: String = ""

## 游戏类型标识
var game_type: String = ""

## 房间端口
var port: int = 0

## 最大玩家数（含 Host）
var max_players: int = 2

## 房主准备状态
var host_ready: bool = false

## 保存的游戏版本号，用于广播
var _game_version: String = "1.0.0"

## 所有客人的准备状态。键为 peer_id，值为 ready 状态
var _guests: Dictionary = {}

## 获取当前客人 peer ID 列表
var guest_peer_ids: Array:
	get: return _guests.keys()

## 当前玩家数（含 Host）
var player_count: int:
	get: return 1 + _guests.size()

# ── Godot 信号 ──

## 房间状态转换时触发
signal room_state_changed(old_state: RoomState.State, new_state: RoomState.State)

## 客人加入房间时触发
signal guest_joined(peer_id: int)

## 客人离开房间时触发
signal guest_left(peer_id: int)

## 客人准备状态变更时触发
signal guest_ready_changed(peer_id: int, ready: bool)

## 所有人（Host + 全部 Guest）都已准备时触发
signal all_ready()

## 游戏即将开始时触发
signal game_starting(game_type_str: String)


# ── 初始化 ──

## 设置依赖。应在使用前调用
func setup(transport: TransportBase, discovery: DiscoveryBase, message_channel: MessageChannel, config: EasyMultiplayerConfig, game_version: String = "1.0.0") -> void:
	# 清理旧绑定
	if _transport != null:
		_transport.peer_connected.disconnect(_on_peer_connected)
		_transport.peer_disconnected.disconnect(_on_peer_disconnected)
	if _message_channel != null:
		_message_channel.message_received.disconnect(_on_message_received)

	_transport = transport
	_discovery = discovery
	_message_channel = message_channel
	_config = config
	_game_version = game_version

	_transport.peer_connected.connect(_on_peer_connected)
	_transport.peer_disconnected.connect(_on_peer_disconnected)
	_message_channel.message_received.connect(_on_message_received)


# ── 公共 API ──

## 创建房间并开始广播
func create_room(name: String, game_type_str: String, port_override: int = -1, max_players_override: int = -1) -> Error:
	if _transport == null or _discovery == null:
		push_error("[RoomHost] 未初始化，请先调用 setup()")
		return ERR_UNCONFIGURED

	if state != RoomState.State.IDLE and state != RoomState.State.CLOSED:
		push_error("[RoomHost] 无法创建房间：当前状态不允许")
		return ERR_ALREADY_IN_USE

	room_name = name
	game_type = game_type_str
	port = port_override if port_override > 0 else _config.port
	max_players = max_players_override if max_players_override > 0 else _config.max_clients + 1
	host_ready = false
	_guests.clear()

	# 创建传输层主机
	var error = _transport.create_host(port, max_players - 1)
	if error != OK:
		push_error("[RoomHost] 创建主机失败: ", error)
		return error

	# 开始广播
	var room_info = RoomInfo.new()
	room_info.host_name = name
	room_info.game_type = game_type_str
	room_info.port = port
	room_info.player_count = 1
	room_info.max_players = max_players
	room_info.version = _game_version
	_discovery.start_broadcast(room_info)

	state = RoomState.State.WAITING
	print("[RoomHost] 房间已创建: ", name, " (", game_type_str, ") 端口:", port, " 最大玩家:", max_players)
	return OK


## 仅停止广播，不断开已连接的客人。
## 用于对手加入后停止广播，同时保持连接
func stop_broadcast() -> void:
	if _discovery != null:
		_discovery.stop_broadcast()
	print("[RoomHost] 广播已停止（连接保持）")


## 关闭房间，清理所有资源
func close_room() -> void:
	if _discovery != null:
		_discovery.stop_broadcast()

	# 断开所有客人
	if _transport != null:
		for peer_id in _guests.keys():
			_transport.disconnect_peer(peer_id)

	host_ready = false
	_guests.clear()
	state = RoomState.State.CLOSED
	print("[RoomHost] 房间已关闭")


## 设置房主准备状态，并通知所有客人
func set_host_ready(ready: bool) -> void:
	if state != RoomState.State.READY:
		print("[RoomHost] 无法设置准备状态：房间不在 Ready 状态")
		return

	host_ready = ready
	print("[RoomHost] 房主准备状态: ", ready)

	# 通知所有客人
	if _message_channel != null:
		var msg = (MSG_HOST_READY + str(ready)).to_utf8_buffer()
		_message_channel.broadcast(ROOM_CHANNEL, msg)

	_check_all_ready()


## 开始游戏。仅在所有人都准备就绪时有效
func start_game() -> void:
	if state != RoomState.State.READY:
		push_error("[RoomHost] 无法开始游戏：房间不在 Ready 状态")
		return

	if not host_ready or not are_all_guests_ready():
		push_error("[RoomHost] 无法开始游戏：未全部准备就绪")
		return

	state = RoomState.State.PLAYING

	# 通知所有客人游戏开始
	if _message_channel != null:
		var msg = (MSG_GAME_START + game_type).to_utf8_buffer()
		_message_channel.broadcast(ROOM_CHANNEL, msg)

	print("[RoomHost] 游戏开始: ", game_type)
	game_starting.emit(game_type)


## 重置所有准备状态
func reset_ready_state() -> void:
	host_ready = false
	for peer_id in _guests.keys():
		_guests[peer_id] = false
	print("[RoomHost] 准备状态已重置")


## 检查指定客人是否已准备
func is_guest_ready(peer_id: int) -> bool:
	return _guests.get(peer_id, false)


## 检查是否所有客人都已准备
func are_all_guests_ready() -> bool:
	if _guests.is_empty():
		return false
	for ready in _guests.values():
		if not ready:
			return false
	return true


# ── Node 生命周期 ──

## 节点退出场景树时清理
func _exit_tree() -> void:
	if state != RoomState.State.IDLE and state != RoomState.State.CLOSED:
		close_room()

	if _transport != null:
		_transport.peer_connected.disconnect(_on_peer_connected)
		_transport.peer_disconnected.disconnect(_on_peer_disconnected)
	if _message_channel != null:
		_message_channel.message_received.disconnect(_on_message_received)


# ── 内部事件处理 ──

## 对端连接事件处理
func _on_peer_connected(peer_id: int) -> void:
	if state != RoomState.State.WAITING and state != RoomState.State.READY:
		return

	# 检查是否已满
	if player_count >= max_players:
		print("[RoomHost] 房间已满，拒绝 peer ", peer_id)
		if _transport != null:
			_transport.disconnect_peer(peer_id)
		return

	_guests[peer_id] = false
	print("[RoomHost] 客人已加入: ", peer_id, " (当前 ", player_count, "/", max_players, ")")
	guest_joined.emit(peer_id)

	# 发送房间信息给新加入的客人
	var room_info_msg = MSG_ROOM_INFO + room_name + "|" + game_type
	if _message_channel != null:
		_message_channel.send_reliable(peer_id, ROOM_CHANNEL, room_info_msg.to_utf8_buffer())

	# 更新广播中的玩家数
	_update_broadcast()

	# 如果房间已满，停止广播并进入 Ready 状态
	if player_count >= max_players:
		if _discovery != null:
			_discovery.stop_broadcast()
		if state == RoomState.State.WAITING:
			state = RoomState.State.READY
	elif state == RoomState.State.WAITING and _guests.size() > 0:
		# 有人加入但未满，也进入 Ready 状态（允许提前开始）
		state = RoomState.State.READY


## 对端断开事件处理
func _on_peer_disconnected(peer_id: int) -> void:
	if not _guests.has(peer_id):
		return

	_guests.erase(peer_id)
	print("[RoomHost] 客人已离开: ", peer_id, " (剩余 ", player_count, "/", max_players, ")")
	guest_left.emit(peer_id)

	# 客人离开时重置 host_ready 状态，确保多人场景下准备状态一致
	host_ready = false

	# 如果在 Ready 或 Waiting 状态，根据剩余人数调整
	if state == RoomState.State.READY:
		if _guests.is_empty():
			# 没有客人了，回到 Waiting 并重新广播
			if _discovery != null:
				var room_info = RoomInfo.new()
				room_info.host_name = room_name
				room_info.game_type = game_type
				room_info.port = port
				room_info.player_count = 1
				room_info.max_players = max_players
				room_info.version = _game_version
				_discovery.start_broadcast(room_info)
			state = RoomState.State.WAITING
		else:
			# 还有客人，重新广播（如果未满）
			if player_count < max_players:
				_update_broadcast()
				if _discovery != null:
					var room_info = RoomInfo.new()
					room_info.host_name = room_name
					room_info.game_type = game_type
					room_info.port = port
					room_info.player_count = player_count
					room_info.max_players = max_players
					room_info.version = _game_version
					_discovery.start_broadcast(room_info)


## 消息接收处理。处理房间控制消息
func _on_message_received(peer_id: int, channel: String, data: PackedByteArray) -> void:
	if channel != ROOM_CHANNEL:
		return

	var msg = data.get_string_from_utf8()

	if msg.begins_with(MSG_GUEST_READY):
		var ready_str = msg.substr(MSG_GUEST_READY.length())
		var ready = ready_str == "true"
		if _guests.has(peer_id):
			_guests[peer_id] = ready
			print("[RoomHost] 客人 ", peer_id, " 准备状态: ", ready)
			guest_ready_changed.emit(peer_id, ready)
			_check_all_ready()


## 检查是否所有人都已准备，如果是则触发 all_ready 信号
func _check_all_ready() -> void:
	if not host_ready or not are_all_guests_ready():
		return

	print("[RoomHost] 所有人已就绪！")
	all_ready.emit()


## 更新广播中的玩家数信息
func _update_broadcast() -> void:
	if _discovery == null or not _discovery.is_broadcasting:
		return

	# 停止旧广播，启动新广播（更新玩家数）
	_discovery.stop_broadcast()
	var room_info = RoomInfo.new()
	room_info.host_name = room_name
	room_info.game_type = game_type
	room_info.port = port
	room_info.player_count = player_count
	room_info.max_players = max_players
	room_info.version = _game_version
	_discovery.start_broadcast(room_info)
