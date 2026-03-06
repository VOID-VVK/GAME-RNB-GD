## 存档数据基类。游戏继承此类，加 @export 字段定义自己的存档结构。
class_name EasySaveData
extends Resource

@export var description: String = ""
@export var save_time: String = ""
