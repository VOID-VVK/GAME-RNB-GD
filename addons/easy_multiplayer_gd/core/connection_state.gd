class_name ConnectionState
extends RefCounted

## 连接状态枚举，表示 EasyMultiplayer 的连接生命周期阶段。
##
## 状态转换规则：
## - Disconnected → Hosting：调用 host()
## - Disconnected → Joining：调用 join()
## - Hosting → Connected：收到 peer_connected
## - Joining → Connected：收到 connection_succeeded
## - Connected → Reconnecting：心跳超时或 peer_disconnected（非主动退出）
## - Reconnecting → Connected：对端重新连接成功
## - Reconnecting → Disconnected：重连超时或用户取消
## - Any → Disconnected：调用 disconnect_all()

enum State {
	DISCONNECTED,  ## 初始状态或已断开连接
	HOSTING,       ## 作为主机等待客户端连接
	JOINING,       ## 客户端正在连接到主机
	CONNECTED,     ## 已连接，双方在线
	RECONNECTING   ## 对端断线，等待重连中
}

## 网络质量分级枚举，基于 RTT（往返时延）评估。
##
## - Good：RTT < 100ms
## - Warning：100ms ≤ RTT < 300ms
## - Bad：RTT ≥ 300ms 或断线
enum NetQuality {
	GOOD,     ## 网络质量良好，RTT < 100ms
	WARNING,  ## 网络质量一般，100ms ≤ RTT < 300ms
	BAD       ## 网络质量差，RTT ≥ 300ms 或断线
}

## 客户端状态枚举，表示 RoomClient 的生命周期阶段。
##
## 状态转换规则：
## - Idle → Searching：调用 start_searching()
## - Searching → Joining：调用 join_room()
## - Joining → InRoom：连接成功
## - InRoom → GameStarting：收到游戏开始消息
## - Any → Idle：调用 leave_room() 或连接失败
enum ClientState {
	IDLE,           ## 初始状态或已离开房间
	SEARCHING,      ## 正在搜索局域网房间
	JOINING,        ## 正在加入房间
	IN_ROOM,        ## 已在房间中
	GAME_STARTING   ## 游戏即将开始
}
