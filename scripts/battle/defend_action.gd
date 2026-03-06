class_name DefendAction
extends BaseAction

## 防御行动

func _init(p_actor: Character) -> void:
	super("defend", p_actor, null)

func execute() -> int:
	if not actor.stats.is_alive:
		print("[%s] 已死亡，无法防御" % actor.character_name)
		return TurnEnums.ActionResult.FAILED

	print("[%s] 进入防御姿态" % actor.character_name)
	# 后续可添加防御状态效果（提升防御力）
	return TurnEnums.ActionResult.SUCCESS
