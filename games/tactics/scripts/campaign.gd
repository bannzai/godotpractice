extends Node
## 戦闘・成長・フェーズ進行はプレイヤーの操作を一度適用するため非冪等。
## 検証では save_path を作業ディレクトリ内へ差し替えて実セーブを保護する。

var screen: String = "title"
var stage_index: int = 0
var turn: int = 1
var phase: String = "player"
var outcome: String = ""
var units: Array[Dictionary] = []
var events: Array[Dictionary] = []
var save_path: String = "user://campaign.json"
var save_error: String = ""
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _move_origins: Dictionary = {}


func new_game() -> bool:
	stage_index = 0
	units.clear()
	for definition: Dictionary in BattleData.ALLIES:
		units.append(BattleData.create_unit(definition, "player"))
	_start_stage()
	return save_game()


func stage() -> Dictionary:
	return BattleData.STAGES[stage_index]


func unit_by_id(id: String) -> Dictionary:
	for unit: Dictionary in units:
		if unit.id == id:
			return unit
	return {}


func unit_at(cell: Vector2i) -> Dictionary:
	for unit: Dictionary in units:
		if unit.hp > 0 and BattleRules.position_of(unit) == cell:
			return unit
	return {}


func living(team: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for unit: Dictionary in units:
		if unit.team == team and unit.hp > 0:
			result.append(unit)
	return result


func movement(unit: Dictionary) -> Array[Vector2i]:
	if unit.is_empty() or unit.hp <= 0 or unit.acted:
		return []
	if unit.moved:
		return [BattleRules.position_of(unit)]
	return BattleRules.movement(unit, units, stage().map)


func attack_range(unit: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if unit.is_empty() or unit.hp <= 0 or unit.acted:
		return result
	var reach: int = 2 if unit.job == "bow" else 1
	for origin: Vector2i in movement(unit):
		for x: int in range(-reach, reach + 1):
			for y: int in range(-reach, reach + 1):
				var cell: Vector2i = origin + Vector2i(x, y)
				if absi(x) + absi(y) == reach and BattleData.inside(cell) and cell not in result:
					result.append(cell)
	return result


func move_unit(id: String, cell: Vector2i) -> bool:
	var unit: Dictionary = unit_by_id(id)
	if not _can_act(unit) or unit.moved or cell not in movement(unit):
		return false
	_move_origins[id] = BattleRules.position_of(unit)
	unit.x = cell.x
	unit.y = cell.y
	unit.moved = true
	_check_outcome()
	return true


func undo_move(id: String) -> bool:
	var unit: Dictionary = unit_by_id(id)
	if not _can_act(unit) or not _move_origins.has(id):
		return false
	unit.x = _move_origins[id].x
	unit.y = _move_origins[id].y
	unit.moved = false
	_move_origins.erase(id)
	return true


func preview(attacker_id: String, target_id: String) -> Dictionary:
	var attacker: Dictionary = unit_by_id(attacker_id)
	var target: Dictionary = unit_by_id(target_id)
	if not _can_act(attacker) or target.is_empty() or target.hp <= 0:
		return {}
	if not BattleRules.can_reach(attacker, target):
		return {}
	if attacker.job == "healer":
		if target.team != attacker.team or target.hp == target.max_hp:
			return {}
	elif target.team == attacker.team:
		return {}
	return BattleRules.forecast(attacker, target, stage().map)


func attack(attacker_id: String, target_id: String) -> Array[Dictionary]:
	events = []
	var prediction: Dictionary = preview(attacker_id, target_id)
	if prediction.is_empty():
		return events
	var attacker: Dictionary = unit_by_id(attacker_id)
	var target: Dictionary = unit_by_id(target_id)
	if attacker.job == "healer":
		var healed: int = mini(prediction.heal, target.max_hp - target.hp)
		target.hp += healed
		events.append({"kind": "heal", "actor": attacker.id, "target": target.id, "amount": healed})
		_grant_xp(attacker, 20)
	else:
		_hit(attacker, target)
		if target.hp > 0 and attacker.hp > 0 and prediction.counter_strikes > 0:
			_hit(target, attacker)
		if target.hp > 0 and attacker.hp > 0 and prediction.strikes == 2:
			_hit(attacker, target)
		if target.hp > 0 and attacker.hp > 0 and prediction.counter_strikes == 2:
			_hit(target, attacker)
	_finish_action(attacker)
	return events.duplicate(true)


func wait_unit(id: String) -> void:
	var unit: Dictionary = unit_by_id(id)
	if _can_act(unit):
		_finish_action(unit)


func use_item(id: String) -> Array[Dictionary]:
	events = []
	var unit: Dictionary = unit_by_id(id)
	if not _can_act(unit) or unit.items <= 0 or unit.hp == unit.max_hp:
		return events
	var amount: int = mini(15, unit.max_hp - unit.hp)
	unit.hp += amount
	unit.items -= 1
	events.append({"kind": "heal", "actor": id, "target": id, "amount": amount})
	_finish_action(unit)
	return events.duplicate(true)


func end_player_phase() -> void:
	if phase != "player" or outcome != "":
		return
	phase = "enemy"
	_move_origins.clear()
	for unit: Dictionary in living("enemy"):
		unit.acted = false
		unit.moved = false
	save_game()


func enemy_step() -> Array[Dictionary]:
	events = []
	if phase != "enemy" or outcome != "":
		return events
	for unit: Dictionary in living("enemy"):
		if unit.acted:
			continue
		var choice: Dictionary = _enemy_choice(unit)
		var origin: Vector2i = BattleRules.position_of(unit)
		if choice.cell != origin:
			unit.x = choice.cell.x
			unit.y = choice.cell.y
			events.append({"kind": "move", "actor": unit.id, "from": origin, "to": choice.cell})
		if choice.target != "":
			var movement_events: Array[Dictionary] = events.duplicate(true)
			attack(unit.id, choice.target)
			events = movement_events + events
		else:
			_finish_action(unit)
		return events.duplicate(true)
	phase = "player"
	turn += 1
	for unit: Dictionary in living("player"):
		unit.acted = false
		unit.moved = false
	save_game()
	return events


func next_stage() -> bool:
	if outcome != "victory":
		return false
	stage_index += 1
	_start_stage()
	return save_game()


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func save_game() -> bool:
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		save_error = "進行を保存できませんでした。"
		return false
	file.store_string(JSON.stringify({"version": 1, "stage": stage_index, "turn": turn,
		"phase": phase, "outcome": outcome, "units": units}))
	save_error = ""
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(save_path)) != OK:
		return false
	if not valid_save(json.data):
		return false
	var data: Dictionary = json.data
	stage_index = int(data.stage)
	turn = int(data.turn)
	phase = data.phase
	outcome = data.outcome
	units.assign(data.units)
	_move_origins.clear()
	for unit: Dictionary in units:
		for key: String in ["x", "y", "hp", "max_hp", "level", "xp", "strength", "defense",
			"speed", "skill", "move", "items"]:
			unit[key] = int(unit[key])
	screen = "play" if outcome == "" else "result"
	return true


func valid_save(data: Variant) -> bool:
	if not data is Dictionary or not _valid_header(data):
		return false
	var ids: Array[String] = []
	var occupied: Array[Vector2i] = []
	for value: Variant in data.units:
		if not _valid_unit(value):
			return false
		var cell: Vector2i = Vector2i(value.x, value.y)
		if value.id in ids or (value.hp > 0 and cell in occupied):
			return false
		ids.append(value.id)
		if value.hp > 0:
			occupied.append(cell)
	return _valid_roster(data)


func _valid_roster(data: Dictionary) -> bool:
	var definitions: Array = BattleData.ALLIES + BattleData.STAGES[int(data.stage)].enemies
	if data.units.size() != definitions.size():
		return false
	for definition: Dictionary in definitions:
		var matching: bool = false
		for unit: Dictionary in data.units:
			if unit.id != definition.id:
				continue
			var team: String = "player" if definition in BattleData.ALLIES else "enemy"
			matching = unit.team == team and unit.job == definition.job
			matching = matching and unit.boss == definition.get("boss", false)
		if not matching:
			return false
	return not (data.stage == BattleData.STAGES.size() - 1 and data.outcome == "victory")


func _valid_header(data: Dictionary) -> bool:
	for key: String in ["version", "stage", "turn", "phase", "outcome", "units"]:
		if not data.has(key):
			return false
	for key: String in ["version", "stage", "turn"]:
		if not _whole_number(data[key]):
			return false
	return (data.version == 1 and data.stage >= 0 and data.stage < BattleData.STAGES.size()
		and data.turn >= 1 and data.phase in ["player", "enemy"]
		and data.outcome in ["", "victory", "defeat", "ending"]
		and data.units is Array and not data.units.is_empty())


func _valid_unit(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key: String in ["id", "name", "job", "team", "x", "y", "hp", "max_hp", "strength",
		"defense", "speed", "skill", "move", "level", "xp", "items", "acted", "moved",
		"ai", "growth", "boss"]:
		if not value.has(key):
			return false
	if not _valid_unit_identity(value):
		return false
	for key: String in ["x", "y", "hp", "max_hp", "strength", "defense", "speed", "skill",
		"move", "level", "xp", "items"]:
		if not _whole_number(value[key]) or value[key] < 0 or value[key] > 999:
			return false
	for stat: Variant in value.growth:
		if (stat not in ["max_hp", "strength", "defense", "speed", "skill"]
			or not _whole_number(value.growth[stat])
			or value.growth[stat] < 0 or value.growth[stat] > 100):
			return false
	return (BattleData.inside(Vector2i(value.x, value.y)) and value.hp <= value.max_hp
		and value.max_hp > 0 and value.level > 0 and value.xp < 100)


func _valid_unit_identity(value: Dictionary) -> bool:
	return (value.id is String and value.name is String and BattleData.JOBS.has(value.job)
		and value.team in ["player", "enemy"] and value.growth is Dictionary
		and value.acted is bool and value.moved is bool and value.boss is bool
		and value.ai in ["hold", "approach"])


func _whole_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(value) and value == floor(value)


func _start_stage() -> void:
	units = living("player") + _dead_allies()
	for unit: Dictionary in units:
		for definition: Dictionary in BattleData.ALLIES:
			if unit.id == definition.id:
				unit.x = definition.x
				unit.y = definition.y
		if unit.hp > 0:
			unit.hp = unit.max_hp
		unit.acted = false
		unit.moved = false
	for definition: Dictionary in stage().enemies:
		units.append(BattleData.create_unit(definition, "enemy"))
	turn = 1
	phase = "player"
	outcome = ""
	screen = "play"
	_move_origins.clear()


func _dead_allies() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for unit: Dictionary in units:
		if unit.team == "player" and unit.hp <= 0:
			result.append(unit)
	return result


func _can_act(unit: Dictionary) -> bool:
	return (not unit.is_empty() and unit.hp > 0 and not unit.acted
		and unit.team == phase and outcome == "")


func _hit(attacker: Dictionary, target: Dictionary) -> void:
	var prediction: Dictionary = BattleRules.strike(attacker, target, stage().map)
	events.append({"kind": "attack", "actor": attacker.id, "target": target.id})
	if rng.randi_range(1, 100) > prediction.hit:
		events.append({"kind": "miss", "actor": attacker.id, "target": target.id, "amount": 0})
		return
	var critical: bool = rng.randi_range(1, 100) <= prediction.critical
	var damage: int = prediction.damage * (3 if critical else 1)
	target.hp = maxi(0, target.hp - damage)
	events.append({"kind": "hit", "actor": attacker.id, "target": target.id,
		"amount": damage, "critical": critical})
	if target.hp == 0:
		events.append({"kind": "death", "actor": attacker.id, "target": target.id})
		if attacker.team == "player":
			_grant_xp(attacker, 60)


func _grant_xp(unit: Dictionary, amount: int) -> void:
	unit.xp += amount
	while unit.xp >= 100:
		unit.xp -= 100
		unit.level += 1
		var gains: Array[String] = []
		for stat: String in unit.growth:
			if rng.randi_range(1, 100) <= unit.growth[stat]:
				unit[stat] += 1
				gains.append(stat)
				if stat == "max_hp":
					unit.hp += 1
		events.append({"kind": "level", "actor": unit.id, "target": unit.id,
			"amount": unit.level, "gains": gains})


func _finish_action(unit: Dictionary) -> void:
	unit.acted = true
	_move_origins.erase(unit.id)
	_check_outcome()
	if phase == "player" and outcome == "":
		var all_acted: bool = true
		for ally: Dictionary in living("player"):
			all_acted = all_acted and ally.acted
		if all_acted:
			end_player_phase()
	save_game()


func _check_outcome() -> void:
	var hero: Dictionary = unit_by_id("hero")
	if hero.hp <= 0:
		outcome = "defeat"
	elif stage().objective == "rout" and living("enemy").is_empty():
		outcome = "victory"
	elif stage().objective == "boss" and unit_by_id("boss").hp <= 0:
		outcome = "victory"
	elif stage().objective == "reach" and BattleRules.position_of(hero) == stage().goal:
		outcome = "ending"
	if outcome != "":
		save_game()


func _enemy_choice(unit: Dictionary) -> Dictionary:
	var origin: Vector2i = BattleRules.position_of(unit)
	var cells: Array[Vector2i] = BattleRules.movement(unit, units, stage().map)
	if unit.ai == "hold":
		cells = [origin]
	var best: Dictionary = {"cell": origin, "target": ""}
	var best_score: float = -INF
	var nearest: int = 999
	for cell: Vector2i in cells:
		for target: Dictionary in living("player"):
			var separation: int = BattleRules.distance(cell, BattleRules.position_of(target))
			if separation == (2 if unit.job == "bow" else 1):
				var prediction: Dictionary = BattleRules.strike(unit, target, stage().map)
				var score: float = prediction.damage * prediction.hit / 100.0 - target.hp
				if prediction.damage >= target.hp:
					score += 100
				if score > best_score:
					best_score = score
					best = {"cell": cell, "target": target.id}
			elif best.target == "" and separation < nearest:
				nearest = separation
				best.cell = cell
	return best
