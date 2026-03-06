class_name RoomInfo
extends RefCounted

## 房间信息数据类，作为广播载荷在网络中传输。
##
## 相比千棋世界的实现，新增 metadata 字典，
## 使用者可存放自定义数据（如游戏模式、地图名）而无需修改插件。
## Magic 改为 EASYMULTI_V1，避免与千棋世界广播冲突。

## 广播魔数，用于过滤非本插件的广播包
var magic: String = "EASYMULTI_V1"

## 房间名称 / 主机名
var host_name: String = ""

## 游戏类型标识
var game_type: String = ""

## 当前玩家数
var player_count: int = 1

## 最大玩家数
var max_players: int = 2

## 游戏端口
var port: int = 27015

## 游戏版本号
var version: String = "1.0.0"

## 广播实例标识，用于过滤自身广播（同一进程内）
var instance_id: String = ""

## 自定义元数据字典，使用者可存放任意键值对
var metadata: Dictionary = {}


## 发现的房间条目，包含房间信息和发现时的元数据。
class DiscoveredRoom:
	## 房间信息
	var info: RoomInfo = RoomInfo.new()

	## 主机 IP 地址
	var host_ip: String = ""

	## 最后一次收到该房间广播的时间戳（引擎时间）
	var last_seen: float = 0.0
