extends Node
## 農場・所持品・暦を一元管理する。操作関数はプレイヤーの行動ごとに資源や時刻を進めるため非冪等。

signal changed

const CROPS: Dictionary = {
	"turnip": {"name": "かぶ", "season": "spring", "days": 2, "sell": 60, "seed_price": 15},
	"carrot": {"name": "にんじん", "season": "spring", "days": 3, "sell": 100, "seed_price": 25},
	"tomato": {"name": "トマト", "season": "summer", "days": 2, "sell": 90, "seed_price": 20},
	"corn": {"name": "とうもろこし", "season": "summer", "days": 4, "sell": 180, "seed_price": 40},
}
const TOOLS: Array[String] = ["クワ", "ジョウロ", "種", "収穫"]
const FIELD_COLUMNS: int = 6
const FIELD_ROWS: int = 4
const TARGET_MONEY: int = 900
const DAYS_PER_SEASON: int = 10
const LAST_DAY: int = DAYS_PER_SEASON * 2
const MAX_STAMINA: int = 100
const FOOD_PRICE: int = 35
const FOOD_RECOVERY: int = 30
const SAVE_PATH: String = "user://farm-save.json"
const SPAWN_POSITION: Vector2 = Vector2(416, 272)
const WORLD_BOUNDS: Rect2 = Rect2(64, 200, 864, 360)
const OBSTACLES: Array[Rect2] = [
	Rect2(80, 172, 190, 110), Rect2(270, 208, 64, 50),
	Rect2(802, 155, 138, 75), Rect2(835, 363, 65, 48),
	Rect2(80, 430, 72, 94), Rect2(200, 461, 78, 68),
]
const SAVE_VERSION: int = 1
const COUNT_LIMIT: int = 1000000

var day: int = 1
var minutes: float = 360.0
var stamina: int = MAX_STAMINA
var money: int = 120
var food: int = 3
var selected_tool: int = 0
var selected_crop: String = "turnip"
var player_position: Vector2 = SPAWN_POSITION
var facing: Vector2 = Vector2.DOWN
var tiles: Array[Dictionary] = []
var seeds: Dictionary = {}
var harvested: Dictionary = {}
var shipping: Dictionary = {}
var shipped: Dictionary = {}
var earned: int = 0
var phase: String = "playing"


func _init() -> void:
	reset()


func reset() -> void:
	day = 1
	minutes = 360.0
	stamina = MAX_STAMINA
	money = 120
	food = 3
	selected_tool = 0
	selected_crop = "turnip"
	player_position = SPAWN_POSITION
	facing = Vector2.DOWN
	earned = 0
	phase = "playing"
	tiles.clear()
	for index: int in range(FIELD_COLUMNS * FIELD_ROWS):
		tiles.append(_empty_tile())
	seeds = _empty_counts()
	seeds["turnip"] = 8
	seeds["carrot"] = 4
	harvested = _empty_counts()
	shipping = _empty_counts()
	shipped = _empty_counts()
	changed.emit()


func season() -> String:
	return "spring" if day <= DAYS_PER_SEASON else "summer"


func season_name() -> String:
	return "春" if season() == "spring" else "夏"


func clock_text() -> String:
	var clock_minutes: int = int(minutes)
	return "%02d:%02d" % [(clock_minutes / 60) as int % 24, clock_minutes % 60]


func can_walk(at: Vector2) -> bool:
	if not WORLD_BOUNDS.has_point(at):
		return false
	if at.x < 155 and at.y > 444:
		return false
	for obstacle: Rect2 in OBSTACLES:
		if obstacle.has_point(at):
			return false
	return true


func crop_stage(index: int) -> int:
	if index < 0 or index >= tiles.size() or tiles[index].crop == "":
		return -1
	var tile: Dictionary = tiles[index]
	if tile.withered:
		return 4
	if tile.growth >= CROPS[tile.crop].days:
		return 3
	if tile.growth > 0:
		return 2
	return 1 if tile.watered else 0


func use_tool(index: int) -> Dictionary:
	if phase != "playing":
		return _result(false, "notice", "農場の記録を振り返りましょう")
	if index < 0 or index >= tiles.size():
		return _result(false, "notice", "畑のマスを向いて道具を使いましょう")
	var tile: Dictionary = tiles[index]
	var result: Dictionary
	match selected_tool:
		0:
			result = _hoe(tile)
		1:
			result = _water(tile)
		2:
			result = _plant(tile)
		3:
			result = _harvest(tile)
		_:
			return _result(false, "notice", "道具を選んでください")
	if result.ok:
		_spend_stamina([4, 3, 2, 3][selected_tool], result)
	return result


