class_name DuelState
extends RefCounted
## 決闘の状態。公開コマンドは入力に対応して状態を進めるため非冪等。

const Catalog = preload("res://scripts/card_catalog.gd")

var players: Array[Dictionary] = []
var turn_player: int = 0
var phase: String = "draw"
var turn: int = 1
var winner: int = -1
var message: String = ""
var events: Array[Dictionary] = []
var summoned: bool = false


func start(deck_index: int, random_seed: int = 1) -> bool:
	players.clear()
	events.clear()
	turn_player = 0
	phase = "draw"
	turn = 1
	winner = -1
	summoned = false
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = random_seed
	for index: int in range(2):
		var pile: Array[String] = Catalog.deck(deck_index if index == 0 else 1 - deck_index)
		for cursor: int in range(pile.size() - 1, 0, -1):
			var other: int = random.randi_range(0, cursor)
			var id: String = pile[cursor]
			pile[cursor] = pile[other]
			pile[other] = id
		players.append({"life": 8000, "deck": pile, "hand": [], "monsters": [],
			"spells": [], "grave": []})
		for _number: int in range(5):
			_draw(index)
	message = "決闘開始。ドローフェイズから進めよう。"
	return true


# 次のフェイズへの入力を毎回適用するため非冪等。
func advance_phase() -> bool:
	events.clear()
	if winner != -1 or players.is_empty():
		return false
	match phase:
		"draw":
			_draw(turn_player)
			if winner != -1:
				return true
			phase = "main"
			message = "メイン：召喚・魔法・罠のセットができる。"
		"main":
			phase = "end" if turn == 1 else "battle"
			message = "先攻の最初のターンは攻撃できない。" if turn == 1 else "バトル：モンスターで攻撃！"
		"battle":
			phase = "end"
			message = "エンド：次へ進むと相手のターン。"
		"end":
			_begin_turn()
			message = "新しいターン。１枚ドローしよう。"
	return true


# 召喚の入力ごとに手札を消費するため非冪等。
func summon(hand_index: int, defense: bool = false) -> bool:
	events.clear()
	if not _can_play(hand_index, "monster") or summoned or players[turn_player].monsters.size() >= 5:
		return false
	var id: String = players[turn_player].hand.pop_at(hand_index)
	players[turn_player].monsters.append({"id": id, "defense": defense,
		"attacked": false, "boost": 0, "changed": false})
	summoned = true
	events.append({"type": "summon", "player": turn_player, "id": id})
	message = "%s を%s表示で召喚。" % [Catalog.card(id).name, "守備" if defense else "攻撃"]
	return true


# 発動ごとにカードを消費し効果を適用するため非冪等。
func play_spell(hand_index: int, target: int = -1) -> bool:
	events.clear()
	if not _can_play(hand_index, "spell"):
		return false
	var id: String = players[turn_player].hand[hand_index]
	var effect: String = Catalog.card(id).effect
	var owner: int = 1 - turn_player if effect == "destroy" else turn_player
	if effect != "draw":
		if target == -1:
			target = _strongest(owner)
		if target < 0 or target >= players[owner].monsters.size():
			return false
	players[turn_player].hand.remove_at(hand_index)
	players[turn_player].grave.append(id)
	events.append({"type": "spell", "player": turn_player, "id": id})
	match effect:
		"draw":
			_draw(turn_player)
			if winner == -1:
				_draw(turn_player)
		"destroy":
			_destroy(owner, target)
		"boost":
			players[turn_player].monsters[target].boost += 700
	if winner == -1:
		message = "%s を発動。" % Catalog.card(id).name
	return true


# セットの入力ごとに手札を場へ移すため非冪等。
func set_trap(hand_index: int) -> bool:
	events.clear()
	if not _can_play(hand_index, "trap") or players[turn_player].spells.size() >= 5:
		return false
	var id: String = players[turn_player].hand.pop_at(hand_index)
	players[turn_player].spells.append(id)
	events.append({"type": "set", "player": turn_player, "id": id})
	message = "罠を伏せた。相手の攻撃時に自動発動する。"
	return true


# 表示変更の入力に対応して反転するため非冪等。
func change_position(index: int) -> bool:
	events.clear()
	if winner != -1 or phase != "main" or not _valid_monster(turn_player, index):
		return false
	var monster: Dictionary = players[turn_player].monsters[index]
	if monster.changed or monster.attacked:
		return false
	monster.defense = not monster.defense
	monster.changed = true
	message = "%s を%s表示に変更。" % [Catalog.card(monster.id).name, "守備" if monster.defense else "攻撃"]
	return true


# 攻撃の入力ごとに戦闘と罠を解決するため非冪等。
func attack(attacker: int, target: int = -1) -> bool:
	events.clear()
	if winner != -1 or phase != "battle" or turn == 1 or not _valid_monster(turn_player, attacker):
		return false
	var monster: Dictionary = players[turn_player].monsters[attacker]
	if monster.defense or monster.attacked:
		return false
	var enemy: int = 1 - turn_player
	if not players[enemy].monsters.is_empty() and not _valid_monster(enemy, target):
		return false
	monster.attacked = true
	events.append({"type": "attack", "player": turn_player, "id": monster.id, "target": target})
	message = "%s の攻撃！" % Catalog.card(monster.id).name
	if _trigger_trap(enemy, attacker) or winner != -1:
		return true
	if players[enemy].monsters.is_empty():
		_damage(enemy, power(monster))
	else:
		_resolve_battle(attacker, target)
	return true


func power(monster: Dictionary) -> int:
	return maxi(0, int(Catalog.card(monster.id).attack) + int(monster.boost))


