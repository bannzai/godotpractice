extends RefCounted
## 入力を変更せず、同じ入力から同じ街を返す月次シミュレーション。

const SIZE: int = 32
const GOAL_POPULATION: int = 600
const MAX_LEVEL: int = 3
const COSTS: Dictionary = {
	"empty": 10,
	"road": 15,
	"residential": 35,
	"commercial": 45,
	"industrial": 55,
	"power": 900,
	"park": 100,
	"police": 450,
	"fire": 400,
}
const UPKEEP: Dictionary = {
	"empty": 0,
	"road": 1,
	"residential": 0,
	"commercial": 0,
	"industrial": 0,
	"power": 65,
	"park": 5,
	"police": 28,
	"fire": 24,
}
const ZONES: Array[String] = ["residential", "commercial", "industrial"]
const DIRECTIONS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]


static func new_city() -> Dictionary:
	var tiles: Array[Dictionary] = []
	for y: int in SIZE:
		for x: int in SIZE:
			var terrain: String = "flat"
			if x > 25 + int(sin(float(y) * 0.4) * 2.0):
				terrain = "water"
			elif (x * 17 + y * 11) % 19 < 3 and (x < 6 or y < 5 or y > 23):
				terrain = "forest"
			tiles.append({"terrain": terrain, "kind": "empty", "level": 0, "age": 0})
	for x: int in range(7, 23):
		tiles[15 * SIZE + x].kind = "road"
	for y: int in range(10, 21):
		tiles[y * SIZE + 14].kind = "road"
	tiles[16 * SIZE + 7].kind = "power"
	for x: int in range(8, 14):
		tiles[14 * SIZE + x].kind = "residential"
	for y: int in range(11, 14):
		tiles[y * SIZE + 13].kind = "residential"
	for x: int in range(17, 21):
		tiles[16 * SIZE + x].kind = "industrial"
	for x: int in range(15, 18):
		tiles[14 * SIZE + x].kind = "commercial"
	tiles[16 * SIZE + 11].kind = "park"
	tiles[16 * SIZE + 13].kind = "police"
	tiles[16 * SIZE + 15].kind = "fire"
	return {
		"version": 1,
		"tiles": tiles,
		"money": 6000,
		"population": 0,
		"jobs": 0,
		"month": 0,
		"tax": 9,
		"negative_months": 0,
		"outcome": "playing",
		"income": 0,
		"expenses": 0,
		"demand": {"r": 60, "c": 40, "i": 50},
	}


static func can_place(state: Dictionary, cell: Vector2i, kind: String) -> bool:
	if not _inside(cell) or not COSTS.has(kind) or state.outcome != "playing":
		return false
	var tile: Dictionary = state.tiles[cell.y * SIZE + cell.x]
	return (
		state.money >= COSTS[kind]
		and tile.terrain != "water"
		and tile.kind != kind
		and (kind == "empty" or tile.kind == "empty")
	)


static func place(state: Dictionary, cell: Vector2i, kind: String) -> Dictionary:
	var result: Dictionary = state.duplicate(true)
	if can_place(state, cell, kind):
		var index: int = cell.y * SIZE + cell.x
		result.tiles[index] = {"terrain": "flat", "kind": kind, "level": 0, "age": 0}
		result.money -= COSTS[kind]
		_update_totals(result)
		result.demand = _demand(result)
	return result


## 月を進める操作のため、返した状態を再入力すると次の月になる。同一入力の再計算は同一結果。
static func advance_month(state: Dictionary) -> Dictionary:
	var result: Dictionary = state.duplicate(true)
	if state.outcome != "playing":
		return result
	var report: Dictionary = analyze(state)
	result.month += 1
	for index: int in SIZE * SIZE:
		var tile: Dictionary = result.tiles[index]
		if tile.kind not in ZONES:
			continue
		tile.age += 1
		var bad: bool = (
			not report.road_access[index]
			or not report.powered[index]
			or report.crime[index] >= 65
			or report.fire_risk[index] >= 75
			or (tile.kind == "residential" and report.pollution[index] >= 55)
		)
		var demand_key: String = {"residential": "r", "commercial": "c", "industrial": "i"}[
			tile.kind
		]
		var wanted: int = report.demand[demand_key]
		if (bad or wanted < -20 or state.tax >= 18) and tile.age % 2 == 0:
			tile.level = maxi(0, tile.level - 1)
		elif not bad and wanted > 0 and tile.age % 3 == 0:
			tile.level = mini(MAX_LEVEL, tile.level + 1)
	_update_totals(result)
	result.income = int((result.population * 0.7 + result.jobs * 0.55) * result.tax / 9.0)
	result.expenses = _expenses(result)
	result.money += result.income - result.expenses
	result.negative_months = state.negative_months + 1 if result.money < 0 else 0
	result.demand = _demand(result)
	if result.negative_months >= 3:
		result.outcome = "defeat"
	elif result.population >= GOAL_POPULATION:
		result.outcome = "clear"
	return result