func eat() -> Dictionary:
	if phase != "playing" or food <= 0:
		return _result(false, "notice", "お弁当は町の商店で買えます")
	if stamina == MAX_STAMINA:
		return _result(false, "notice", "体力は満タンです")
	food -= 1
	var recovery: int = mini(FOOD_RECOVERY, MAX_STAMINA - stamina)
	stamina += recovery
	changed.emit()
	return _result(true, "eat", "お弁当で体力が %d 回復しました" % recovery, recovery)


func buy_seed(crop: String) -> Dictionary:
	if phase != "playing" or not CROPS.has(crop):
		return _result(false, "notice", "購入できない種です")
	if CROPS[crop].season != season():
		return _result(false, "notice", "この種は %s の入荷です" % (
			"春" if CROPS[crop].season == "spring" else "夏"))
	if money < CROPS[crop].seed_price:
		return _result(false, "notice", "所持金が足りません")
	money -= int(CROPS[crop].seed_price)
	seeds[crop] += 1
	changed.emit()
	return _result(true, "buy", "%sの種を買いました" % CROPS[crop].name)


func buy_food() -> Dictionary:
	if phase != "playing" or money < FOOD_PRICE:
		return _result(false, "notice", "お弁当には %d G 必要です" % FOOD_PRICE)
	money -= FOOD_PRICE
	food += 1
	changed.emit()
	return _result(true, "buy", "お弁当を買いました")


func ship_all() -> Dictionary:
	if phase != "playing":
		return _result(false, "notice", "今季の出荷は終了しました")
	var value: int = 0
	for crop: String in CROPS:
		value += int(harvested[crop]) * int(CROPS[crop].sell)
		shipping[crop] += harvested[crop]
		harvested[crop] = 0
	if value == 0:
		return _result(false, "notice", "収穫した作物を持ってきてください")
	changed.emit()
	return _result(true, "ship", "出荷箱に入れました。翌朝 +%d G" % value, value)


func advance_day(forced: bool = false) -> Dictionary:
	if phase != "playing":
		return _result(false, "notice", "今季の農場は終了しました")
	var penalty: int = ceili(float(money) * 0.1) if forced else 0
	money -= penalty
	var income: int = _settle_shipping()
	if _goal_met():
		phase = "win"
	elif day == LAST_DAY:
		phase = "loss"
	else:
		day += 1
		_grow_and_dry()
	minutes = 360.0
	stamina = MAX_STAMINA
	player_position = SPAWN_POSITION
	facing = Vector2.DOWN
	changed.emit()
	var message: String = "%s %d 日目。出荷売上 +%d G" % [
		season_name(), (day - 1) % DAYS_PER_SEASON + 1, income]
	if forced:
		message = "休息が必要でした（-%d G）。%s" % [penalty, message]
	if phase == "win":
		message = "目標達成！ あなたの農場が実りました"
	elif phase == "loss":
		message = "20 日間の農場生活が終わりました"
	var result: Dictionary = _result(true, "day", message, income)
	result.advanced_day = true
	return result


func tick(delta: float) -> Dictionary:
	if phase != "playing" or not is_finite(delta) or delta <= 0.0:
		return {}
	minutes += delta * 5.0
	if minutes >= 1560.0:
		return advance_day(true)
	return {}


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION, "day": day, "minutes": minutes, "stamina": stamina,
		"money": money, "food": food, "selected_tool": selected_tool,
		"selected_crop": selected_crop, "position": [player_position.x, player_position.y],
		"facing": [facing.x, facing.y], "tiles": tiles.duplicate(true),
		"seeds": seeds.duplicate(), "harvested": harvested.duplicate(),
		"shipping": shipping.duplicate(), "shipped": shipped.duplicate(),
		"earned": earned, "phase": phase,
	}


