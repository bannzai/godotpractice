class_name SpiritBoard
extends RefCounted
## 戦闘の状態。合法性の判定はプレイヤーとCPUで共用する。
## 操作関数は1回の手を進めるため非冪等。UIは返り値のokがtrueの時だけ演出する。

const Catalog: Script = preload("res://scripts/card_catalog.gd")

var width: int = 3
var units: Array[Dictionary] = []
var hands: Array = [[], []]
var draw_piles: Array = [[], []]
var discards: Array = [[], []]
var kings: Array[int] = [10, 10]
var max_kings: Array[int] = [10, 10]
var turn: int = 0
var phase: String = "prepare"
var winner: int = -1
var turn_number: int = 1
var enemy_id: String = "ghost"
var darkness: int = 0
var deployed: bool = false
var next_uid: int = 1
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(deck: Array, board_width: int, battle_seed: int,
		health: int = 10, dark: int = 0, opponent: String = "ghost") -> void:
	width = 5 if board_width >= 5 else 3
	units.clear()
	hands = [[], []]
	draw_piles = [deck.duplicate(), []]
	discards = [[], []]
	darkness = clampi(dark, 0, 100)
	max_kings = [8 if darkness >= 80 else 10, 10]
	kings = [clampi(health, 1, max_kings[0]), 10]
	turn = 0
	phase = "prepare"
	winner = -1
	turn_number = 1
	next_uid = 1
	deployed = false
	enemy_id = opponent
	rng.seed = battle_seed
	# 敵も8枚から開始。通常の相手は支援札が中心で、先手の進軍を止め切らない。
	draw_piles[1] = ["bell", "willow", "bell", "willow", "bell", "lantern", "crow", "bell"]
	if opponent == "general":
		draw_piles[1] = ["bell", "monk", "lantern", "fox", "bell", "mask", "bell", "willow"]
	elif opponent == "police":
		draw_piles[1] = ["monk", "bell", "lantern", "bell", "crow", "willow", "bell", "fox"]
	_shuffle(draw_piles[0])
	_shuffle(draw_piles[1])
	for side: int in range(2):
		for _card: int in range(3):
			_draw(side)


func at(pos: int) -> Dictionary:
	for unit: Dictionary in units:
		if int(unit.pos) == pos:
			return unit
	return {}


func effective_atk(pos: int, defending_hidden: bool = false) -> int:
	var unit: Dictionary = at(pos)
	if unit.is_empty():
		return 0
	var info: Dictionary = Catalog.card(str(unit.card))
	var power: int = int(info.atk)
	if int(unit.side) == 0 and darkness >= 50:
		power += 1
	if str(info.effect) == "ambush" and defending_hidden:
		power += 2
	if str(info.effect) == "ward" and pos / width == (3 if int(unit.side) == 0 else 0):
		power += 1
	for ally: Dictionary in units:
		if int(ally.side) == int(unit.side) and bool(ally.face) and _adjacent(pos, int(ally.pos)):
			if str(Catalog.card(str(ally.card)).effect) == "aura":
				power += 1
	return power


func can_deploy(pos: int) -> bool:
	if winner != -1 or phase != "prepare" or deployed or not _inside(pos):
		return false
	return at(pos).is_empty() and (pos / width >= 2 if turn == 0 else pos / width < 2)


func deploy(hand_index: int, pos: int, face: bool = true) -> Dictionary:
	if hand_index < 0 or hand_index >= hands[turn].size() or not can_deploy(pos):
		return _invalid("自陣の空きマスへ、1ターンに1枚置けます。")
	var card_id: String = str(hands[turn].pop_at(hand_index))
	var unit: Dictionary = {"uid": next_uid, "card": card_id, "side": turn, "pos": pos,
		"face": face, "moved": false, "attacked": false, "flipped": false}
	next_uid += 1
	units.append(unit)
	deployed = true
	if face:
		_reveal_effect(unit)
	return {"ok": true, "type": "deploy", "to": pos, "card": card_id,
		"side": turn, "text": "%sが%s。" % [Catalog.card(card_id).name, "登場" if face else "潜伏"]}


