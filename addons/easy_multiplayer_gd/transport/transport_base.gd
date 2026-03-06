class_name TransportBase
extends RefCounted

## 传输层抽象基类。所有网络传输实现（ENet、WebSocket 等）均需继承此类。
##
## 设计目标：将插件与具体传输实现解耦，便于未来扩展 WebSocket、Steam Networking 等传输层。
##
## poll() 方法需在每帧调用以驱动内部事件循环，
## 这使得非 Godot 原生的传输实现也能在 _process 中被驱动。

## 传输层状态枚举
enum TransportStatus {
	DISCONNECTED,  ## 未连接
	CONNECTING,    ## 正在连接中
	CONNECTED      ## 已连接
}

# ── 事件回调（由实现者触发） ──

## 对端连接成功时触发。参数为对端 ID
signal peer_connected(peer_id: int)

## 对端断开连接时触发。参数为对端 ID
signal peer_disconnected(peer_id: int)

## 收到数据时触发。参数依次为：对端 ID、通道编号、数据载荷
signal data_received(peer_id: int, channel: int, data: PackedByteArray)

## 客户端连接主机成功时触发
signal connection_succeeded()

## 客户端连接主机失败时触发
signal connection_failed()

# ── 属性 ──

## 当前是否为服务端（Host）
var is_server: bool = false:
	get: return is_server

## 本机的唯一标识符
var unique_id: int = 0:
	get: return unique_id

## 当前传输层状态
var status: TransportStatus = TransportStatus.DISCONNECTED:
	get: return status

# ── 生命周期 ──

## 创建主机（服务端），开始监听指定端口。
## port: 监听端口，默认 27015
## max_clients: 最大客户端数，默认 1
## 返回操作结果，OK 表示成功
func create_host(port: int, max_clients: int) -> int:
	push_error("TransportBase.create_host() 必须被子类实现")
	return ERR_UNAVAILABLE

## 创建客户端，连接到指定主机。
## address: 目标主机 IP 地址
## port: 目标端口
## 返回操作结果，OK 表示成功
func create_client(address: String, port: int) -> int:
	push_error("TransportBase.create_client() 必须被子类实现")
	return ERR_UNAVAILABLE

## 断开所有连接并释放资源
func disconnect_all() -> void:
	push_error("TransportBase.disconnect_all() 必须被子类实现")

## 断开指定对端的连接
## peer_id: 要断开的对端标识符
func disconnect_peer(peer_id: int) -> void:
	push_error("TransportBase.disconnect_peer() 必须被子类实现")

## 每帧调用，驱动内部事件循环
func poll() -> void:
	push_error("TransportBase.poll() 必须被子类实现")

# ── 数据发送 ──

## 通过可靠通道发送数据。保证送达且按序。
## peer_id: 目标对端标识符
## channel: 逻辑通道编号（0 = 默认）
## data: 原始数据载荷
func send_reliable(peer_id: int, channel: int, data: PackedByteArray) -> void:
	push_error("TransportBase.send_reliable() 必须被子类实现")

## 通过不可靠通道发送数据。不保证送达，适合高频低优先数据。
## peer_id: 目标对端标识符
## channel: 逻辑通道编号（0 = 默认）
## data: 原始数据载荷
func send_unreliable(peer_id: int, channel: int, data: PackedByteArray) -> void:
	push_error("TransportBase.send_unreliable() 必须被子类实现")