# 呼出しごとにCPUの次の行動を１つ実行するため非冪等。
func cpu_step() -> bool:
	if winner != -1 or turn_player != 1:
		return false
	if phase == "main":
		return _cpu_main()
	if phase == "battle":
		return _cpu_battle()
	return advance_phase()


func _can_play(index: int, kind: String) -> bool:
	return winner == -1 and phase == "main" and not players.is_empty() \
		and index >= 0 and index < players[turn_player].hand.size() \
		and Catalog.card(players[turn_player].hand[index]).type == kind


func _valid_monster(owner: int, index: int) -> bool:
	return owner >= 0 and owner < players.size() and index >= 0 \
		and index < players[owner].monsters.size()


func _strongest(owner: int) -> int:
	var best: int = -1
	for index: int in players[owner].monsters.size():
		if best == -1 or power(players[owner].monsters[index]) > power(players[owner].monsters[best]):
			best = index
	return best


# 内部の状態変更関数は、１回の操作が１回の決闘イベントになるため非冪等。
func _draw(owner: int) -> void:
	if players[owner].deck.is_empty():
		winner = 1 - owner
		message = "デッキが尽きた！"
		events.append({"type": "finish", "player": winner})
		return
	var id: String = players[owner].deck.pop_back()
	players[owner].hand.append(id)
	events.append({"type": "draw", "player": owner, "id": id})


# ターン終了のたびに手番を切り替えるため非冪等。
func _begin_turn() -> void:
	for player: Dictionary in players:
		for monster: Dictionary in player.monsters:
			monster.boost = 0
			monster.attacked = false
			monster.changed = false
	turn_player = 1 - turn_player
	turn += 1
	phase = "draw"
	summoned = false


# 破壊イベントごとに対象を場から取り除くため非冪等。
func _destroy(owner: int, index: int) -> void:
	var id: String = players[owner].monsters[index].id
	players[owner].monsters.remove_at(index)
	players[owner].grave.append(id)
	events.append({"type": "destroy", "player": owner, "id": id, "target": index})


# ダメージイベントごとにライフを減らすため非冪等。
func _damage(owner: int, amount: int) -> void:
	players[owner].life = maxi(0, int(players[owner].life) - amount)
	events.append({"type": "damage", "player": owner, "amount": amount})
	if players[owner].life <= 0:
		winner = 1 - owner
		events.append({"type": "finish", "player": winner})


# 攻撃宣言のたびに伏せ罠を１枚消費するため非冪等。
func _trigger_trap(owner: int, attacker: int) -> bool:
	if players[owner].spells.is_empty():
		return false
	var id: String = players[owner].spells.pop_front()
	players[owner].grave.append(id)
	events.append({"type": "trap", "player": owner, "id": id})
	message = "%s が発動！" % Catalog.card(id).name
	match Catalog.card(id).effect:
		"destroy":
			_destroy(turn_player, attacker)
			return true
		"weaken":
			players[turn_player].monsters[attacker].boost -= 800
		"damage":
			_damage(turn_player, 1000)
	return false


# 戦闘ごとに破壊とダメージを反映するため非冪等。
func _resolve_battle(attacker: int, target: int) -> void:
	var enemy: int = 1 - turn_player
	var offense: int = power(players[turn_player].monsters[attacker])
	var defender: Dictionary = players[enemy].monsters[target]
	var resistance: int = int(Catalog.card(defender.id).defense) \
		if defender.defense else power(defender)
	var difference: int = offense - resistance
	if defender.defense:
		if difference > 0:
			_destroy(enemy, target)
		elif difference < 0:
			_damage(turn_player, -difference)
	elif difference > 0:
		_destroy(enemy, target)
		_damage(enemy, difference)
	elif difference < 0:
		_destroy(turn_player, attacker)
		_damage(turn_player, -difference)
	else:
		_destroy(enemy, target)
		_destroy(turn_player, attacker)


# CPUの意思決定ごとに１回の行動を適用するため非冪等。
func _cpu_main() -> bool:
	# ドロー → 敵の最大攻撃力を破壊 → 最大攻撃力を召喚 → 強化 → 罠 の順。
	for effect: String in ["draw", "destroy"]:
		for index: int in players[1].hand.size():
			if players[1].hand[index] == effect and play_spell(index):
				return true
	if not summoned and players[1].monsters.size() < 5:
		var best: int = -1
		for index: int in players[1].hand.size():
			var card: Dictionary = Catalog.card(players[1].hand[index])
			if card.type == "monster" and (best == -1 \
				or card.attack > Catalog.card(players[1].hand[best]).attack):
				best = index
		if best != -1:
			return summon(best)
	for index: int in players[1].hand.size():
		if players[1].hand[index] == "boost" and play_spell(index):
			return true
	for index: int in players[1].hand.size():
		if Catalog.card(players[1].hand[index]).type == "trap" and set_trap(index):
			return true
	for index: int in players[1].monsters.size():
		if players[1].monsters[index].defense and change_position(index):
			return true
	return advance_phase()


# CPUの意思決定ごとに１回の攻撃を適用するため非冪等。
func _cpu_battle() -> bool:
	for index: int in players[1].monsters.size():
		var monster: Dictionary = players[1].monsters[index]
		if monster.attacked or monster.defense:
			continue
		if players[0].monsters.is_empty():
			return attack(index)
		var target: int = -1
		var weakest: int = 100000
		for candidate: int in players[0].monsters.size():
			var defender: Dictionary = players[0].monsters[candidate]
			var resistance: int = int(Catalog.card(defender.id).defense) \
				if defender.defense else power(defender)
			if resistance < weakest and resistance <= power(monster):
				target = candidate
				weakest = resistance
		if target != -1:
			return attack(index, target)
	return advance_phase()
