class_name BattleRules
extends RefCounted
## 戦闘予測と移動探索は状態を変更しない。

const DIRECTIONS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]


static func position_of(unit: Dictionary) -> Vector2i:
	return Vector2i(unit.x, unit.y)


static func distance(first: Vector2i, second: Vector2i) -> int:
	return absi(first.x - second.x) + absi(first.y - second.y)


static func triangle(attacker: String, defender: String) -> int:
	var beats: Dictionary = {"sword": "axe", "axe": "lance", "lance": "sword"}
	if beats.get(attacker, "") == defender:
		return 1
	if beats.get(defender, "") == attacker:
		return -1
	return 0


static func can_reach(attacker: Dictionary, target: Dictionary) -> bool:
	var reach: int = 2 if attacker.job == "bow" else 1
	return distance(position_of(attacker), position_of(target)) == reach


static func strike(attacker: Dictionary, target: Dictionary, map: Array) -> Dictionary:
	var ground: Dictionary = BattleData.terrain(position_of(target), map)
	var advantage: int = triangle(attacker.job, target.job)
	return {
		"damage": maxi(0, attacker.strength + advantage * 2 - target.defense - ground.defense),
		"hit": clampi(85 + attacker.skill * 2 - target.speed * 2
			+ advantage * 15 - ground.evasion, 5, 100),
		"critical": clampi(attacker.skill - target.speed, 0, 25),
	}


static func forecast(attacker: Dictionary, target: Dictionary, map: Array) -> Dictionary:
	var result: Dictionary = strike(attacker, target, map)
	var counter: Dictionary = strike(target, attacker, map)
	var can_counter: bool = target.job != "healer" and can_reach(target, attacker)
	result.merge({"strikes": 2 if attacker.speed - target.speed >= 4 else 1,
		"counter_damage": counter.damage if can_counter else 0,
		"counter_hit": counter.hit if can_counter else 0,
		"counter_strikes": (2 if target.speed - attacker.speed >= 4 else 1) if can_counter else 0,
		"heal": attacker.strength + 8 if attacker.job == "healer" else 0})
	return result


static func movement(unit: Dictionary, units: Array[Dictionary], map: Array) -> Array[Vector2i]:
	var origin: Vector2i = position_of(unit)
	var costs: Dictionary = {origin: 0}
	var frontier: Array[Vector2i] = [origin]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_front()
		for direction: Vector2i in DIRECTIONS:
			var next: Vector2i = cell + direction
			if not BattleData.inside(next) or occupied(next, units, unit.team, true):
				continue
			var cost: int = costs[cell] + BattleData.terrain(next, map).cost
			if cost > unit.move or cost >= costs.get(next, 999):
				continue
			costs[next] = cost
			frontier.append(next)
	var result: Array[Vector2i] = []
	for cell: Vector2i in costs:
		if cell == origin or not occupied(cell, units, unit.team, false):
			result.append(cell)
	return result


static func occupied(
	cell: Vector2i, units: Array[Dictionary], team: String, enemies_only: bool
) -> bool:
	for unit: Dictionary in units:
		if unit.hp > 0 and position_of(unit) == cell:
			if not enemies_only or unit.team != team:
				return true
	return false