static func analyze(state: Dictionary) -> Dictionary:
	var roads: Array[bool] = _connected_roads(state)
	var grid_power: Dictionary = _power(state)
	var report: Dictionary = {
		"powered": grid_power.powered,
		"capacity": grid_power.capacity,
		"power_used": grid_power.used,
		"road_access": [],
		"pollution": [],
		"crime": [],
		"fire_risk": [],
		"demand": _demand(state),
		"warnings": [],
	}
	var problems: Dictionary = {"停電": 0, "道路未接続": 0, "公害": 0, "犯罪": 0, "火災危険": 0}
	var facilities: Dictionary = {"industrial": [], "park": [], "police": [], "fire": []}
	for index: int in SIZE * SIZE:
		var tile: Dictionary = state.tiles[index]
		if facilities.has(tile.kind) and grid_power.powered[index]:
			facilities[tile.kind].append(index)
	for index: int in SIZE * SIZE:
		var tile: Dictionary = state.tiles[index]
		var access: bool = roads[index]
		for neighbor: int in _neighbors(index):
			access = access or roads[neighbor]
		var pollution: int = int(_influence(state, index, facilities.industrial, 4, 22, true))
		pollution -= int(_influence(state, index, facilities.park, 4, 18))
		if tile.terrain == "forest":
			pollution -= 10
		var crime: int = 20 + int(tile.level) * 14 + int(state.population / 30.0)
		crime -= int(_influence(state, index, facilities.police, 8, 100))
		var risk: int = 20 + mini(int(tile.age), 50) + (25 if tile.kind == "industrial" else 0)
		risk -= int(_influence(state, index, facilities.fire, 8, 100))
		report.road_access.append(access)
		report.pollution.append(clampi(pollution, 0, 100))
		report.crime.append(clampi(crime, 0, 100))
		report.fire_risk.append(clampi(risk, 0, 100))
		if tile.kind in ZONES:
			problems["停電"] += int(not grid_power.powered[index])
			problems["道路未接続"] += int(not access)
			problems["公害"] += int(pollution >= 55 and tile.kind == "residential")
			problems["犯罪"] += int(crime >= 65)
			problems["火災危険"] += int(risk >= 75)
	for problem: String in problems:
		if problems[problem] > 0:
			report.warnings.append("%s %d区画" % [problem, problems[problem]])
	if state.money < 0:
		report.warnings.append("赤字 %d/3月・建設停止" % state.negative_months)
	return report


static func decode_save(data: Variant) -> Dictionary:
	if not data is Dictionary or not _valid_header(data):
		return {}
	if not data.get("tiles") is Array or data.tiles.size() != SIZE * SIZE:
		return {}
	var result: Dictionary = data.duplicate(true)
	for index: int in SIZE * SIZE:
		var tile: Variant = result.tiles[index]
		if not tile is Dictionary or not _valid_tile(tile):
			return {}
		tile.level = int(tile.level)
		tile.age = int(tile.age)
	for key: String in [
		"version",
		"money",
		"population",
		"jobs",
		"month",
		"tax",
		"negative_months",
		"income",
		"expenses"
	]:
		result[key] = int(result[key])
	var counted: Dictionary = result.duplicate(true)
	_update_totals(counted)
	if counted.population != result.population or counted.jobs != result.jobs:
		return {}
	if result.outcome == "clear" and result.population < GOAL_POPULATION:
		return {}
	if result.outcome == "defeat" and (result.negative_months < 3 or result.money >= 0):
		return {}
	if (
		result.outcome == "playing"
		and (result.negative_months >= 3 or result.population >= GOAL_POPULATION)
	):
		return {}
	if (result.money >= 0 and result.negative_months != 0) or result.negative_months > result.month:
		return {}
	result.demand = _demand(result)
	return result


static func _valid_header(data: Dictionary) -> bool:
	var limits: Dictionary = {
		"version": [1, 1],
		"money": [-100000000, 100000000],
		"population": [0, 61440],
		"jobs": [0, 73728],
		"month": [0, 100000],
		"tax": [0, 20],
		"negative_months": [0, 3],
		"income": [0, 1000000],
		"expenses": [0, 1000000],
	}
	for key: String in limits:
		if not _integer_between(data.get(key), limits[key][0], limits[key][1]):
			return false
	if data.get("outcome") not in ["playing", "clear", "defeat"]:
		return false
	if not data.get("demand") is Dictionary:
		return false
	for key: String in ["r", "c", "i"]:
		if not _integer_between(data.demand.get(key), -100, 100):
			return false
	return true


