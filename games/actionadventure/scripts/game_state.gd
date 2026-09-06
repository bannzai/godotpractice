extends Node
## 探索の進行を保持する。消費型操作は、入力イベントごとの効果を表すため冪等でない。

const SAVE_PATH: String = "user://adventure.json"
const MODES: Array[String] = ["title", "play", "gameover", "ending", "menu", "dialogue"]
const REWARDS: Array[String] = ["boomerang", "bombs", "key", "heart", "coins", "treasure"]
const INTEGER_LIMITS: Dictionary = {
	"room": [0, 11], "checkpoint": [0, 11], "hp": [0, 24], "max_hp": [3, 24],
	"coins": [0, 9999], "keys": [0, 99], "bombs": [0, 99], "potions": [0, 99],
}

var mode: String = "title"
var room: int = 0
var checkpoint: int = 0
var hp: int = 3
var max_hp: int = 3
var coins: int = 0
var keys: int = 0
var bombs: int = 0
var potions: int = 0
var tool: String = "none"
var boomerang_owned: bool = false
var bombs_owned: bool = false
var flags: Dictionary = {}
var opened: Dictionary = {}
var unlocked: Dictionary = {}


func new_game() -> void:
	mode = "play"
	room = 0
	checkpoint = 0
	hp = 3
	max_hp = 3
	coins = 0
	keys = 0
	bombs = 0
	potions = 0
	tool = "none"
	boomerang_owned = false
	bombs_owned = false
	flags.clear()
	opened.clear()
	unlocked.clear()


func snapshot() -> Dictionary:
	return {
		"schema": 1, "mode": mode, "room": room, "checkpoint": checkpoint,
		"hp": hp, "max_hp": max_hp, "coins": coins, "keys": keys,
		"bombs": bombs, "potions": potions, "tool": tool,
		"boomerang_owned": boomerang_owned, "bombs_owned": bombs_owned,
		"flags": flags.duplicate(true), "opened": opened.duplicate(true),
		"unlocked": unlocked.duplicate(true),
	}


func restore(data: Variant) -> bool:
	if not _valid_snapshot(data):
		return false
	mode = data.mode
	for key: String in INTEGER_LIMITS:
		set(key, int(data[key]))
	tool = data.tool
	boomerang_owned = data.boomerang_owned
	bombs_owned = data.bombs_owned
	flags = data.flags.duplicate(true)
	opened = data.opened.duplicate(true)
	unlocked = data.unlocked.duplicate(true)
	return true


func save_game(path: String = SAVE_PATH) -> bool:
	var data: Dictionary = snapshot()
	data.mode = "ending" if mode == "ending" else "play"
	if not _valid_snapshot(data) or hp <= 0:
		return false
	var file: FileAccess = FileAccess.open(path + ".pending", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var succeeded: bool = file.get_error() == OK
	file.close()
	if not succeeded:
		return false
	return DirAccess.rename_absolute(path + ".pending", path) == OK


func load_game(path: String = SAVE_PATH) -> bool:
	return restore(_read_save(path))


func has_save() -> bool:
	return _valid_snapshot(_read_save(SAVE_PATH))


func damage(amount: int) -> bool:
	if amount > 0 and mode == "play":
		hp = maxi(0, hp - amount)
		if hp == 0:
			mode = "gameover"
	return hp == 0


func heal(amount: int) -> void:
	if amount > 0:
		hp = mini(max_hp, hp + amount)


func spend(price: int) -> bool:
	if price < 0 or coins < price:
		return false
	coins -= price
	return true


func open_chest(id: String, reward: String) -> bool:
	if id.is_empty() or opened.has(id) or reward not in REWARDS:
		return false
	opened[id] = true
	match reward:
		"boomerang":
			boomerang_owned = true
			tool = "boomerang"
		"bombs":
			bombs_owned = true
			bombs = mini(99, bombs + 5)
			tool = "bomb"
		"key":
			keys = mini(99, keys + 1)
		"heart":
			max_hp = mini(24, max_hp + 1)
			hp = max_hp
		"coins":
			coins = mini(9999, coins + 12)
		"treasure":
			set_flag("treasure")
			mode = "ending"
	return true


func unlock_door(id: String) -> bool:
	if id.is_empty():
		return false
	if unlocked.has(id):
		return true
	if keys <= 0:
		return false
	keys -= 1
	unlocked[id] = true
	return true


func set_flag(id: String) -> void:
	if not id.is_empty():
		flags[id] = true


func has_flag(id: String) -> bool:
	return flags.has(id)


func retry() -> void:
	room = checkpoint
	hp = max_hp
	mode = "play"


func _read_save(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 262144:
		return null
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return null
	return parser.data


func _valid_snapshot(data: Variant) -> bool:
	if not data is Dictionary or data.size() != 16:
		return false
	if not data.has("schema") or not _integer_in_range(data.schema, 1, 1):
		return false
	if not _valid_numbers(data) or not _valid_equipment(data):
		return false
	if not data.has("mode") or not data.mode is String or data.mode not in MODES:
		return false
	for key: String in ["flags", "opened", "unlocked"]:
		if not data.has(key) or not _valid_flags(data[key]):
			return false
	return true


func _valid_numbers(data: Dictionary) -> bool:
	for key: String in INTEGER_LIMITS:
		if not data.has(key):
			return false
		if not _integer_in_range(data[key], INTEGER_LIMITS[key][0], INTEGER_LIMITS[key][1]):
			return false
	return data.hp <= data.max_hp


func _valid_equipment(data: Dictionary) -> bool:
	if not data.has("tool") or not data.tool is String:
		return false
	if data.tool not in ["none", "boomerang", "bomb"]:
		return false
	for key: String in ["boomerang_owned", "bombs_owned"]:
		if not data.has(key) or not data[key] is bool:
			return false
	if data.tool == "boomerang" and not data.boomerang_owned:
		return false
	if (data.tool == "bomb" or data.bombs > 0) and not data.bombs_owned:
		return false
	return true


func _integer_in_range(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and value == floor(value) and value >= minimum and value <= maximum


func _valid_flags(value: Variant) -> bool:
	if not value is Dictionary or value.size() > 256:
		return false
	for key: Variant in value:
		if not key is String or key.is_empty() or key.length() > 100:
			return false
		if not value[key] is bool or not value[key]:
			return false
	return true
