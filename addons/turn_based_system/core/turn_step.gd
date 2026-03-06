class_name TurnStep

## 需要行动的单位（单位级行动时非 null）
## 实现 ITurnUnit 约定的对象
var unit = null

## 需要行动的阵营（阵营级行动时非 null）
## 实现 ITurnFaction 约定的对象
var faction = null

## 是否为同时行动（所有方同时规划）
var is_simultaneous: bool = false