func from_dict(value: Variant) -> bool:
	if not _valid_save(value):
		return false
	day = int(value.day)
	minutes = float(value.minutes)
	stamina = int(value.stamina)
	money = int(value.money)
	food = int(value.food)
	selected_tool = int(value.selected_tool)
	selected_crop = str(value.selected_crop)
	player_position = Vector2(float(value.position[0]), float(value.position[1]))
	facing = Vector2(float(value.facing[0]), float(value.facing[1]))
	tiles.clear()
	for tile: Dictionary in value.tiles:
		var restored: Dictionary = tile.duplicate()
		restored.growth = int(restored.growth)
		tiles.append(restored)
	seeds = _restore_counts(value.seeds)
	harvested = _restore_counts(value.harvested)
	shipping = _restore_counts(value.shipping)
	shipped = _restore_counts(value.shipped)
	earned = int(value.earned)
	phase = str(value.phase)
	changed.emit()
	return true


func save_game(path: String = SAVE_PATH) -> bool:
	var data: Dictionary = to_dict()
	if not _valid_save(data):
		return false
	var temporary: String = path + ".pending"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		return false
	return DirAccess.rename_absolute(temporary, path) == OK


func load_game(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 1048576:
		return false
	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(file.get_as_text())
	file.close()
	return parse_error == OK and from_dict(parser.data)


func _hoe(tile: Dictionary) -> Dictionary:
	if tile.withered:
		tile.merge(_empty_tile(), true)
	if tile.crop != "":
		return _result(false, "notice", "ここでは作物が育っています")
	if tile.tilled:
		return _result(false, "notice", "ここは耕してあります。種を植えましょう")
	tile.tilled = true
	return _result(true, "hoe", "ふかふかの土になりました")


func _water(tile: Dictionary) -> Dictionary:
	if not tile.tilled or tile.withered:
		return _result(false, "notice", "耕した畑に水をあげましょう")
	if tile.watered:
		return _result(false, "notice", "今日はもう水をあげました")
	tile.watered = true
	return _result(true, "water", "水やり完了。作物は明日の朝に成長します")


func _plant(tile: Dictionary) -> Dictionary:
	if not tile.tilled or tile.crop != "":
		return _result(false, "notice", "空いている耕したマスに植えましょう")
	if not CROPS.has(selected_crop) or CROPS[selected_crop].season != season():
		return _result(false, "notice", "今の季節に合う種を選びましょう")
	if seeds[selected_crop] <= 0:
		return _result(false, "notice", "種がありません。町の商店で買えます")
	seeds[selected_crop] -= 1
	tile.crop = selected_crop
	tile.growth = 0
	tile.withered = false
	return _result(true, "plant", "%sの種を植えました" % CROPS[selected_crop].name)


func _harvest(tile: Dictionary) -> Dictionary:
	if tile.withered:
		return _result(false, "notice", "枯れた作物はクワで片づけられます")
	if tile.crop == "" or tile.growth < CROPS[tile.crop].days:
		return _result(false, "notice", "実った作物を収穫しましょう")
	var crop: String = tile.crop
	harvested[crop] += 1
	tile.crop = ""
	tile.growth = 0
	return _result(true, "harvest", "%sを収穫しました！ 出荷箱へ運びましょう" % CROPS[crop].name)


func _spend_stamina(cost: int, result: Dictionary) -> void:
	stamina = maxi(0, stamina - cost)
	if stamina == 0:
		var morning: Dictionary = advance_day(true)
		result.text = morning.text
		result.advanced_day = true
	else:
		changed.emit()


func _settle_shipping() -> int:
	var income: int = 0
	for crop: String in CROPS:
		income += int(shipping[crop]) * int(CROPS[crop].sell)
		shipped[crop] += shipping[crop]
		shipping[crop] = 0
	money += income
	earned += income
	return income


func _grow_and_dry() -> void:
	for tile: Dictionary in tiles:
		if tile.crop != "":
			if CROPS[tile.crop].season != season():
				tile.withered = true
			elif tile.watered and not tile.withered:
				tile.growth = mini(int(CROPS[tile.crop].days), int(tile.growth) + 1)
		tile.watered = false


func _goal_met() -> bool:
	if money >= TARGET_MONEY:
		return true
	for crop: String in CROPS:
		if shipped[crop] == 0:
			return false
	return true


func _empty_counts() -> Dictionary:
	var counts: Dictionary = {}
	for crop: String in CROPS:
		counts[crop] = 0
	return counts


func _empty_tile() -> Dictionary:
	return {"tilled": false, "watered": false, "crop": "", "growth": 0, "withered": false}


func _result(ok: bool, kind: String, text: String, amount: int = 0) -> Dictionary:
	return {"ok": ok, "kind": kind, "text": text, "amount": amount, "advanced_day": false}


func _valid_save(value: Variant) -> bool:
	if not value is Dictionary or not _has_save_fields(value):
		return false
	if not _valid_save_numbers(value) or not _valid_save_position(value):
		return false
	if (
		not value.selected_crop is String or not CROPS.has(value.selected_crop)
		or not value.phase is String or value.phase not in ["playing", "win", "loss"]
		or not value.tiles is Array or value.tiles.size() != FIELD_COLUMNS * FIELD_ROWS
	):
		return false
	for field: String in ["seeds", "harvested", "shipping", "shipped"]:
		if not _valid_counts(value[field]):
			return false
	for tile: Variant in value.tiles:
		if not _valid_tile(tile, int(value.day)):
			return false
	return _valid_save_outcome(value)


func _has_save_fields(value: Dictionary) -> bool:
	var fields: Array[String] = [
		"version", "day", "minutes", "stamina", "money", "food", "selected_tool", "selected_crop",
		"position", "facing", "tiles", "seeds", "harvested", "shipping", "shipped", "earned", "phase",
	]
	return value.size() == fields.size() and value.has_all(fields)


func _valid_save_numbers(value: Dictionary) -> bool:
	return (
		_whole_number(value.version, SAVE_VERSION, SAVE_VERSION)
		and _whole_number(value.day, 1, LAST_DAY)
		and _number(value.minutes, 360.0, 1559.999999)
		and _whole_number(value.stamina, 1, MAX_STAMINA)
		and _whole_number(value.money, 0, COUNT_LIMIT)
		and _whole_number(value.food, 0, COUNT_LIMIT)
		and _whole_number(value.selected_tool, 0, TOOLS.size() - 1)
		and _whole_number(value.earned, 0, COUNT_LIMIT * 180)
	)


func _valid_save_position(value: Dictionary) -> bool:
	if not value.position is Array or value.position.size() != 2:
		return false
	if (
		not _number(value.position[0], WORLD_BOUNDS.position.x, WORLD_BOUNDS.end.x)
		or not _number(value.position[1], WORLD_BOUNDS.position.y, WORLD_BOUNDS.end.y)
	):
		return false
	if not can_walk(Vector2(float(value.position[0]), float(value.position[1]))):
		return false
	if not value.facing is Array or value.facing.size() != 2:
		return false
	if not _number(value.facing[0], -1.0, 1.0) or not _number(value.facing[1], -1.0, 1.0):
		return false
	var direction: Vector2 = Vector2(float(value.facing[0]), float(value.facing[1]))
	return is_equal_approx(direction.length_squared(), 1.0)


func _valid_counts(value: Variant) -> bool:
	if not value is Dictionary or value.size() != CROPS.size() or not value.has_all(CROPS.keys()):
		return false
	for crop: String in CROPS:
		if not _whole_number(value[crop], 0, COUNT_LIMIT):
			return false
	return true


func _valid_tile(value: Variant, saved_day: int) -> bool:
	if not _valid_tile_fields(value):
		return false
	if not value.crop is String or (value.crop != "" and not CROPS.has(value.crop)):
		return false
	if not _whole_number(value.growth, 0, 4):
		return false
	if (value.watered or value.crop != "") and not value.tilled:
		return false
	if value.crop == "":
		return value.growth == 0 and not value.withered
	var crop: Dictionary = CROPS[value.crop]
	var saved_season: String = "spring" if saved_day <= DAYS_PER_SEASON else "summer"
	return value.growth <= crop.days and value.withered == (crop.season != saved_season)


func _valid_tile_fields(value: Variant) -> bool:
	return (
		value is Dictionary and value.size() == 5
		and value.has_all(["tilled", "watered", "crop", "growth", "withered"])
		and value.tilled is bool and value.watered is bool and value.withered is bool
	)


func _valid_save_outcome(value: Dictionary) -> bool:
	var complete_collection: bool = true
	for crop: String in CROPS:
		complete_collection = complete_collection and value.shipped[crop] > 0
	var reached: bool = value.money >= TARGET_MONEY or complete_collection
	if value.phase == "win":
		return reached
	if value.phase == "loss":
		return int(value.day) == LAST_DAY and not reached
	return not reached


func _restore_counts(value: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	for crop: String in CROPS:
		counts[crop] = int(value[crop])
	return counts


func _number(value: Variant, low: float, high: float) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and float(value) >= low and float(value) <= high


func _whole_number(value: Variant, low: int, high: int) -> bool:
	return _number(value, low, high) and float(value) == floorf(float(value))
