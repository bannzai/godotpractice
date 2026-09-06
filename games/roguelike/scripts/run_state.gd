extends Node
## コマンドは一手の消費・乱数進行を伴うため非冪等。照会と同一seedでの開始は冪等。

signal changed
signal event(kind: String, cell: Vector2i, value: int)
signal finished

const Data = preload("res://scripts/game_data.gd")
const Dungeon = preload("res://scripts/dungeon.gd")
const SAVE_PATH: String = "user://roguelike_record.json"

var dungeon: RogueDungeon = Dungeon.new()
var player_pos: Vector2i = Vector2i.ZERO
var facing: Vector2i = Vector2i.RIGHT
var floor_number: int = 1
var hp: int = 55
var max_hp: int = 55
var level: int = 1
var xp: int = 0
var hunger: int = 100
var gold: int = 0
var kills: int = 0
var turns: int = 0
var inventory: Array[String] = []
var weapon: String = ""
var shield: String = ""
var identified: Dictionary = {}
var enemies: Array[Dictionary] = []
var ground_items: Array[Dictionary] = []
var messages: Array[String] = []
var status: String = "title"
var result_cause: String = ""
var best_floor: int = 0
var run_seed: int = 0
var save_enabled: bool = true
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _next_enemy_id: int = 0


func _ready() -> void:
	load_record()


func start_run(seed_value: int = 0) -> void:
	run_seed = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
	_rng.seed = run_seed
	floor_number = 1
	hp = 55
	max_hp = 55
	level = 1
	xp = 0
	hunger = 100
	gold = 0
	kills = 0
	turns = 0
	inventory.assign(["blade", "shield", "herb", "herb", "food", "food", "wand"])
	weapon = "blade"
	shield = "shield"
	identified.clear()
	messages.clear()
	result_cause = ""
	_next_enemy_id = 0
	status = "playing"
	facing = Vector2i.RIGHT
	_generate_floor()
	_log("灯りを頼りに、深淵の出口を目指そう。")
	changed.emit()


func attack_power() -> int:
	return 6 + (level - 1) * 2 + int(Data.ITEMS.get(weapon, {}).get("power", 0))


func defense_power() -> int:
	return 1 + (level - 1) / 2 + int(Data.ITEMS.get(shield, {}).get("power", 0))


func xp_to_next() -> int:
	return level * 16


func item_name(kind: String) -> String:
	var item: Dictionary = Data.ITEMS.get(kind, {})
	if item.has("unknown") and not identified.has(kind):
		return str(item.unknown)
	return str(item.get("name", kind))


func item_description(kind: String) -> String:
	if Data.ITEMS[kind].has("unknown") and not identified.has(kind):
		return "まだ識別されていない。使うと効果が分かる。"
	return str(Data.ITEMS[kind].description)


func enemy_at(cell: Vector2i) -> int:
	for index: int in range(enemies.size()):
		if enemies[index].pos == cell:
			return index
	return -1


func move(direction: Vector2i) -> bool:
	if status != "playing" or direction == Vector2i.ZERO:
		return false
	if absi(direction.x) > 1 or absi(direction.y) > 1:
		return false
	facing = direction
	var destination: Vector2i = player_pos + direction
	if not dungeon.can_step(player_pos, destination):
		return false
	var target: int = enemy_at(destination)
	if target >= 0:
		_damage_enemy(target, maxi(1, attack_power() - _enemy_defense(target)), true)
	else:
		player_pos = destination
		hunger = maxi(0, hunger - 1)
		event.emit("move", player_pos, 0)
		_pickup_here()
		if player_pos == dungeon.stairs:
			_log("出口だ。決定キーで%s。" % ("脱出" if floor_number == Data.LAST_FLOOR else "次の階へ"))
	_end_turn()
	return true


func wait_turn() -> void:
	if status == "playing":
		_end_turn()


func descend() -> bool:
	if status != "playing" or player_pos != dungeon.stairs:
		return false
	if floor_number == Data.LAST_FLOOR:
		return escape()
	floor_number += 1
	_generate_floor()
	event.emit("stairs", player_pos, floor_number)
	changed.emit()
	return true


