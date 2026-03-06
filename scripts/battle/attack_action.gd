class_name AttackAction
extends BaseAction

## 攻击行动

func _init(p_actor: Character, p_target: Character) -> void:
	super("attack", p_actor, p_target)

func execute() -> int:
	if not actor.stats.is_alive:
		print("[%s] 已死亡，无法攻击" % actor.character_name)
		return TurnEnums.ActionResult.FAILED

	if not target or not target.stats.is_alive:
		print("[%s] 目标无效或已死亡" % actor.character_name)
		return TurnEnums.ActionResult.FAILED

	actor.attack_target(target)
	return TurnEnums.ActionResult.SUCCESS
