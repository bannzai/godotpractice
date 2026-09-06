class_name BoardBattle
extends RefCounted
## 公開操作が唯一の戦闘状態遷移。ゲームイベントごとに進行するため状態変更は非冪等。

const Catalog = preload("res://scripts/core/catalog.gd")
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]

var width: int = 3
var units: Array[Dictionary] = []
var hands: Array = [[], []]
var decks: Array = [[], []]
var discards: Array = [[], []]
var hp: Array[int] = [10, 10]
var turn: int = 0
var phase: String = "standby"
var winner: int = -1
var turn_number: int = 1
var enemy_id: String = "scout"
var swapped: bool = false
var next_uid: int = 1
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(player_deck: Array, opponent: String, board_width: int,
		seed_number: int, player_hp: int = 10) -> bool:
	if not Catalog.valid_cards(player_deck, 4, 40) or not Catalog.ENEMIES.has(opponent):
		return false
	if board_width not in [3, 5] or player_hp < 1 or player_hp > 10:
		return false
	width = board_width
	enemy_id = opponent
	rng.seed = seed_number
	units.clear()
	hands = [[], []]
	decks = [player_deck.duplicate(), Catalog.ENEMIES[opponent].deck.duplicate()]
	discards = [[], []]
	hp.assign([player_hp, 10])
	turn = 0
	phase = "standby"
	winner = -1
	turn_number = 1
	swapped = false
	next_uid = 1
	for side: int in range(2):
		_shuffle(decks[side])
		for index: int in range(3):
			_draw(side)
	return true


func unit_at(pos: Vector2i) -> Dictionary:
	for unit: Dictionary in units:
		if position(unit) == pos:
			return unit
	return {}


func unit_by_id(uid: int) -> Dictionary:
	for unit: Dictionary in units:
		if unit.uid == uid:
			return unit
	return {}


func king_position(side: int) -> Vector2i:
	return Vector2i(width / 2, 4 if side == 0 else -1)