static func _valid_tile(tile: Dictionary) -> bool:
	if tile.get("terrain") not in ["flat", "water", "forest"] or not COSTS.has(tile.get("kind")):
		return false
	if (
		not _integer_between(tile.get("level"), 0, MAX_LEVEL)
		or not _integer_between(tile.get("age"), 0, 100000)
	):
		return false
	if tile.terrain == "water" and tile.kind != "empty":
		return false
	return tile.kind in ZONES or (tile.level == 0 and tile.age == 0)


static func _integer_between(value: Variant, minimum: int, maximum: int) -> bool:
	return (
		(value is int or value is float)
		and is_finite(float(value))
		and float(value) == floor(float(value))
		and value >= minimum
		and value <= maximum
	)


static func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < SIZE and cell.y >= 0 and cell.y < SIZE


static func _neighbors(index: int) -> Array[int]:
	var result: Array[int] = []
	var cell: Vector2i = Vector2i(index % SIZE, int(index / float(SIZE)))
	for direction: Vector2i in DIRECTIONS:
		var next: Vector2i = cell + direction
		if _inside(next):
			result.append(next.y * SIZE + next.x)
	return result


static func _connected_roads(state: Dictionary) -> Array[bool]:
	var connected: Array[bool] = []
	connected.resize(SIZE * SIZE)
	connected.fill(false)
	var queue: Array[int] = []
	for index: int in SIZE * SIZE:
		if state.tiles[index].kind == "power":
			for neighbor: int in _neighbors(index):
				if state.tiles[neighbor].kind == "road" and not connected[neighbor]:
					connected[neighbor] = true
					queue.append(neighbor)
	var cursor: int = 0
	while cursor < queue.size():
		for neighbor: int in _neighbors(queue[cursor]):
			if state.tiles[neighbor].kind == "road" and not connected[neighbor]:
				connected[neighbor] = true
				queue.append(neighbor)
		cursor += 1
	return connected


static func _power(state: Dictionary) -> Dictionary:
	var powered: Array[bool] = []
	powered.resize(SIZE * SIZE)
	powered.fill(false)
	var queue: Array[int] = []
	for index: int in SIZE * SIZE:
		if state.tiles[index].kind == "power":
			powered[index] = true
			queue.append(index)
	var capacity: int = queue.size() * 90
	var used: int = 0
	var cursor: int = 0
	while cursor < queue.size():
		for neighbor: int in _neighbors(queue[cursor]):
			var tile: Dictionary = state.tiles[neighbor]
			if tile.kind == "empty" or powered[neighbor]:
				continue
			var cost: int = 0 if tile.kind == "road" else 1 + int(tile.level)
			if used + cost > capacity:
				continue
			used += cost
			powered[neighbor] = true
			queue.append(neighbor)
		cursor += 1
	return {"powered": powered, "capacity": capacity, "used": used}


static func _influence(
	state: Dictionary, index: int, sources: Array, radius: int, strength: int, scaled: bool = false
) -> float:
	var total: float = 0.0
	var point: Vector2i = Vector2i(index % SIZE, int(index / float(SIZE)))
	for source: int in sources:
		var origin: Vector2i = Vector2i(source % SIZE, int(source / float(SIZE)))
		var distance: int = absi(point.x - origin.x) + absi(point.y - origin.y)
		if distance <= radius:
			var level: int = int(state.tiles[source].level) if scaled else 1
			total += float(strength * level) * (1.0 - float(distance) / float(radius + 1))
	return total


## 内部で作った複製に集計値を書き込む。外部入力の状態は変更しない。
static func _update_totals(state: Dictionary) -> void:
	state.population = 0
	state.jobs = 0
	for tile: Dictionary in state.tiles:
		if tile.kind == "residential":
			state.population += int(tile.level) * 20
		elif tile.kind == "commercial":
			state.jobs += int(tile.level) * 16
		elif tile.kind == "industrial":
			state.jobs += int(tile.level) * 24


static func _expenses(state: Dictionary) -> int:
	var result: int = 0
	for tile: Dictionary in state.tiles:
		result += UPKEEP[tile.kind]
	return result


static func _demand(state: Dictionary) -> Dictionary:
	var commercial: int = 0
	var industrial: int = 0
	for tile: Dictionary in state.tiles:
		if tile.kind == "commercial":
			commercial += int(tile.level) * 16
		elif tile.kind == "industrial":
			industrial += int(tile.level) * 24
	var tax_penalty: int = (int(state.tax) - 9) * 12
	return {
		"r": clampi(int(60 + (state.jobs * 1.8 - state.population) * 0.5) - tax_penalty, -100, 100),
		"c":
		clampi(int(40 + (state.population * 0.35 - commercial) * 0.8) - tax_penalty, -100, 100),
		"i": clampi(int(50 + (state.population * 0.6 - industrial) * 0.5) - tax_penalty, -100, 100),
	}
