# gdlint: disable=max-public-methods
# 状態の正本を分散させず進行・所持品・保存の公開操作を集約する。
extends Node
## 進行・所持品・保存の正本。操作系メソッドは資源を消費するため非冪等。

signal changed
signal world_changed
signal event(kind: String, text: String)

const Data := preload("res://scripts/voxel_data.gd")
const SAVE_VERSION := 2
const DAY_SECONDS := 180.0
const INITIAL_DAY_TIME := 0.18
const RECIPES: Array[Dictionary] = [
	{"id": "plank", "name": "木の板", "costs": {"wood": 1}, "output": "plank", "count": 4},
	{"id": "bench", "name": "作業台", "costs": {"plank": 4}, "output": "bench", "count": 1},
	{"id": "wood_pick", "name": "木のつるはし", "costs": {"plank": 3, "wood": 2},
		"output": "wood_pick", "count": 1, "bench": true},
	{"id": "stone_pick", "name": "石のつるはし", "costs": {"stone": 3, "wood": 2},
		"output": "stone_pick", "count": 1, "bench": true, "level": 1},
	{"id": "torch", "name": "たいまつ", "costs": {"wood": 1, "leaf": 1},
		"output": "torch", "count": 4},
	{"id": "stew", "name": "野営シチュー", "costs": {"meat": 1, "apple": 1},
		"output": "stew", "count": 1, "bench": true},
	{"id": "bandage", "name": "葉の包帯", "costs": {"leaf": 3}, "output": "bandage", "count": 1},
	{"id": "timber", "name": "板を束ねた木材", "costs": {"plank": 6}, "output": "wood", "count": 1}
]
const ITEM_NAMES := {
	"dirt": "土", "wood": "木材", "plank": "木の板", "stone": "石", "torch": "たいまつ",
	"apple": "島リンゴ", "bench": "作業台", "sand": "砂", "leaf": "葉", "ore": "鉱石",
	"wood_pick": "木のつるはし", "stone_pick": "石のつるはし", "meat": "肉",
	"stew": "野営シチュー", "bandage": "葉の包帯"
}
const DEFAULT_HOTBAR: Array[String] = [
	"dirt", "wood", "plank", "stone", "torch", "apple", "bench", "sand", "leaf"
]
const PLACE_IDS := {
	"dirt": Data.DIRT, "wood": Data.WOOD, "plank": Data.PLANK, "stone": Data.STONE,
	"torch": Data.TORCH, "bench": Data.BENCH, "sand": Data.SAND, "leaf": Data.LEAVES
}

var phase: String = "title"
var data: RefCounted = Data.new()
var inventory: Dictionary = {}
var hotbar: Array[String] = DEFAULT_HOTBAR.duplicate()
var selected: int = 0
var hp: float = 100.0
var hunger: float = 100.0
var day_time: float = INITIAL_DAY_TIME
var day: int = 1
var tool_level: int = 0
var house_built: bool = false
var player_position: Vector3 = Vector3.ZERO
var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var _hunger_clock: float = 0.0


func new_game(world_seed: int = 46073) -> void:
	enemies.clear()
	projectiles.clear()
	data.generate(world_seed)
	inventory = {"apple": 6}
	selected = 0
	hotbar.assign(DEFAULT_HOTBAR)
	hp = 100.0
	hunger = 100.0
	day_time = INITIAL_DAY_TIME
	day = 1
	tool_level = 0
	house_built = false
	_hunger_clock = 0.0
	player_position = data.spawn
	phase = "play"
	world_changed.emit()
	changed.emit()


# 実時間を進めるため非冪等。大きい delta も日境界を取りこぼさない。
func step(delta: float) -> void:
	if phase != "play" or delta <= 0 or not is_finite(delta):
		return
	day_time += delta / DAY_SECONDS
	while day_time >= 1.0:
		day_time -= 1.0
		day += 1
	_hunger_clock += delta
	while _hunger_clock >= 1.0:
		_hunger_clock -= 1.0
		hunger = maxf(0, hunger - 0.20)
		if hunger <= 0:
			damage(1.0)
		if phase != "play":
			break
	_update_goal()
	changed.emit()