func move_unit(from: int, to: int) -> Dictionary:
	var unit: Dictionary = at(from)
	if not _can_prepare(unit) or bool(unit.moved) or not _inside(to) or not _adjacent(from, to):
		return _invalid("移動は隣のマスへ。動いた霊はこのターン攻撃できません。")
	var target: Dictionary = at(to)
	if target.is_empty() and not bool(unit.face):
		return _invalid("潜伏中の霊は登場すると移動できます。")
	if not target.is_empty() and (int(target.side) != turn or bool(target.moved)):
		return _invalid("相手がいるマスには移動できません。攻撃を選んでください。")
	unit.pos = to
	unit.moved = true
	if not target.is_empty():
		target.pos = from
		target.moved = true
	return {"ok": true, "type": "move", "from": from, "to": to,
		"card": unit.card, "side": turn, "text": "配置を変えた。この霊は次のターンから攻撃できる。"}


func flip_unit(pos: int) -> Dictionary:
	var unit: Dictionary = at(pos)
	if not _can_prepare(unit) or bool(unit.flipped):
		return _invalid("登場・潜伏は準備中、各霊1回ずつです。")
	unit.face = not bool(unit.face)
	unit.flipped = true
	if bool(unit.face):
		_reveal_effect(unit)
	return {"ok": true, "type": "flip", "to": pos, "card": unit.card,
		"side": turn, "text": "%sが%s。" % [Catalog.card(str(unit.card)).name,
			"登場" if bool(unit.face) else "潜伏"]}


func legal_targets(pos: int) -> Array[int]:
	var targets: Array[int] = []
	var unit: Dictionary = at(pos)
	if not _can_attack(unit):
		return targets
	for target: Dictionary in units:
		if int(target.side) != turn and _adjacent(pos, int(target.pos)):
			targets.append(int(target.pos))
	if pos == _king_neighbor(1 - turn):
		targets.append(-2 if turn == 0 else -1)
	return targets


func attack(from: int, to: int) -> Dictionary:
	if to not in legal_targets(from):
		return _invalid("登場していて、まだ動いていない霊が隣へ攻撃できます。")
	phase = "battle"
	var attacker: Dictionary = at(from)
	attacker.attacked = true
	var power: int = effective_atk(from)
	var outcome: Dictionary = {"ok": true, "type": "attack", "from": from,
		"to": to, "card": attacker.card, "side": turn, "removed": []}
	if to < 0:
		var victim: int = 1 - turn
		if str(Catalog.card(str(attacker.card)).effect) == "siege":
			power += 1
		kings[victim] = maxi(0, kings[victim] - power)
		outcome.type = "king_hit"
		outcome.damage = power
		outcome.text = "王に%dの傷を与えた。" % power
		if kings[victim] == 0:
			winner = turn
		return outcome
	var defender: Dictionary = at(to)
	var was_hidden: bool = not bool(defender.face)
	var defense: int = effective_atk(to, was_hidden)
	defender.face = true
	# 攻撃で暴かれた時も登場効果を発動し、比較値は宣言時点で固定する。
	if was_hidden:
		_reveal_effect(defender)
	var revenge: bool = was_hidden and str(Catalog.card(str(defender.card)).effect) == "revenge"
	if power >= defense:
		outcome.removed.append(defender.duplicate())
		_remove(defender)
	if power <= defense or revenge:
		outcome.removed.append(attacker.duplicate())
		_remove(attacker)
	elif power > defense:
		attacker.pos = to
	if power < defense:
		defender.pos = from
	outcome.damage = power
	outcome.text = "%d 対 %d。%s" % [power, defense,
		"両者が霧に還った。" if outcome.removed.size() == 2 else "勝った霊が進む。"]
	return outcome


func end_turn() -> Dictionary:
	if winner != -1:
		return _invalid("戦いは終わりました。")
	turn = 1 - turn
	turn_number += 1
	phase = "prepare"
	deployed = false
	for unit: Dictionary in units:
		if int(unit.side) == turn:
			unit.moved = false
			unit.attacked = false
			unit.flipped = false
	_draw(turn)
	return {"ok": true, "type": "turn", "side": turn, "text": "あなたの手番。" if turn == 0 else "相手の手番。"}


func cpu_turn() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	while turn == 1 and winner == -1:
		events.append(cpu_step())
	return events