func in_board(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < 4


func own_zone(side: int, pos: Vector2i) -> bool:
	return in_board(pos) and (pos.y >= 2 if side == 0 else pos.y < 2)


func deploy(hand_index: int, pos: Vector2i) -> Dictionary:
	if phase != "standby" or not own_zone(turn, pos) or not unit_at(pos).is_empty():
		return _rejected()
	if hand_index < 0 or hand_index >= hands[turn].size():
		return _rejected()
	var unit: Dictionary = {"uid": next_uid, "card": hands[turn].pop_at(hand_index),
		"side": turn, "x": pos.x, "y": pos.y, "face": false, "moved": false,
		"attacked": false, "effect_used": false}
	next_uid += 1
	units.append(unit)
	return {"ok": true, "type": "deploy", "uid": unit.uid, "card": unit.card, "to": pos}


func reveal(uid: int) -> Dictionary:
	var unit: Dictionary = unit_by_id(uid)
	if not _standby_unit(unit) or unit.face:
		return _rejected()
	unit.face = true
	if _effect(unit) == "insight":
		_draw(turn)
	return {"ok": true, "type": "reveal", "uid": uid}


func swap_units(uid: int, other_uid: int) -> Dictionary:
	var unit: Dictionary = unit_by_id(uid)
	var other: Dictionary = unit_by_id(other_uid)
	if not _standby_unit(unit) or other.is_empty() or swapped:
		return _rejected()
	if distance(position(unit), position(other)) != 1:
		return _rejected()
	if other.side != turn and not (unit.face and _effect(unit) == "infiltrate"):
		return _rejected()
	var previous: Vector2i = position(unit)
	var destination: Vector2i = position(other)
	_set_position(unit, destination)
	_set_position(other, previous)
	swapped = true
	return {"ok": true, "type": "swap", "uid": uid, "other": other_uid,
		"from": previous, "to": destination, "other_from": destination, "other_to": previous}


func move_unit(uid: int, pos: Vector2i) -> Dictionary:
	var unit: Dictionary = unit_by_id(uid)
	if not _standby_unit(unit) or not unit.face or unit.moved:
		return _rejected()
	if not in_board(pos) or not unit_at(pos).is_empty() or distance(position(unit), pos) != 1:
		return _rejected()
	var previous: Vector2i = position(unit)
	_set_position(unit, pos)
	unit.moved = true
	return {"ok": true, "type": "move", "uid": uid, "from": previous, "to": pos}


func use_effect(uid: int, target_uid: int = -1) -> Dictionary:
	var unit: Dictionary = unit_by_id(uid)
	if not _standby_unit(unit) or not unit.face or unit.effect_used:
		return _rejected()
	if _effect(unit) == "reveal":
		var target: Dictionary = unit_by_id(target_uid)
		if target.is_empty() or target.side == turn or target.face:
			return _rejected()
		target.face = true
	elif _effect(unit) == "heal" and hp[turn] < 10:
		hp[turn] = mini(10, hp[turn] + 1)
	else:
		return _rejected()
	unit.effect_used = true
	return {"ok": true, "type": "effect", "uid": uid, "target": target_uid}


func begin_battle() -> Dictionary:
	if phase != "standby":
		return _rejected()
	phase = "battle"
	return {"ok": true, "type": "phase"}


func can_attack(uid: int, target_uid: int = -1, check_phase: bool = true) -> bool:
	var unit: Dictionary = unit_by_id(uid)
	if unit.is_empty() or unit.side != turn or not unit.face or unit.moved or unit.attacked:
		return false
	if winner != -1 or (check_phase and phase != "battle"):
		return false
	var target_pos: Vector2i = king_position(1 - turn)
	if target_uid != -1:
		var target: Dictionary = unit_by_id(target_uid)
		if target.is_empty() or target.side == turn:
			return false
		target_pos = position(target)
	var delta: Vector2i = target_pos - position(unit)
	var reach: int = 2 if _effect(unit) == "ranged" else 1
	return (delta.x == 0 or delta.y == 0) and distance(position(unit), target_pos) <= reach


func attack(uid: int, target_uid: int = -1) -> Dictionary:
	if not can_attack(uid, target_uid):
		return _rejected()
	var unit: Dictionary = unit_by_id(uid)
	var target: Dictionary = unit_by_id(target_uid)
	unit.attacked = true
	var event: Dictionary = {"ok": true, "type": "attack", "uid": uid,
		"card": unit.card, "target": target_uid, "from": position(unit),
		"target_card": "" if target.is_empty() else target.card,
		"target_was_hidden": not target.is_empty() and not target.face,
		"defeated": [], "damage": 0, "king_damage_side": -1}
	if target_uid == -1:
		event.to = king_position(1 - turn)
		event.damage = maxi(0, attack_power(unit, true) + int(_effect(unit) == "siege"))
		hp[1 - turn] = maxi(0, hp[1 - turn] - event.damage)
	else:
		_resolve_duel(unit, target, event)
	if event.damage > 0:
		event.king_damage_side = 1 - turn
	_check_winner()
	return event


func attack_power(unit: Dictionary, attacking: bool, target_face: bool = false) -> int:
	var power: int = Catalog.CARDS[unit.card].atk
	if attacking and target_face and _effect(unit) == "duelist":
		power += 1
	if not attacking and _effect(unit) == "guard":
		power += 2
	for ally: Dictionary in units:
		if ally.side == unit.side and ally.uid != unit.uid and ally.face and _effect(ally) == "aura":
			if distance(position(unit), position(ally)) == 1:
				power += 1
	return power


func end_turn() -> Dictionary:
	if phase != "battle":
		return _rejected()
	turn = 1 - turn
	turn_number += 1
	swapped = false
	phase = "standby"
	for unit: Dictionary in units:
		if unit.side == turn:
			unit.moved = false
			unit.attacked = false
			unit.effect_used = false
	_draw(turn)
	return {"ok": true, "type": "turn", "side": turn}


func ai_step() -> Dictionary:
	if phase == "over":
		return _rejected()
	if phase == "standby":
		return _ai_standby()
	var choice: Dictionary = _best_attack()
	if not choice.is_empty():
		return attack(choice.uid, choice.target)
	return end_turn()


func snapshot() -> Dictionary:
	return {"width": width, "units": units.duplicate(true), "hands": hands.duplicate(true),
		"decks": decks.duplicate(true), "discards": discards.duplicate(true), "hp": hp.duplicate(),
		"turn": turn, "phase": phase, "winner": winner, "turn_number": turn_number,
		"enemy_id": enemy_id, "swapped": swapped, "next_uid": next_uid,
		"rng_state": str(rng.state)}


func restore(data: Variant) -> bool:
	if not valid_snapshot(data):
		return false
	width = int(data.width)
	units.assign(data.units.duplicate(true))
	for unit: Dictionary in units:
		for key: String in ["uid", "side", "x", "y"]:
			unit[key] = int(unit[key])
	hands = data.hands.duplicate(true)
	decks = data.decks.duplicate(true)
	discards = data.discards.duplicate(true)
	hp.assign([int(data.hp[0]), int(data.hp[1])])
	turn = int(data.turn)
	phase = data.phase
	winner = int(data.winner)
	turn_number = int(data.turn_number)
	enemy_id = data.enemy_id
	swapped = data.swapped
	next_uid = int(data.next_uid)
	rng.state = int(data.rng_state)
	return true


static func valid_snapshot(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	for key: String in ["width", "units", "hands", "decks", "discards", "hp", "turn", "phase",
			"winner", "turn_number", "enemy_id", "swapped", "next_uid", "rng_state"]:
		if not data.has(key):
			return false
	if not _integer_range(data.width, 3, 5):
		return false
	if data.width != 3 and data.width != 5:
		return false
	if not _integer_range(data.turn, 0, 1) or not _integer_range(data.winner, -1, 1):
		return false
	if data.phase not in ["standby", "battle", "over"] or not data.swapped is bool:
		return false
	if not data.enemy_id is String or not Catalog.ENEMIES.has(data.enemy_id):
		return false
	if not _integer_range(data.turn_number, 1, 100000) or not _integer_range(data.next_uid, 1, 100000):
		return false
	if not data.rng_state is String or not data.rng_state.is_valid_int():
		return false
	if not data.hp is Array or data.hp.size() != 2:
		return false
	for health: Variant in data.hp:
		if not _integer_range(health, 0, 10):
			return false
	if (data.phase == "over") != (data.winner != -1):
		return false
	if data.winner == -1 and (data.hp[0] == 0 or data.hp[1] == 0):
		return false
	if data.winner != -1 and data.hp[1 - int(data.winner)] != 0:
		return false
	if data.winner != -1 and data.hp[int(data.winner)] == 0:
		return false
	for pile: Variant in [data.hands, data.decks, data.discards]:
		if not pile is Array or pile.size() != 2:
			return false
		for cards: Variant in pile:
			if not Catalog.valid_cards(cards):
				return false
	return _valid_units(data)


static func position(unit: Dictionary) -> Vector2i:
	return Vector2i(unit.x, unit.y)


static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func _integer_range(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and value >= low and value <= high and value == int(value)


static func _valid_units(data: Dictionary) -> bool:
	if not data.units is Array or data.units.size() > int(data.width) * 4:
		return false
	var seen_ids: Array = []
	var seen_cells: Array = []
	for unit: Variant in data.units:
		if not unit is Dictionary:
			return false
		for key: String in ["uid", "card", "side", "x", "y", "face", "moved", "attacked", "effect_used"]:
			if not unit.has(key):
				return false
		if not unit.card is String or not Catalog.CARDS.has(unit.card):
			return false
		if not _integer_range(unit.side, 0, 1):
			return false
		if not _integer_range(unit.uid, 1, int(data.next_uid) - 1) or unit.uid in seen_ids:
			return false
		if not _integer_range(unit.x, 0, int(data.width) - 1) or not _integer_range(unit.y, 0, 3):
			return false
		var cell: Vector2i = Vector2i(unit.x, unit.y)
		if cell in seen_cells:
			return false
		for key: String in ["face", "moved", "attacked", "effect_used"]:
			if not unit[key] is bool:
				return false
		seen_ids.append(unit.uid)
		seen_cells.append(cell)
	return true


func _resolve_duel(unit: Dictionary, target: Dictionary, event: Dictionary) -> void:
	var was_hidden: bool = not target.face
	event.to = position(target)
	target.face = true
	var offense: int = attack_power(unit, true, not was_hidden)
	var defense: int = attack_power(target, false)
	if (was_hidden and _effect(target) == "revenge") or offense == defense:
		_discard(unit, event)
		_discard(target, event)
		return
	var victor: Dictionary = unit if offense > defense else target
	var defeated: Dictionary = target if offense > defense else unit
	var destination: Vector2i = position(defeated)
	var anchored: bool = _effect(defeated) == "anchor"
	_discard(defeated, event)
	if not anchored:
		_set_position(victor, destination)
	if victor == unit and _effect(victor) == "terror":
		hp[1 - turn] = maxi(0, hp[1 - turn] - 1)
		event.damage = 1


func _discard(unit: Dictionary, event: Dictionary) -> void:
	discards[unit.side].append(unit.card)
	event.defeated.append(unit.duplicate())
	units.erase(unit)


func _check_winner() -> void:
	for side: int in range(2):
		if hp[side] <= 0:
			winner = 1 - side
			phase = "over"


func _draw(side: int) -> void:
	if decks[side].is_empty() and not discards[side].is_empty():
		decks[side] = discards[side].duplicate()
		discards[side].clear()
		_shuffle(decks[side])
	if not decks[side].is_empty():
		hands[side].append(decks[side].pop_back())


func _shuffle(cards: Array) -> void:
	for index: int in range(cards.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var held: Variant = cards[index]
		cards[index] = cards[other]
		cards[other] = held


func _standby_unit(unit: Dictionary) -> bool:
	return phase == "standby" and not unit.is_empty() and unit.side == turn


func _set_position(unit: Dictionary, pos: Vector2i) -> void:
	unit.x = pos.x
	unit.y = pos.y


func _effect(unit: Dictionary) -> String:
	return Catalog.CARDS[unit.card].effect


func _rejected() -> Dictionary:
	return {"ok": false, "type": "invalid"}


func _ai_standby() -> Dictionary:
	var preparation: Dictionary = _ai_prepare()
	if not preparation.is_empty():
		return preparation
	var deployment: Dictionary = _ai_deployment()
	if not deployment.is_empty():
		return deploy(deployment.index, deployment.pos)
	if enemy_id in ["general", "final"] and not swapped:
		var exchange: Dictionary = _ai_exchange()
		if not exchange.is_empty():
			return swap_units(exchange.uid, exchange.other)
	for unit: Dictionary in units:
		if unit.side != turn or not unit.face or unit.moved or _has_target(unit.uid):
			continue
		var destination: Vector2i = _ai_destination(unit)
		if destination != position(unit):
			return move_unit(unit.uid, destination)
	return begin_battle()


func _ai_prepare() -> Dictionary:
	var concealed: Array[Dictionary] = []
	for unit: Dictionary in units:
		if unit.side == turn and not unit.face and _effect(unit) != "revenge":
			return reveal(unit.uid)
		if unit.side != turn and not unit.face:
			concealed.append(unit)
	for unit: Dictionary in units:
		if unit.side != turn or not unit.face or unit.effect_used:
			continue
		if _effect(unit) == "reveal" and not concealed.is_empty():
			return use_effect(unit.uid, concealed[0].uid)
		if _effect(unit) == "heal" and hp[turn] < 10:
			return use_effect(unit.uid)
	return {}


func _ai_deployment() -> Dictionary:
	var best_index: int = -1
	var best_power: int = -100
	for index: int in range(hands[turn].size()):
		var power: int = Catalog.CARDS[hands[turn][index]].atk
		if power > best_power:
			best_power = power
			best_index = index
	if best_index == -1:
		return {}
	var best_pos: Vector2i = Vector2i(-1, -1)
	var best_distance: int = 100
	for y: int in range(4):
		for x: int in range(width):
			var pos: Vector2i = Vector2i(x, y)
			if own_zone(turn, pos) and unit_at(pos).is_empty():
				var length: int = distance(pos, king_position(1 - turn))
				if length < best_distance:
					best_distance = length
					best_pos = pos
	return {} if best_pos.x < 0 else {"index": best_index, "pos": best_pos}


func _ai_exchange() -> Dictionary:
	for unit: Dictionary in units:
		if unit.side != turn or not unit.face:
			continue
		for other: Dictionary in units:
			if distance(position(unit), position(other)) != 1:
				continue
			if other.side != turn and _effect(unit) != "infiltrate":
				continue
			if distance(position(other), king_position(1 - turn)) >= distance(
					position(unit), king_position(1 - turn)):
				continue
			if other.side != turn or Catalog.CARDS[unit.card].atk > Catalog.CARDS[other.card].atk:
				return {"uid": unit.uid, "other": other.uid}
	return {}


func _ai_destination(unit: Dictionary) -> Vector2i:
	var best: Vector2i = position(unit)
	var best_distance: int = distance(best, king_position(1 - turn))
	for direction: Vector2i in DIRECTIONS:
		var pos: Vector2i = position(unit) + direction
		if in_board(pos) and unit_at(pos).is_empty():
			var length: int = distance(pos, king_position(1 - turn))
			if length < best_distance:
				best_distance = length
				best = pos
	return best


func _has_target(uid: int) -> bool:
	if can_attack(uid, -1, false):
		return true
	for other: Dictionary in units:
		if can_attack(uid, other.uid, false):
			return true
	return false


func _best_attack() -> Dictionary:
	var best: Dictionary = {}
	var best_score: int = -1000
	for unit: Dictionary in units:
		if can_attack(unit.uid) and attack_power(unit, true) > 0:
			return {"uid": unit.uid, "target": -1}
		for target: Dictionary in units:
			if not can_attack(unit.uid, target.uid):
				continue
			# AI は潜伏札の種類・能力を読み取らず、未知の守備力を2として評価する。
			var defense: int = attack_power(target, false) if target.face else 2
			var score: int = attack_power(unit, true, target.face) - defense
			if score > best_score:
				best_score = score
				best = {"uid": unit.uid, "target": target.uid}
	return best
