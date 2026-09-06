extends Node
## 画面をまたぐ冒険と戦闘の状態。乱数器を注入可能にして同じ戦闘を検証できる。

const SAVE_PATH: String = "user://adventure.json"
const SAVE_VERSION: int = 1

var party: Array = []
var storage: Array = []
var balls: int = 12
var potions: int = 5
var zone: String = "town"
var cell: Vector2i = Vector2i(9, 10)
var enemy: Dictionary = {}
var trainer: bool = false
var mode: String = "title"
var active_index: int = 0
var steps: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func new_game() -> void:
	party = [Catalog.create_monster("ember", 5)]
	storage = []
	balls = 12
	potions = 5
	zone = "town"
	cell = Vector2i(9, 10)
	enemy = {}
	trainer = false
	mode = "field"
	active_index = 0
	steps = 0


func heal_party() -> void:
	for monster: Dictionary in party:
		monster.hp = Catalog.stats(monster).hp
	balls = maxi(balls, 12)
	potions = maxi(potions, 5)


func active_monster() -> Dictionary:
	if party.is_empty():
		return {}
	return party[active_index]


func start_battle(id: String, level: int, is_trainer: bool = false) -> void:
	if mode != "field" or not Catalog.SPECIES.has(id):
		return
	if active_index < 0 or active_index >= party.size() or party[active_index].hp <= 0:
		active_index = _first_healthy()
	if active_index < 0:
		active_index = 0
		mode = "gameover"
		return
	enemy = Catalog.create_monster(id, level)
	trainer = is_trainer
	mode = "battle"


## アイテム消費とターン進行が目的のため、同じ入力でも毎回状態を進める。
func resolve_turn(action: String, move_id: String = "") -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if mode != "battle":
		return events
	if action == "attack":
		if move_id not in Catalog.moves(active_monster()):
			return [_message("その技はまだ使えない。")]
		var player_first: bool = Catalog.stats(active_monster()).speed >= Catalog.stats(enemy).speed
		if player_first:
			_attack(true, move_id, events)
			if mode == "battle":
				_enemy_attack(events)
		else:
			var before_index: int = active_index
			_enemy_attack(events)
			if mode == "battle" and active_index == before_index:
				_attack(true, move_id, events)
		return events
	if not _item_action(action, move_id, events):
		return events
	if mode == "battle":
		_enemy_attack(events)
	return events


## 戦闘での消費・交代はプレイヤーが入力した回数だけ実行する。
func _item_action(action: String, argument: String, events: Array[Dictionary]) -> bool:
	match action:
		"capture":
			return _capture(events)
		"potion":
			return _potion(events)
		"flee":
			if trainer:
				events.append(_message("隊長との勝負からは逃げられない。"))
				return false
			mode = "field"
			events.append(_message("無事に逃げ出した。"))
		"switch":
			return _switch(argument, events)
		_:
			return false
	return true


## 回復薬の消費は入力した回数に対応するため非冪等。
func _potion(events: Array[Dictionary]) -> bool:
	if potions <= 0 or active_monster().hp == Catalog.stats(active_monster()).hp:
		events.append(_message("回復薬がないか、HP が満タンだ。"))
		return false
	potions -= 1
	active_monster().hp = mini(active_monster().hp + 35, Catalog.stats(active_monster()).hp)
	events.append(_message("回復薬で HP を回復した！"))
	return true


func _switch(argument: String, events: Array[Dictionary]) -> bool:
	if not argument.is_valid_int():
		return false
	var next_index: int = int(argument)
	if next_index < 0 or next_index >= party.size() or next_index == active_index:
		return false
	if party[next_index].hp <= 0:
		events.append(_message("その仲間は倒れている。"))
		return false
	active_index = next_index
	events.append(_message("いっておいで、%s！" % _name(active_monster())))
	return true


## 抽選とボールの消費を伴うため、捕獲入力ごとに実行する。
func _capture(events: Array[Dictionary]) -> bool:
	if trainer or balls <= 0:
		events.append(_message("隊長の仲間は捕まえられない。" if trainer else "ボールがない。"))
		return false
	balls -= 1
	if rng.randf() >= Catalog.capture_chance(enemy):
		events.append({"kind": "capture", "text": "ボールから飛び出した！", "success": false})
		return true
	var caught: Dictionary = enemy.duplicate(true)
	var joins_party: bool = party.size() < 6
	if joins_party:
		party.append(caught)
	else:
		storage.append(caught)
	mode = "field"
	var destination: String = "手持ち" if joins_party else "預かり所"
	events.append({
		"kind": "capture", "success": true,
		"text": "%sを捕まえた！ %sに加わった。" % [_name(caught), destination],
	})
	return true


## 敵の技をターンごとに抽選するため非冪等。
func _enemy_attack(events: Array[Dictionary]) -> void:
	var available: Array = Catalog.moves(enemy)
	_attack(false, available[rng.randi_range(0, available.size() - 1)], events)


