## EasySave 主管理器（作为 Autoload 使用）
extends Node

static var instance: Node

@export var config: EasySaveConfig = EasySaveConfig.new()

signal slot_saved(slot: int)
signal slot_loaded(slot: int)

var _pending_load: EasySaveData


func _ready() -> void:
	instance = self


## 存档到指定槽位。自动填充 save_time。
func save_to_slot(slot: int, data: EasySaveData) -> void:
	var dt := Time.get_datetime_dict_from_system()
	data.save_time = "%04d-%02d-%02d %02d:%02d" % [
		dt["year"], dt["month"], dt["day"],
		dt["hour"], dt["minute"]
	]
	SaveSlotManager.save(slot, data, config.save_directory)
	slot_saved.emit(slot)
	print("[EasySave] 已保存到槽位 %d" % slot)


## 从指定槽位加载数据。
func load_from_slot(slot: int) -> EasySaveData:
	return SaveSlotManager.load_slot(slot, config.save_directory)


## 加载槽位数据并存入 pending，发射 slot_loaded 信号。
## 用于跨场景传递：信号回调中切场景，新场景 _ready() 调用 consume_pending_load。
func load_to_slot(slot: int) -> void:
	_pending_load = SaveSlotManager.load_slot(slot, config.save_directory)
	slot_loaded.emit(slot)
	print("[EasySave] 已加载槽位 %d" % slot)


## 取出跨场景传递的数据（取一次就清空）。
func consume_pending_load() -> EasySaveData:
	var data := _pending_load
	_pending_load = null
	return data


## 只读元数据（description + save_time），不需要知道游戏数据类型。
func peek_slot(slot: int) -> EasySaveData:
	return SaveSlotManager.peek(slot, config.save_directory)


func has_save(slot: int) -> bool:
	return SaveSlotManager.has_save(slot, config.save_directory)


func delete_slot(slot: int) -> void:
	SaveSlotManager.delete(slot, config.save_directory)
	print("[EasySave] 已删除槽位 %d" % slot)
