## 槽位文件操作。纯静态方法，不持有状态。
class_name SaveSlotManager
extends RefCounted


static func get_slot_path(slot: int, dir: String) -> String:
	return "%s/save_%d.tres" % [dir, slot]


static func save(slot: int, data: EasySaveData, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var path := get_slot_path(slot, dir)
	var err := ResourceSaver.save(data, path)
	if err != OK:
		push_error("[EasySave] 存档失败 slot=%d: %s" % [slot, error_string(err)])


static func load_slot(slot: int, dir: String) -> EasySaveData:
	var path := get_slot_path(slot, dir)
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as EasySaveData


static func peek(slot: int, dir: String) -> EasySaveData:
	return load_slot(slot, dir)


static func has_save(slot: int, dir: String) -> bool:
	return FileAccess.file_exists(get_slot_path(slot, dir))


static func delete(slot: int, dir: String) -> void:
	var path := get_slot_path(slot, dir)
	if FileAccess.file_exists(path):
		var da := DirAccess.open(dir)
		if da:
			da.remove(path.get_file())
