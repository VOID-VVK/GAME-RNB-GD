extends Node2D
class_name NPCNode

## NPC 节点类
## 作为场景节点，内部持有 NPC 数据对象

enum NPCType {
	VILLAGER,
	MERCHANT,
	GUARD,
	QUEST_GIVER
}

@export var npc_name: String = "NPC"
@export var npc_type: NPCType = NPCType.VILLAGER

func _ready():
	# 可以在这里初始化 NPC 数据对象
	pass

func interact():
	print("[%s] 与你交谈" % npc_name)