func cpu_step() -> Dictionary:
	if turn != 1 or winner != -1:
		return _invalid("今は相手の手番ではありません。")
	if phase == "prepare":
		return _cpu_prepare_step()
	for unit: Dictionary in units:
		if int(unit.side) == 1:
			var targets: Array[int] = legal_targets(int(unit.pos))
			if not targets.is_empty():
				return attack(int(unit.pos), targets[0])
	return end_turn()


func _cpu_prepare_step() -> Dictionary:
	# 手札の先頭を使い、最短距離を優先する。隠れた霊の種類は参照しない。
	var center: int = width / 2
	var places: Array[int] = [width + center, center]
	for pos: int in range(width * 2):
		if pos not in places:
			places.append(pos)
	for pos: int in places:
		if not hands[1].is_empty() and can_deploy(pos):
			return deploy(0, pos, true)
	for unit: Dictionary in units:
		if int(unit.side) != 1:
			continue
		var pos: int = int(unit.pos)
		if not bool(unit.face) and not bool(unit.flipped):
			return flip_unit(pos)
		if not legal_targets(pos).is_empty() or bool(unit.moved) or not bool(unit.face):
			continue
		var step: int = pos + width if pos / width < 3 else pos + signi(center - pos % width)
		if step != pos and _inside(step) and at(step).is_empty():
			return move_unit(pos, step)
	phase = "battle"
	return {"ok": true, "type": "phase", "side": 1, "text": "相手が攻撃に移る。"}


func to_data() -> Dictionary:
	return {"width": width, "units": units.duplicate(true), "hands": hands.duplicate(true),
		"draw_piles": draw_piles.duplicate(true), "discards": discards.duplicate(true),
		"kings": kings.duplicate(), "max_kings": max_kings.duplicate(), "turn": turn,
		"phase": phase, "winner": winner, "turn_number": turn_number, "enemy_id": enemy_id,
		"darkness": darkness, "deployed": deployed, "next_uid": next_uid, "rng_state": str(rng.state)}


func restore(data: Dictionary) -> bool:
	if not _valid_data(data):
		return false
	width = int(data.width)
	units.assign(data.units.duplicate(true))
	for unit: Dictionary in units:
		for key: String in ["uid", "pos", "side"]:
			unit[key] = int(unit[key])
	hands = data.hands.duplicate(true)
	draw_piles = data.draw_piles.duplicate(true)
	discards = data.discards.duplicate(true)
	kings.assign(data.kings)
	max_kings.assign(data.max_kings)
	turn = int(data.turn)
	phase = str(data.phase)
	winner = int(data.winner)
	turn_number = int(data.turn_number)
	enemy_id = str(data.enemy_id)
	darkness = int(data.darkness)
	deployed = bool(data.deployed)
	next_uid = int(data.next_uid)
	rng.state = int(data.rng_state)
	return true


func _can_prepare(unit: Dictionary) -> bool:
	return winner == -1 and phase == "prepare" and not unit.is_empty() and int(unit.side) == turn


func _can_attack(unit: Dictionary) -> bool:
	return winner == -1 and not unit.is_empty() and int(unit.side) == turn \
		and bool(unit.face) and not bool(unit.moved) and not bool(unit.attacked)


func _inside(pos: int) -> bool:
	return pos >= 0 and pos < width * 4


func _adjacent(first: int, second: int) -> bool:
	return absi(first % width - second % width) + absi(first / width - second / width) == 1


func _king_neighbor(side: int) -> int:
	return width / 2 + (width * 3 if side == 0 else 0)


func _invalid(reason: String) -> Dictionary:
	return {"ok": false, "type": "invalid", "text": reason}


func _remove(unit: Dictionary) -> void:
	discards[int(unit.side)].append(str(unit.card))
	units.erase(unit)


func _draw(side: int) -> void:
	if hands[side].size() >= 8:
		return
	if draw_piles[side].is_empty() and not discards[side].is_empty():
		draw_piles[side] = discards[side].duplicate()
		discards[side].clear()
		_shuffle(draw_piles[side])
	if not draw_piles[side].is_empty():
		hands[side].append(draw_piles[side].pop_back())


