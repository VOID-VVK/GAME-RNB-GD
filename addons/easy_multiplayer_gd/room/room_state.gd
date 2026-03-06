class_name RoomState
extends RefCounted

## 房间主机状态枚举。
##
## 状态转换规则：
## - Idle → Waiting：调用 create_room()
## - Waiting → Ready：有客人加入（peer_joined）
## - Ready → Playing：调用 start_game()
## - Ready → Waiting：客人离开（peer_left）
## - Any → Closed：调用 close_room()
## - Closed → Idle：可重新创建房间

enum State {
	IDLE,     ## 空闲，未创建房间
	WAITING,  ## 等待客人加入
	READY,    ## 客人已加入，准备阶段
	PLAYING,  ## 游戏进行中
	CLOSED    ## 房间已关闭
}

## 房间客户端状态枚举。
##
## 状态转换规则：
## - Idle → Searching：调用 start_searching()
## - Searching → Joining：调用 join_room()
## - Idle → Joining：直接调用 join_room()（手动输入 IP）
## - Joining → InRoom：连接成功
## - Joining → Idle：连接失败
## - InRoom → GameStarting：收到游戏开始通知
## - InRoom → Idle：调用 leave_room() 或断开连接
## - GameStarting → Idle：断开连接

enum ClientState {
	IDLE,           ## 空闲
	SEARCHING,      ## 正在搜索房间
	JOINING,        ## 正在加入房间
	IN_ROOM,        ## 已在房间中
	GAME_STARTING   ## 游戏即将开始
}