func escape() -> bool:
	if status != "playing" or floor_number != Data.LAST_FLOOR or player_pos != dungeon.stairs:
		return false
	_finish("won", "深淵の出口から生還した")
	return true


func retire() -> void:
	_finish("dead", "探索を断念して帰還した")


func return_title() -> void:
	status = "title"
	changed.emit()


func pickup() -> bool:
	if status != "playing":
		return false
	var picked: bool = _pickup_here()
	if picked:
		_end_turn()
	return picked


func use_item(index: int) -> bool:
	if not _valid_item(index):
		return false
	var kind: String = inventory[index]
	var item: Dictionary = Data.ITEMS[kind]
	identified[kind] = true
	match str(item.type):
		"weapon":
			weapon = kind
		"shield":
			shield = kind
		"heal":
			hp = mini(max_hp, hp + int(item.power))
		"food":
			hunger = mini(100, hunger + int(item.power))
		"scroll":
			if kind == "fire":
				for target: int in range(enemies.size() - 1, -1, -1):
					if dungeon.same_room(player_pos, enemies[target].pos) or (
						player_pos.distance_to(enemies[target].pos) <= 2):
						_damage_enemy(target, int(item.power), false)
			else:
				var occupant: int = enemy_at(dungeon.stairs)
				if occupant >= 0:
					enemies[occupant].pos = player_pos
				player_pos = dungeon.stairs
		"wand":
			_cast_wand(int(item.power))
	if str(item.type) not in ["weapon", "shield"]:
		inventory.remove_at(index)
	_log("%sを%s。" % [item_name(kind), "装備した" if str(item.type) in ["weapon", "shield"] else "使った"])
	event.emit("use", player_pos, 0)
	_end_turn()
	return true


func drop_item(index: int) -> bool:
	if not _valid_item(index):
		return false
	var kind: String = inventory[index]
	_remove_equipment(kind)
	inventory.remove_at(index)
	ground_items.append({"pos": player_pos, "kind": kind})
	_log("%sを足元に置いた。" % item_name(kind))
	_end_turn()
	return true


func throw_item(index: int, direction: Vector2i) -> bool:
	if not _valid_item(index) or direction == Vector2i.ZERO:
		return false
	if absi(direction.x) > 1 or absi(direction.y) > 1:
		return false
	var kind: String = inventory[index]
	_remove_equipment(kind)
	inventory.remove_at(index)
	facing = direction
	var cell: Vector2i = player_pos
	var hit: bool = false
	for step: int in range(6):
		if not dungeon.can_step(cell, cell + direction):
			break
		cell += direction
		var target: int = enemy_at(cell)
		if target >= 0:
			_damage_enemy(target, 12 + level, false)
			hit = true
			break
	if not hit:
		ground_items.append({"pos": cell, "kind": kind})
	_log("%sを投げた。" % item_name(kind))
	event.emit("attack", cell, 0)
	_end_turn()
	return true


func record_from_value(value: Variant) -> int:
	if not value is Dictionary:
		return 0
	var depth: Variant = value.get("best_floor", 0)
	if not (depth is float or depth is int):
		return 0
	if not is_finite(float(depth)):
		return 0
	return clampi(int(depth), 0, Data.LAST_FLOOR)


func load_record() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parser: JSON = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(SAVE_PATH)) == OK:
		best_floor = record_from_value(parser.data)


func _save_record() -> void:
	if not save_enabled:
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"best_floor": best_floor}))