func is_night() -> bool:
	return day_time >= 0.68 or day_time < 0.16


func selected_item() -> String:
	return hotbar[clampi(selected, 0, hotbar.size() - 1)]


func item_name(item: String) -> String:
	return str(ITEM_NAMES.get(item, item))


func recipe_available(recipe: Dictionary) -> bool:
	return recipe_reason(recipe).is_empty()


func recipe_reason(recipe: Dictionary) -> String:
	if phase != "play":
		return "遠征中だけ折れます"
	if tool_level < int(recipe.get("level", 0)):
		return "先に木のつるはしを折ります"
	if bool(recipe.get("bench", false)) and not _has_bench():
		return "作業台を持つか、島に置きます"
	var missing: Array[String] = []
	for item: String in recipe.costs:
		var shortage: int = int(recipe.costs[item]) - int(inventory.get(item, 0))
		if shortage > 0:
			missing.append("%sが%d足りません" % [item_name(item), shortage])
	return "、".join(missing)


func _has_bench() -> bool:
	if int(inventory.get("bench", 0)) > 0:
		return true
	return Data.BENCH in data.blocks.values()


func craft(recipe_id: String) -> bool:
	for recipe: Dictionary in RECIPES:
		if recipe.id != recipe_id:
			continue
		if not recipe_available(recipe):
			return false
		for item: String in recipe.costs:
			inventory[item] = int(inventory.get(item, 0)) - int(recipe.costs[item])
		add_item(recipe.output, int(recipe.count))
		if recipe.output == "wood_pick":
			tool_level = maxi(tool_level, 1)
		elif recipe.output == "stone_pick":
			tool_level = 2
		event.emit("craft", recipe.name + " が完成！")
		_update_goal()
		changed.emit()
		return true
	return false


func can_mine(cell: Vector3i) -> bool:
	var id: int = data.get_block(cell)
	return phase == "play" and cell.y > 0 and id not in [Data.AIR, Data.WATER] \
		and (id != Data.STONE or tool_level >= 1) and (id != Data.ORE or tool_level >= 2)


func mine(cell: Vector3i) -> bool:
	if not can_mine(cell):
		return false
	var id: int = data.get_block(cell)
	data.set_block(cell, Data.AIR)
	add_item(str(Data.ITEMS[id]), 1)
	if id == Data.LEAVES and posmod(cell.x + cell.y + cell.z, 3) == 0:
		add_item("apple", 1)
	house_built = check_house()
	world_changed.emit()
	changed.emit()
	return true


func place(cell: Vector3i, player_aabb: AABB) -> bool:
	if not placement_reason(cell, player_aabb).is_empty():
		return false
	var item: String = selected_item()
	inventory[item] = int(inventory[item]) - 1
	data.set_block(cell, int(PLACE_IDS[item]))
	house_built = check_house()
	_update_goal()
	world_changed.emit()
	changed.emit()
	return true


func placement_reason(cell: Vector3i, player_aabb: AABB) -> String:
	var item: String = selected_item()
	var reason: String = ""
	if phase != "play":
		reason = "遠征中だけ置けます"
	elif not PLACE_IDS.has(item):
		reason = "%sは置けません" % item_name(item)
	elif int(inventory.get(item, 0)) <= 0:
		reason = "%sを持っていません" % item_name(item)
	elif not data.in_bounds(cell):
		reason = "島の外には置けません"
	elif data.get_block(cell) not in [Data.AIR, Data.WATER]:
		reason = "すでに紙ブロックがあります"
	elif player_aabb.intersects(AABB(Vector3(cell), Vector3.ONE)):
		reason = "自分と重なる場所には置けません"
	return reason


