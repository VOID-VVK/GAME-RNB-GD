class_name TurnTemplates

## 8 种回合制预设模板

## 象棋/围棋 — 双方严格交替
static func classic() -> TurnSystemConfig:
	return TurnSystemConfig.new(
		AlternatingOrder.new(),
		SingleAction.new(),
		ImmediateResolution.new(),
		SinglePhaseSequence.new(),
	)

## 火焰纹章/XCOM — 阵营全体行动
static func faction(faction_count: int = 2) -> TurnSystemConfig:
	return TurnSystemConfig.new(
		FactionRoundRobin.new(faction_count),
		SingleAction.new(),
		BatchResolution.new(),
		SinglePhaseSequence.new(),
	)

## 博德之门3/FFX — 速度先攻制
static func initiative(recalc_after_action: bool = false) -> TurnSystemConfig:
	return TurnSystemConfig.new(
		InitiativeQueue.new(recalc_after_action),
		SingleAction.new(),
		ImmediateResolution.new(),
		SinglePhaseSequence.new(),
	)

## FF ATB — 半即时制
static func atb(gauge_speed: float = 1.0) -> TurnSystemConfig:
	return TurnSystemConfig.new(
		ATBGaugeOrder.new(gauge_speed),
		GaugeBasedBudget.new(),
		ImmediateResolution.new(),
		SinglePhaseSequence.new(),
	)

## 女神异闻录 — 弱点连锁制
static func press_turn(icons_per_turn: int = 4) -> TurnSystemConfig:
	return TurnSystemConfig.new(
		ConditionalOrder.new(),
		PressTurnIconsBudget.new(icons_per_turn),
		ImmediateResolution.new(),
		PressTurnPhasesSequence.new(),
	)

## 文明多人/Into the Breach — 同时行动制
static func simultaneous() -> TurnSystemConfig:
	return TurnSystemConfig.new(
		AllAtOnce.new(),
		SingleAction.new(),
		SimultaneousResolution.new(),
		PlanResolveSequence.new(),
	)

## 杀戮尖塔/神界原罪2 — 资源驱动制
static func resource(default_ap: int = 3) -> TurnSystemConfig:
	return TurnSystemConfig.new(
		FactionRoundRobin.new(2),
		ActionPointsBudget.new(default_ap),
		ImmediateResolution.new(),
		CardPhasesSequence.new(),
	)

## Nethack/不思议迷宫 — Roguelike 滴答制
static func tick() -> TurnSystemConfig:
	return TurnSystemConfig.new(
		TickOrder.new(),
		SingleAction.new(),
		ImmediateResolution.new(),
		SinglePhaseSequence.new(),
	)
