extends Node
## 進行操作はプレイヤーの行動を一度ずつ消費するため非冪等。
## UI はこの状態を参照し、戦闘処理は描画やフレーム速度に依存させない。

signal changed
signal effect(kind: String, amount: int)

const Catalog = preload("res://scripts/card_catalog.gd")
const NODE_LABELS: Dictionary = {
	"battle": "戦闘", "elite": "強敵", "rest": "休憩", "event": "遺物の泉", "card": "書庫",
	"boss": "最上階のボス",
}

var phase: String = "title"
var won: bool = false
var floor_index: int = -1
var map_rows: Array[Array] = []
var route: Array[int] = []
var current_kind: String = ""
var seed_value: int = 0
var hp: int = 84
var max_hp: int = 84
var energy: int = 0
var block: int = 0
var strength: int = 0
var weak: int = 0
var vulnerable: int = 0
var armor: int = 0
var draw_bonus: int = 0
var turn: int = 0
var deck: Array[String] = []
var draw_pile: Array[String] = []
var discard_pile: Array[String] = []
var exhaust_pile: Array[String] = []
var hand: Array[String] = []
var relics: Array[String] = []
var reward_cards: Array[String] = []
var enemy: Dictionary = {}
var message: String = ""
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func start_run(run_seed: int = 0) -> bool:
	seed_value = run_seed if run_seed != 0 else int(Time.get_unix_time_from_system())
	_rng.seed = seed_value
	phase = "map"
	won = false
	floor_index = -1
	route.clear()
	hp = max_hp
	deck.assign(["strike", "strike", "strike", "strike", "strike",
		"guard", "guard", "guard", "guard", "fracture"])
	relics.clear()
	reward_cards.clear()
	enemy.clear()
	_clear_battle()
	_build_map()
	message = "枝道を選び、夜の頂を目指そう。"
	changed.emit()
	return true


func return_title() -> bool:
	phase = "title"
	changed.emit()
	return true


func choose_node(index: int) -> bool:
	if phase != "map" or floor_index + 1 >= map_rows.size():
		return false
	var row: Array = map_rows[floor_index + 1]
	if index < 0 or index >= row.size():
		return false
	floor_index += 1
	route.append(index)
	current_kind = row[index].kind
	match current_kind:
		"battle", "elite", "boss":
			_start_battle()
		"card":
			_offer_cards()
			message = "書庫で見つけた技を、ひとつ持っていこう。"
		_:
			phase = current_kind
	changed.emit()
	return true


func play_card(index: int) -> bool:
	if phase != "battle" or index < 0 or index >= hand.size():
		return false
	var id: String = hand[index]
	var card: Dictionary = Catalog.CARDS[id]
	if energy < int(card.cost):
		return false
	energy -= int(card.cost)
	hand.remove_at(index)
	# ドロー効果で使用中のカードを引き直さないよう、効果解決後に山へ移す。
	effect.emit("card", 0)
	var effects: Dictionary = card.effects
	for key: String in effects:
		_apply_effect(key, int(effects[key]))
	if card.get("exhaust", false) or card.type == "power":
		exhaust_pile.append(id)
	else:
		discard_pile.append(id)
	message = "%s を使った。" % card.name
	if int(enemy.hp) <= 0:
		_win_battle()
	changed.emit()
	return true


func end_turn() -> bool:
	if phase != "battle":
		return false
	discard_pile.append_array(hand)
	hand.clear()
	effect.emit("discard", 0)
	weak = maxi(0, weak - 1)
	# 敵の前ターンの防御は、次に敵が行動するまで有効。
	enemy.block = 0
	var intent: Dictionary = enemy.intent
	match String(intent.kind):
		"attack":
			var damage: int = attack_damage(int(intent.amount), int(enemy.strength),
				int(enemy.weak), vulnerable)
			var blocked: int = mini(block, damage)
			block -= blocked
			damage -= blocked
			hp = maxi(0, hp - damage)
			effect.emit("hurt", damage)
		"block":
			enemy.block = int(intent.amount)
		"strength":
			enemy.strength += int(intent.amount)
		"weak":
			weak += int(intent.amount)
		"vulnerable":
			vulnerable += int(intent.amount)
	if intent.kind != "vulnerable":
		vulnerable = maxi(0, vulnerable - 1)
	enemy.weak = maxi(0, int(enemy.weak) - 1)
	enemy.vulnerable = maxi(0, int(enemy.vulnerable) - 1)
	if hp <= 0:
		phase = "result"
		won = false
		message = "灯は消えた。それでも次の旅が待っている。"
	else:
		_start_turn()
	changed.emit()
	return true


func choose_reward(index: int = -1) -> bool:
	if phase != "reward" or index < -1 or index >= reward_cards.size():
		return false
	if index >= 0:
		deck.append(reward_cards[index])
	reward_cards.clear()
	phase = "map"
	message = "次の枝道を選ぼう。"
	changed.emit()
	return true


func rest() -> bool:
	if phase != "rest":
		return false
	var healed: int = mini(max_hp - hp, 26)
	hp += healed
	phase = "map"
	message = "焚き火で HP を%d回復した。" % healed
	changed.emit()
	return true


func resolve_event() -> bool:
	if phase != "event":
		return false
	_gain_relic()
	phase = "map"
	changed.emit()
	return true


static func attack_damage(base: int, power: int, attacker_weak: int, target_vulnerable: int) -> int:
	var amount: float = maxi(0, base + power)
	if attacker_weak > 0:
		amount *= 0.75
	if target_vulnerable > 0:
		amount *= 1.5
	return floori(amount)