func _generate_floor() -> void:
	dungeon.generate(run_seed, floor_number)
	player_pos = dungeon.entrance
	enemies.clear()
	ground_items.clear()
	var choices: Array = Data.FLOOR_ENEMIES[floor_number - 1]
	for index: int in range(3 + floor_number):
		var kind: String = str(choices[_rng.randi_range(0, choices.size() - 1)])
		_spawn_enemy(kind, _random_empty_cell(true))
	if floor_number == Data.LAST_FLOOR:
		_spawn_enemy("boss", _random_empty_cell(true))
	for index: int in range(5):
		var kind: String = Data.LOOT[_rng.randi_range(0, Data.LOOT.size() - 1)]
		ground_items.append({"pos": _random_empty_cell(false), "kind": kind})
	ground_items.append({"pos": _random_empty_cell(false), "kind": "food"})
	if floor_number == 3:
		ground_items.append({"pos": player_pos + _first_open_direction(), "kind": "sunblade"})
	if floor_number == 4:
		ground_items.append({"pos": player_pos + _first_open_direction(), "kind": "ironshield"})
	best_floor = maxi(best_floor, floor_number)
	_save_record()
	_log("地下 %d 階。%s" % [floor_number, "出口を探せ。番人が待ち受ける。" if (
		floor_number == Data.LAST_FLOOR) else "階段を探し、灯りを絶やさず進もう。"])


func _first_open_direction() -> Vector2i:
	for direction: Vector2i in Dungeon.DIRECTIONS:
		if dungeon.is_floor(player_pos + direction):
			return direction
	return Vector2i.ZERO


func _random_empty_cell(away: bool) -> Vector2i:
	var candidates: Array = dungeon.floor_cells.keys()
	for attempt: int in range(300):
		var cell: Vector2i = candidates[_rng.randi_range(0, candidates.size() - 1)]
		if cell == player_pos or cell == dungeon.stairs or enemy_at(cell) >= 0:
			continue
		if away and (dungeon.same_room(player_pos, cell) or player_pos.distance_to(cell) < 7):
			continue
		return cell
	return dungeon.rooms[-1].position


func _spawn_enemy(kind: String, cell: Vector2i, divided: bool = false) -> void:
	var data: Dictionary = Data.ENEMIES[kind]
	_next_enemy_id += 1
	enemies.append({"id": _next_enemy_id, "kind": kind, "pos": cell,
		"hp": int(data.hp) + (floor_number - 1) * 2, "awake": str(data.ai) != "sleep",
		"divided": divided})


func _valid_item(index: int) -> bool:
	return status == "playing" and index >= 0 and index < inventory.size()


func _remove_equipment(kind: String) -> void:
	if weapon == kind:
		weapon = ""
	if shield == kind:
		shield = ""


func _pickup_here() -> bool:
	var picked: bool = false
	for index: int in range(ground_items.size() - 1, -1, -1):
		if ground_items[index].pos != player_pos:
			continue
		if inventory.size() >= Data.PACK_LIMIT:
			_log("持ち物がいっぱい。捨てるか使って空きを作ろう。")
			break
		var kind: String = str(ground_items[index].kind)
		inventory.append(kind)
		ground_items.remove_at(index)
		_log("%sを拾った。" % item_name(kind))
		event.emit("pickup", player_pos, 0)
		picked = true
	return picked


func _cast_wand(power: int) -> void:
	var cell: Vector2i = player_pos
	for step: int in range(7):
		if not dungeon.can_step(cell, cell + facing):
			break
		cell += facing
		var target: int = enemy_at(cell)
		if target < 0:
			continue
		var target_id: int = int(enemies[target].id)
		_damage_enemy(target, power, false)
		for enemy: Dictionary in enemies:
			if int(enemy.id) != target_id:
				continue
			for push: int in range(3):
				var next: Vector2i = Vector2i(enemy.pos) + facing
				if dungeon.can_step(enemy.pos, next) and enemy_at(next) < 0:
					enemy.pos = next
		break


func _enemy_defense(index: int) -> int:
	return int(Data.ENEMIES[enemies[index].kind].defense)