func _shuffle(cards: Array) -> void:
	for index: int in range(cards.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var card_id: String = str(cards[index])
		cards[index] = cards[other]
		cards[other] = card_id


func _reveal_effect(unit: Dictionary) -> void:
	var side: int = int(unit.side)
	match str(Catalog.card(str(unit.card)).effect):
		"heal":
			kings[side] = mini(max_kings[side], kings[side] + 1)
		"draw":
			_draw(side)
		"veil":
			var closest: Dictionary = {}
			var distance: int = 100
			for target: Dictionary in units:
				var target_distance: int = absi(int(target.pos) % width - int(unit.pos) % width) \
					+ absi(int(target.pos) / width - int(unit.pos) / width)
				if int(target.side) != side and bool(target.face) and target_distance < distance:
					closest = target
					distance = target_distance
			if not closest.is_empty():
				closest.face = false


func _valid_data(data: Dictionary) -> bool:
	for key: String in ["width", "units", "hands", "draw_piles", "discards", "kings",
			"max_kings", "turn", "phase", "winner", "turn_number", "enemy_id", "darkness",
			"deployed", "next_uid", "rng_state"]:
		if not data.has(key):
			return false
	for key: String in ["width", "turn", "winner", "turn_number", "darkness", "next_uid"]:
		if not _is_integer(data[key]):
			return false
	if not data.rng_state is String or not data.rng_state.is_valid_int():
		return false
	var valid_scalars: bool = int(data.width) in [3, 5] and int(data.turn) in [0, 1] \
		and str(data.phase) in ["prepare", "battle"] and int(data.winner) in [-1, 0, 1] \
		and str(data.enemy_id) in Catalog.ENEMIES and int(data.darkness) in range(101) \
		and int(data.turn_number) > 0 and int(data.next_uid) > 0 and data.deployed is bool
	return valid_scalars and _valid_piles(data) and _valid_units(data) and _valid_kings(data)


func _valid_piles(data: Dictionary) -> bool:
	for pile_key: String in ["hands", "draw_piles", "discards"]:
		if not data[pile_key] is Array or data[pile_key].size() != 2:
			return false
		for pile: Variant in data[pile_key]:
			if not pile is Array or pile.size() > 100:
				return false
			for card_id: Variant in pile:
				if not card_id is String or card_id not in Catalog.CARDS:
					return false
	for king_key: String in ["kings", "max_kings"]:
		if not data[king_key] is Array or data[king_key].size() != 2:
			return false
		for health: Variant in data[king_key]:
			if not _is_integer(health) or int(health) < 0 or int(health) > 10:
				return false
	return true


func _valid_units(data: Dictionary) -> bool:
	if not data.units is Array or data.units.size() > int(data.width) * 4:
		return false
	var positions: Array[int] = []
	var identifiers: Array[int] = []
	for unit: Variant in data.units:
		if not _valid_unit(unit):
			return false
		if int(unit.pos) < 0 or int(unit.pos) >= int(data.width) * 4 \
				or int(unit.pos) in positions or int(unit.uid) in identifiers \
				or int(unit.uid) >= int(data.next_uid):
			return false
		positions.append(int(unit.pos))
		identifiers.append(int(unit.uid))
	return true


func _valid_unit(unit: Variant) -> bool:
	if not unit is Dictionary:
		return false
	for key: String in ["uid", "card", "side", "pos", "face", "moved", "attacked", "flipped"]:
		if not unit.has(key):
			return false
	for key: String in ["uid", "side", "pos"]:
		if not _is_integer(unit[key]):
			return false
	for key: String in ["face", "moved", "attacked", "flipped"]:
		if not unit[key] is bool:
			return false
	return str(unit.card) in Catalog.CARDS and int(unit.side) in [0, 1] and int(unit.uid) > 0


func _is_integer(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))


func _valid_kings(data: Dictionary) -> bool:
	if int(data.max_kings[0]) != (8 if int(data.darkness) >= 80 else 10) \
			or int(data.max_kings[1]) != 10:
		return false
	for side: int in range(2):
		if int(data.kings[side]) > int(data.max_kings[side]):
			return false
	if int(data.winner) == -1:
		return int(data.kings[0]) > 0 and int(data.kings[1]) > 0
	return int(data.kings[1 - int(data.winner)]) == 0