func intent_text() -> String:
	if enemy.is_empty():
		return ""
	var intent: Dictionary = enemy.intent
	var amount: int = int(intent.amount)
	if intent.kind == "attack":
		return "攻撃 %d" % attack_damage(amount, int(enemy.strength), int(enemy.weak),
			vulnerable)
	var labels: Dictionary = {"block": "防御 %d", "strength": "筋力 +%d",
		"weak": "弱体 %d", "vulnerable": "脆弱 %d"}
	return labels[intent.kind] % amount


func _build_map() -> void:
	map_rows.clear()
	var kinds: Array[Array] = [["battle", "battle"], ["card", "event", "battle"],
		["battle", "elite", "rest"], ["rest", "card", "event"],
		["elite", "battle", "card"], ["event", "battle", "rest"],
		["rest", "elite"], ["boss"]]
	for row: Array in kinds:
		var nodes: Array = []
		for kind: String in row:
			nodes.append({"kind": kind, "label": NODE_LABELS[kind]})
		# 層内だけを混ぜ、必要なノード種とボスの到達可能性は維持する。
		for index: int in range(nodes.size() - 1, 0, -1):
			var swap: int = _rng.randi_range(0, index)
			var value: Dictionary = nodes[index]
			nodes[index] = nodes[swap]
			nodes[swap] = value
		map_rows.append(nodes)


func _clear_battle() -> void:
	draw_pile.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	hand.clear()
	block = 0
	energy = 0
	strength = 0
	weak = 0
	vulnerable = 0
	armor = 0
	draw_bonus = 0
	turn = 0


func _start_battle() -> void:
	_clear_battle()
	phase = "battle"
	var ids: Array[String] = ["moth", "sentinel", "brute"]
	var id: String = "boss" if current_kind == "boss" else ids[_rng.randi_range(0, 2)]
	var definition: Dictionary = Catalog.ENEMIES[id]
	var health: int = int(definition.hp) + floor_index * 2
	if current_kind == "elite":
		health += 14
	enemy = {"id": id, "name": definition.name, "hp": health, "max_hp": health,
		"block": 0, "strength": 2 if current_kind == "elite" else 0,
		"weak": 0, "vulnerable": 0, "intent": {}}
	for relic: String in relics:
		strength += int(Catalog.RELICS[relic].get("strength", 0))
		armor += int(Catalog.RELICS[relic].get("armor", 0))
	draw_pile.assign(deck)
	_shuffle(draw_pile)
	_start_turn()
	message = "敵の意図を見て、攻めるか守るか決めよう。"


func _start_turn() -> void:
	turn += 1
	energy = 3
	block = armor
	_draw(5 + draw_bonus)
	var moves: Array = Catalog.ENEMIES[enemy.id].moves
	enemy.intent = moves[(turn - 1) % moves.size()].duplicate()


func _draw(count: int) -> void:
	for _index: int in range(count):
		if draw_pile.is_empty():
			draw_pile.assign(discard_pile)
			discard_pile.clear()
			_shuffle(draw_pile)
		if draw_pile.is_empty():
			break
		hand.append(draw_pile.pop_back())
	effect.emit("draw", count)


func _shuffle(pile: Array[String]) -> void:
	for index: int in range(pile.size() - 1, 0, -1):
		var swap: int = _rng.randi_range(0, index)
		var value: String = pile[index]
		pile[index] = pile[swap]
		pile[swap] = value


func _apply_effect(key: String, amount: int) -> void:
	match key:
		"damage":
			var damage: int = attack_damage(amount, strength, weak, int(enemy.vulnerable))
			var blocked: int = mini(int(enemy.block), damage)
			enemy.block -= blocked
			damage -= blocked
			enemy.hp = maxi(0, int(enemy.hp) - damage)
			effect.emit("attack", damage)
		"block":
			block += amount
			effect.emit("block", amount)
		"draw":
			_draw(amount)
		"heal":
			hp = mini(max_hp, hp + amount)
		"energy":
			energy += amount
		"weak", "vulnerable":
			enemy[key] += amount
		"strength":
			strength += amount
		"armor":
			armor += amount
		"draw_bonus":
			draw_bonus += amount


func _win_battle() -> void:
	for relic: String in relics:
		hp = mini(max_hp, hp + int(Catalog.RELICS[relic].get("heal", 0)))
	if current_kind == "boss":
		phase = "result"
		won = true
		message = "巨像の夜がほどけ、頂に朝が訪れた。"
		return
	message = "勝利！ 新たなカードを1枚選べる。"
	if current_kind == "elite":
		_gain_relic()
	_offer_cards()


func _offer_cards() -> void:
	phase = "reward"
	reward_cards.clear()
	var pool: Array[String] = []
	for id: String in Catalog.CARDS:
		if Catalog.CARDS[id].rarity != "基本":
			pool.append(id)
	_shuffle(pool)
	for index: int in range(3):
		reward_cards.append(pool[index])


func _gain_relic() -> void:
	var pool: Array[String] = []
	for id: String in Catalog.RELICS:
		if not relics.has(id):
			pool.append(id)
	if pool.is_empty():
		hp = mini(max_hp, hp + 12)
		message = "すべての遺物が揃っている。泉で HP を12回復。"
		return
	var id: String = pool[_rng.randi_range(0, pool.size() - 1)]
	relics.append(id)
	message = "遺物「%s」を得た。%s" % [Catalog.RELICS[id].name, Catalog.RELICS[id].text]