func _damage_enemy(index: int, damage: int, allow_split: bool) -> void:
	var enemy: Dictionary = enemies[index]
	enemy.hp = int(enemy.hp) - damage
	enemy.awake = true
	event.emit("attack", enemy.pos, damage)
	if int(enemy.hp) <= 0:
		var kind: String = str(enemy.kind)
		enemies.remove_at(index)
		kills += 1
		gold += _rng.randi_range(8, 18)
		xp += int(Data.ENEMIES[kind].xp)
		_log("%sを倒した。" % str(Data.ENEMIES[kind].name))
		event.emit("kill", enemy.pos, 0)
		while xp >= xp_to_next():
			xp -= xp_to_next()
			level += 1
			max_hp += 8
			hp = mini(max_hp, hp + 16)
			_log("レベル %d！ 体力と攻撃力が上がった。" % level)
			event.emit("level", player_pos, level)
		if kind == "boss":
			_finish("won", "深淵の番人を倒した")
	elif allow_split and str(enemy.kind) == "splitter" and not bool(enemy.divided):
		enemy.divided = true
		for direction: Vector2i in Dungeon.DIRECTIONS:
			var cell: Vector2i = Vector2i(enemy.pos) + direction
			if dungeon.can_step(enemy.pos, cell) and enemy_at(cell) < 0 and cell != player_pos:
				_spawn_enemy("splitter", cell, true)
				enemies[-1].hp = 8
				_log("雫の群れが分裂した！")
				event.emit("spawn", cell, 0)
				break


func _end_turn() -> void:
	if status != "playing":
		changed.emit()
		return
	turns += 1
	dungeon.update_visibility(player_pos)
	_enemy_turns()
	if status == "playing":
		if hunger == 0:
			_hurt_player(1, "空腹で力尽きた")
		elif turns % 4 == 0:
			hp = mini(max_hp, hp + 1)
	dungeon.update_visibility(player_pos)
	changed.emit()


func _enemy_turns() -> void:
	for enemy: Dictionary in enemies.duplicate():
		if status != "playing":
			break
		var data: Dictionary = Data.ENEMIES[enemy.kind]
		var distance: float = player_pos.distance_to(enemy.pos)
		if not bool(enemy.awake):
			if distance > 2.5:
				continue
			enemy.awake = true
			_log("眠り石が目を覚ました。")
		var sight: bool = distance <= 9 and dungeon.line_of_sight(enemy.pos, player_pos)
		if not sight:
			continue
		var steps: int = 2 if str(data.ai) == "swift" else 1
		for step: int in range(steps):
			if status != "playing":
				break
			_enemy_action(enemy, data)


func _enemy_action(enemy: Dictionary, data: Dictionary) -> void:
	var difference: Vector2i = player_pos - Vector2i(enemy.pos)
	var adjacent: bool = maxi(absi(difference.x), absi(difference.y)) <= 1
	if adjacent and dungeon.can_step(enemy.pos, player_pos):
		event.emit("enemy_attack", enemy.pos, 0)
		_hurt_player(maxi(1, int(data.attack) + floor_number - 1 - defense_power()),
			"%sに倒された" % str(data.name))
		return
	if str(data.ai) == "ranged" and player_pos.distance_to(enemy.pos) <= 6 and (
		difference.x == 0 or difference.y == 0 or absi(difference.x) == absi(difference.y)):
		if dungeon.line_of_sight(enemy.pos, player_pos):
			event.emit("enemy_attack", enemy.pos, 0)
			_hurt_player(maxi(1, int(data.attack) - defense_power()), "灯射手の矢に倒れた")
			return
	var diagonal: Vector2i = Vector2i(signi(difference.x), signi(difference.y))
	var choices: Array[Vector2i] = [diagonal, Vector2i(diagonal.x, 0), Vector2i(0, diagonal.y)]
	for direction: Vector2i in choices:
		var cell: Vector2i = Vector2i(enemy.pos) + direction
		if direction != Vector2i.ZERO and dungeon.can_step(enemy.pos, cell) and (
			enemy_at(cell) < 0 and cell != player_pos):
			enemy.pos = cell
			break


func _hurt_player(damage: int, cause: String) -> void:
	hp = maxi(0, hp - damage)
	event.emit("hurt", player_pos, damage)
	if hp == 0:
		_finish("dead", cause)


func _finish(outcome: String, cause: String) -> void:
	if status != "playing":
		return
	status = outcome
	result_cause = cause
	if outcome == "dead":
		inventory.clear()
		weapon = ""
		shield = ""
	_save_record()
	event.emit("win" if outcome == "won" else "death", player_pos, 0)
	changed.emit()
	finished.emit()


func _log(message: String) -> void:
	messages.append(message)
	if messages.size() > 40:
		messages.pop_front()