func add_item(item: String, amount: int) -> void:
	if not ITEM_NAMES.has(item) or amount <= 0:
		return
	inventory[item] = int(inventory.get(item, 0)) + amount
	changed.emit()


func assign_slot(item: String) -> bool:
	if phase != "play" or selected < 0 or selected >= hotbar.size() \
		or not ITEM_NAMES.has(item) or int(inventory.get(item, 0)) <= 0:
		return false
	hotbar[selected] = item
	changed.emit()
	return true


func eat() -> bool:
	if phase != "play":
		return false
	if selected_item() in ["bandage", "leaf"] and hp < 100 and int(inventory.get("bandage", 0)) > 0:
		inventory.bandage = int(inventory.bandage) - 1
		hp = minf(100, hp + 30)
		event.emit("eat", "葉の包帯で体力を回復")
		changed.emit()
		return true
	if hunger >= 100:
		return false
	var foods: Array[String] = ["stew", "apple", "meat"]
	if selected_item() in foods:
		foods.erase(selected_item())
		foods.push_front(selected_item())
	for food: String in foods:
		if int(inventory.get(food, 0)) <= 0:
			continue
		inventory[food] = int(inventory[food]) - 1
		hunger = minf(100, hunger + (65.0 if food == "stew" else 26.0))
		hp = minf(100, hp + 5)
		event.emit("eat", item_name(food) + " を食べた")
		changed.emit()
		return true
	return false


func damage(amount: float) -> void:
	if phase != "play" or amount <= 0 or not is_finite(amount):
		return
	hp = maxf(0, hp - amount)
	if hp <= 0:
		phase = "failed"
	changed.emit()


func respawn() -> void:
	if phase != "failed":
		return
	var point: Vector3 = _safe_position(data, data.spawn)
	if not point.is_finite():
		return
	enemies.clear()
	projectiles.clear()
	inventory.clear()
	hotbar.assign(DEFAULT_HOTBAR)
	selected = 0
	tool_level = 0
	hp = 100
	hunger = 80
	player_position = point
	phase = "play"
	changed.emit()


func check_house() -> bool:
	for roof: Vector3i in data.blocks:
		if data.get_block(roof) != Data.PLANK or roof.y < 3:
			continue
		if _room_enclosed(roof - Vector3i(0, 2, 0)):
			return true
	return false


func _room_enclosed(interior: Vector3i) -> bool:
	if data.is_solid(interior) or data.is_solid(interior + Vector3i.UP):
		return false
	if not data.is_solid(interior + Vector3i.DOWN):
		return false
	var entrances: int = 0
	for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
		var lower: bool = data.is_solid(interior + direction)
		var upper: bool = data.is_solid(interior + direction + Vector3i.UP)
		if lower and upper:
			continue
		# 一箇所の出入口だけを許可し、柱とまぐさのある二段分の開口を検査する。
		var side := Vector3i(-direction.z, 0, direction.x)
		if lower or upper or not data.is_solid(interior + direction + Vector3i(0, 2, 0)):
			return false
		for offset: Vector3i in [side, -side]:
			if not data.is_solid(interior + direction + offset) \
				or not data.is_solid(interior + direction + offset + Vector3i.UP):
				return false
		entrances += 1
	return entrances <= 1


func survived_three_days() -> bool:
	return day > 4 or (day == 4 and day_time >= INITIAL_DAY_TIME)


func _update_goal() -> void:
	if phase == "play" and survived_three_days() and tool_level >= 2 and house_built:
		phase = "clear"


func serialize() -> Dictionary:
	return {"version": SAVE_VERSION, "world": data.serialize(), "inventory": inventory.duplicate(),
		"hp": hp, "hunger": hunger, "day_time": day_time, "day": day, "tool_level": tool_level,
		"position": [player_position.x, player_position.y, player_position.z], "selected": selected,
		"hotbar": hotbar.duplicate()}