## 攻撃のたびに HP と勝敗を進めるため非冪等。
func _attack(player: bool, move_id: String, events: Array[Dictionary]) -> void:
	var attacker: Dictionary = active_monster() if player else enemy
	var defender: Dictionary = enemy if player else active_monster()
	var amount: int = mini(defender.hp, Catalog.damage(attacker, defender, move_id))
	defender.hp -= amount
	var multiplier: float = Catalog.effectiveness(
		Catalog.MOVES[move_id].type, Catalog.SPECIES[defender.species].type
	)
	var text: String = "%sの%s！ %d ダメージ" % [
		_name(attacker), Catalog.MOVES[move_id].name, amount,
	]
	if multiplier > 1.0:
		text += " / 効果ばつぐん！"
	elif multiplier < 1.0:
		text += " / 効果はいまひとつ"
	events.append({
		"kind": "attack", "target": "enemy" if player else "player", "text": text,
		"damage": amount, "effectiveness": multiplier,
	})
	if defender.hp > 0:
		return
	if player:
		_victory(events)
	else:
		events.append(_message("%sは力尽きた。" % _name(defender)))
		var next_index: int = _first_healthy()
		if next_index < 0:
			mode = "gameover"
			events.append(_message("仲間がみんな倒れてしまった…。"))
		else:
			active_index = next_index
			events.append(_message("%sが代わりに戦う！" % _name(active_monster())))


## 勝利報酬を一度の戦闘終了時に加算するため非冪等。
func _victory(events: Array[Dictionary]) -> void:
	mode = "clear" if trainer else "field"
	var reward: int = int(enemy.level) * 14
	var monster: Dictionary = active_monster()
	monster.xp += reward
	events.append(_message("勝利！ %d 経験値を獲得した。" % reward))
	while monster.level < Catalog.MAX_LEVEL and monster.xp >= Catalog.xp_needed(monster.level):
		var old_moves: Array = Catalog.moves(monster)
		var old_hp: int = Catalog.stats(monster).hp
		monster.xp -= Catalog.xp_needed(monster.level)
		monster.level += 1
		monster.hp += Catalog.stats(monster).hp - old_hp
		events.append({"kind": "level", "text": "%sは Lv.%d に成長！" % [
			_name(monster), monster.level,
		]})
		for move_id: String in Catalog.moves(monster):
			if move_id not in old_moves:
				events.append(_message("新しい技「%s」を覚えた！" % Catalog.MOVES[move_id].name))
	if monster.level == Catalog.MAX_LEVEL:
		monster.xp = 0


## 二つの個体の交換が操作そのものなので、呼び出すたびに交換する。
func swap_storage(party_index: int, storage_index: int) -> bool:
	if mode != "field" or zone != "clinic":
		return false
	if party_index < 0 or party_index >= party.size():
		return false
	if storage_index < 0 or storage_index >= storage.size():
		return false
	var previous: Dictionary = party[party_index]
	party[party_index] = storage[storage_index]
	storage[storage_index] = previous
	return true


func save_game(path: String = SAVE_PATH) -> bool:
	if mode != "field":
		return false
	var data: Dictionary = {
		"version": SAVE_VERSION, "party": party, "storage": storage,
		"balls": balls, "potions": potions, "zone": zone,
		"cell": [cell.x, cell.y], "steps": steps, "active_index": active_index,
	}
	if not valid_save(data):
		return false
	var staging_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(staging_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		return false
	return DirAccess.rename_absolute(staging_path, path) == OK


func load_game(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parser: JSON = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return false
	var data: Variant = parser.data
	if not valid_save(data):
		return false
	party = data.party.duplicate(true)
	storage = data.storage.duplicate(true)
	for monster: Dictionary in party + storage:
		for key: String in ["level", "hp", "xp"]:
			monster[key] = int(monster[key])
	balls = int(data.balls)
	potions = int(data.potions)
	zone = data.zone
	cell = Vector2i(int(data.cell[0]), int(data.cell[1]))
	steps = int(data.steps)
	enemy = {}
	trainer = false
	active_index = int(data.active_index)
	mode = "field"
	return true


func valid_save(data: Variant) -> bool:
	if not _valid_save_structure(data):
		return false
	var living: bool = false
	for monster: Variant in data.party:
		if not Catalog.valid_monster(monster):
			return false
		living = living or monster.hp > 0
	for monster: Variant in data.storage:
		if not Catalog.valid_monster(monster):
			return false
	if not living or not _valid_position(data):
		return false
	return (
		Catalog.integer_between(data.active_index, 0, data.party.size() - 1)
		and Catalog.integer_between(data.balls, 0, 10000)
		and Catalog.integer_between(data.potions, 0, 10000)
		and Catalog.integer_between(data.steps, 0, 1000000000)
	)


func _valid_save_structure(data: Variant) -> bool:
	if not data is Dictionary or data.size() != 9:
		return false
	if not data.has_all([
		"version", "party", "storage", "balls", "potions", "zone", "cell", "steps", "active_index",
	]):
		return false
	if not Catalog.integer_between(data.version, SAVE_VERSION, SAVE_VERSION):
		return false
	if not data.party is Array or data.party.is_empty() or data.party.size() > 6:
		return false
	return data.storage is Array and data.storage.size() <= 10000


func _valid_position(data: Dictionary) -> bool:
	if not data.zone is String or data.zone not in ["town", "route", "home", "clinic"]:
		return false
	if not data.cell is Array or data.cell.size() != 2:
		return false
	return (
		Catalog.integer_between(data.cell[0], 0, 23)
		and Catalog.integer_between(data.cell[1], 0, 13)
		and QuestWorld.walkable(data.zone, Vector2i(int(data.cell[0]), int(data.cell[1])))
	)


func _first_healthy() -> int:
	for index: int in party.size():
		if party[index].hp > 0:
			return index
	return -1


func _name(monster: Dictionary) -> String:
	return Catalog.SPECIES[monster.species].name


func _message(text: String) -> Dictionary:
	return {"kind": "message", "text": text}
