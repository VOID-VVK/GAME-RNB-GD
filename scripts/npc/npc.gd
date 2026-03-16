class_name NPC
extends Character

## NPC 类
## 组合 Character，添加 NPC 特有逻辑

## NPC 类型枚举
enum NPCType {
	VILLAGER,    # 村民
	MERCHANT,    # 商人
	GUARD,       # 守卫
	QUEST_GIVER  # 任务发布者
}

var npc_type: NPCType
var dialogue: Array[String] = []  # 对话内容

func _init(p_unit_id: String, p_name: String, p_npc_type: NPCType = NPCType.VILLAGER) -> void:
	# 创建 NPC 属性（普通属性）
	var npc_stats = CharacterStats.new(100, 10, 5, 10)
	super(p_unit_id, "npc", p_name, npc_stats)
	npc_type = p_npc_type

## 设置对话内容
func set_dialogue(lines: Array[String]) -> void:
	dialogue = lines

## 获取对话内容
func get_dialogue() -> Array[String]:
	return dialogue

## NPC 特有行为可在此扩展
func interact() -> void:
	print("[%s] 与你交谈" % character_name)
	if dialogue.size() > 0:
		print("  对话: %s" % dialogue[0])