func deserialize(value: Variant) -> bool:
	if not _valid_save(value):
		return false
	var restored: RefCounted = Data.new()
	if not restored.deserialize(value.world):
		return false
	var point := Vector3(value.position[0], value.position[1], value.position[2])
	if not _body_clear(restored, point):
		point = _safe_position(restored, restored.spawn)
	if not point.is_finite():
		return false
	enemies.clear()
	projectiles.clear()
	data = restored
	inventory = {}
	for item: String in value.inventory:
		inventory[item] = int(value.inventory[item])
	hp = float(value.hp)
	hunger = float(value.hunger)
	day_time = float(value.day_time)
	day = int(value.day)
	tool_level = int(value.tool_level)
	selected = int(value.selected)
	hotbar.assign(value.hotbar)
	player_position = point
	_hunger_clock = 0
	house_built = check_house()
	phase = "play" if hp > 0 else "failed"
	_update_goal()
	world_changed.emit()
	changed.emit()
	return true


func _valid_save(value: Variant) -> bool:
	if not value is Dictionary or not value.has_all(["version", "world", "inventory", "hp",
		"hunger", "day_time", "day", "tool_level", "position", "selected", "hotbar"]):
		return false
	if not _number_in(value.version, SAVE_VERSION, SAVE_VERSION, true):
		return false
	if not _valid_inventory(value.inventory) or not _valid_hotbar(value.hotbar):
		return false
	if not _number_in(value.hp, 0, 100) or not _number_in(value.hunger, 0, 100) \
		or not _number_in(value.day_time, 0, 0.999999999) \
		or not _number_in(value.day, 1, 999999, true) \
		or not _number_in(value.tool_level, 0, 2, true) \
		or not _number_in(value.selected, 0, 8, true):
		return false
	if not value.position is Array or value.position.size() != 3:
		return false
	return _number_in(value.position[0], -4, 36) and _number_in(value.position[1], -10, 40) \
		and _number_in(value.position[2], -4, 36)


func _valid_hotbar(value: Variant) -> bool:
	if not value is Array or value.size() != 9:
		return false
	for item: Variant in value:
		if not item is String or not ITEM_NAMES.has(item):
			return false
	return true


func _valid_inventory(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for item: Variant in value:
		if not item is String or not ITEM_NAMES.has(item) \
			or not _number_in(value[item], 0, 999999, true):
			return false
	return true


func _number_in(value: Variant, low: float, high: float, integer: bool = false) -> bool:
	if not value is int and not value is float:
		return false
	return is_finite(float(value)) and float(value) >= low and float(value) <= high \
		and (not integer or float(value) == floorf(float(value)))


func save_game(path: String = "user://island-save.json") -> bool:
	if data.blocks.is_empty():
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(serialize()))
	return file.get_error() == OK


func load_game(path: String = "user://island-save.json") -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return false
	return deserialize(parser.data)


static func _body_clear(world: RefCounted, point: Vector3) -> bool:
	var minimum := Vector3i((point - Vector3(0.3, 0, 0.3)).floor())
	var maximum := Vector3i((point + Vector3(0.3, 1.8, 0.3) - Vector3.ONE * 0.001).floor())
	for x: int in range(minimum.x, maximum.x + 1):
		for y: int in range(minimum.y, maximum.y + 1):
			for z: int in range(minimum.z, maximum.z + 1):
				if world.is_solid(Vector3i(x, y, z)):
					return false
	return true


static func _safe_position(world: RefCounted, preferred: Vector3) -> Vector3:
	if _body_clear(world, preferred) \
		and world.is_solid(Vector3i((preferred - Vector3(0, 0.05, 0)).floor())):
		return preferred
	var best := Vector3(INF, INF, INF)
	var best_distance: float = INF
	for cell: Vector3i in world.blocks:
		if not world.is_solid(cell):
			continue
		var point := Vector3(cell) + Vector3(0.5, 1.02, 0.5)
		var distance: float = point.distance_squared_to(preferred)
		if distance < best_distance and _body_clear(world, point):
			best = point
			best_distance = distance
	return best
