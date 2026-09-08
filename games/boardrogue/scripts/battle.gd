extends RefCounted

const CARDS: Dictionary = {
	"scout": {"name": "灯火の斥候", "cost": 1, "power": 1, "text": "軽い歩みで盤をひらく", "kind": "normal", "rare": false},
	"blade": {"name": "銅の剣士", "cost": 1, "power": 2, "text": "小さな代価で確かな一撃", "kind": "normal", "rare": false},
	"spear": {"name": "薄明の槍兵", "cost": 2, "power": 3, "text": "攻守に優れた前衛", "kind": "normal", "rare": false},
	"archer": {"name": "月弓の射手", "cost": 2, "power": 2, "text": "射撃：同列を攻撃し、勝っても移動しない", "kind": "ranged", "rare": false},
	"bulwark": {"name": "石壁の番人", "cost": 2, "power": 2, "text": "守護：防御時の戦力＋1", "kind": "guard", "rare": false},
	"shade": {"name": "影縫い", "cost": 2, "power": 2, "text": "奇襲：伏せ札への攻撃で戦力＋2", "kind": "assassin", "rare": false},
	"mender": {"name": "灯の癒し手", "cost": 1, "power": 1, "text": "治癒：表になると王の体力を1回復", "kind": "healer", "rare": false},
	"knight": {"name": "黒鉄の騎士", "cost": 3, "power": 4, "text": "盤を押し進める重い刃", "kind": "normal", "rare": false},
	"sentinel": {"name": "蒼玉の守護者", "cost": 3, "power": 3, "text": "守護：防御時の戦力＋1", "kind": "guard", "rare": true},
	"oracle": {"name": "星読みの弓", "cost": 3, "power": 3, "text": "射撃：同列を攻撃し、勝っても移動しない", "kind": "ranged", "rare": true},
	"champion": {"name": "夜明けの覇者", "cost": 3, "power": 5, "text": "揺るがぬ最大戦力", "kind": "normal", "rare": true},
	"dragon": {"name": "灰翼の竜", "cost": 3, "power": 4, "text": "奇襲：伏せ札への攻撃で戦力＋2", "kind": "assassin", "rare": true},
}

var width: int = 3
var board: Array[Dictionary] = []
var hands: Array = [[], []]
var decks: Array = [[], []]
var discards: Array = [[], []]
var hp: Array[int] = [10, 10]
var turn: int = 0
var phase: String = "prepare"
var round_number: int = 1
var winner: int = -1
var log_text: String = ""
var events: Array[Dictionary] = []
var energy: int = 3
var swapped: bool = false
const MAX_HP: int = 10
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func setup(columns: int, player_deck: Array[String], enemy_deck: Array[String], seed_value: int, player_hp: int = 10) -> void:
	width = 5 if columns == 5 else 3
	_rng.seed = seed_value
	board.clear()
	for cell: int in range(width * 2):
		board.append({})
	hands = [[], []]
	decks = [player_deck.duplicate(), enemy_deck.duplicate()]
	discards = [[], []]
	hp = [clampi(player_hp, 1, MAX_HP), MAX_HP]
	turn = 0
	phase = "prepare"
	round_number = 1
	winner = -1
	energy = 3
	swapped = false
	events.clear()
	for side: int in range(2):
		_shuffle(decks[side])
		for count: int in range(3):
			_draw(side)
	log_text = "あなたの手番。札を伏せて配置し、攻撃へ"

func own_row(side: int) -> int:
	return 1 - side

func card_power(cell: int) -> int:
	return int(CARDS[board[cell].id].power) if _occupied(cell) else 0

# 手番内の資源を消費するゲーム操作なので非冪等。
func deploy(hand_index: int, cell: int) -> bool:
	if phase != "prepare" or winner != -1 or not _valid(cell) or not board[cell].is_empty():
		return false
	if cell / width != own_row(turn) or hand_index < 0 or hand_index >= hands[turn].size():
		return false
	var id: String = hands[turn][hand_index]
	if not CARDS.has(id) or int(CARDS[id].cost) > energy:
		return false
	energy -= int(CARDS[id].cost)
	hands[turn].remove_at(hand_index)
	board[cell] = {"id": id, "side": turn, "face": false, "moved": false, "attacked": false}
	_record("deploy", cell, -1, "伏せ札を配置")
	return true

func reveal(cell: int) -> bool:
	if phase != "prepare" or winner != -1 or not _owned(cell) or board[cell].face:
		return false
	_flip(cell)
	return true

# 移動済み状態を消費するため非冪等。
func move_unit(from: int, to: int) -> bool:
	if phase != "prepare" or winner != -1 or not _owned(from) or not _valid(to):
		return false
	if not board[from].face or board[from].moved or not board[to].is_empty() or not _adjacent(from, to):
		return false
	board[to] = board[from]
	board[from] = {}
	board[to].moved = true
	_record("move", from, to, "札を移動。この手番は攻撃できない")
	return true

# 準備段階の一度だけ使える配置交換を消費するため非冪等。
func swap_units(from: int, to: int) -> bool:
	if phase != "prepare" or winner != -1 or swapped or from == to or not _owned(from) or not _owned(to):
		return false
	if board[from].moved or board[to].moved or not _adjacent(from, to):
		return false
	var held: Dictionary = board[from]
	board[from] = board[to]
	board[to] = held
	swapped = true
	_record("swap", from, to, "味方の札を入れ替えた")
	return true

func begin_attack() -> bool:
	if phase != "prepare" or winner != -1:
		return false
	phase = "attack"
	log_text = "攻撃する札と標的を選択"
	return true

func legal_targets(from: int) -> Array[int]:
	var targets: Array[int] = []
	if phase != "attack" or winner != -1 or not _owned(from):
		return targets
	if not board[from].face or board[from].moved or board[from].attacked:
		return targets
	for target: int in range(board.size()):
		if _occupied(target) and board[target].side != turn and _adjacent(from, target):
			targets.append(target)
	var opposite: int = (1 - own_row(turn)) * width + from % width
	if from / width != own_row(turn) or board[opposite].is_empty():
		targets.append(-1)
	return targets

# 戦闘で盤・捨て札・王の体力を進めるため非冪等。
func attack(from: int, to: int) -> bool:
	if not legal_targets(from).has(to):
		return false
	var attacker: Dictionary = board[from].duplicate()
	var defender: Dictionary = board[to].duplicate() if to >= 0 else {}
	board[from].attacked = true
	if to == -1:
		var damage: int = maxi(1, card_power(from))
		hp[1 - turn] = maxi(0, hp[1 - turn] - damage)
		_record("king", from, to, "王に%dダメージ" % damage, attacker, defender)
		if hp[1 - turn] == 0:
			winner = turn
			phase = "finished"
		return true
	var attack_power: int = card_power(from)
	if CARDS[board[from].id].kind == "assassin" and not board[to].face:
		attack_power += 2
	var defense_power: int = card_power(to)
	if CARDS[board[to].id].kind == "guard":
		defense_power += 1
	_flip(to)
	var ranged: bool = CARDS[board[from].id].kind == "ranged"
	if attack_power >= defense_power:
		_discard(to)
	if attack_power <= defense_power:
		_discard(from)
	elif not ranged:
		board[to] = board[from]
		board[from] = {}
	_record("clash", from, to, "戦力 %d 対 %d：%s" % [attack_power, defense_power, "相打ち" if attack_power == defense_power else ("攻撃側の勝利" if attack_power > defense_power else "防御側の勝利")], attacker, defender)
	return true

# 次手番へ進めてドローするため非冪等。
func end_turn() -> bool:
	if winner != -1:
		return false
	turn = 1 - turn
	if turn == 0:
		round_number += 1
	phase = "prepare"
	energy = 3
	swapped = false
	for unit: Dictionary in board:
		if not unit.is_empty() and unit.side == turn:
			unit.moved = false
			unit.attacked = false
	_draw(turn)
	log_text = "あなたの手番" if turn == 0 else "相手の手番"
	return true

# CPU の一手番を進めるため非冪等。判断は一操作 API に集約する。
func play_enemy() -> void:
	while turn == 1 and winner == -1:
		if not enemy_step():
			return

# 演出の間隔を挟めるよう合法操作を一つだけ進めるため非冪等。
# 秘密の伏せ札の戦力は判断に使わず、守護札だけ対面の存在を見て伏せを保つ。
func enemy_step() -> bool:
	if turn != 1 or winner != -1:
		return false
	if phase == "prepare":
		for cell: int in range(width):
			if not board[cell].is_empty():
				continue
			var best: int = -1
			for hand_index: int in range(hands[turn].size()):
				var id: String = hands[turn][hand_index]
				if int(CARDS[id].cost) <= energy and (best == -1 or int(CARDS[id].power) > int(CARDS[hands[turn][best]].power)):
					best = hand_index
			if best >= 0:
				return deploy(best, cell)
		for cell: int in range(board.size()):
			if not _owned(cell) or board[cell].face:
				continue
			if cell < width and CARDS[board[cell].id].kind == "guard" and _occupied(cell + width) and board[cell + width].side == 0:
				continue
			return reveal(cell)
		return begin_attack()
	if phase == "attack":
		for cell: int in range(board.size()):
			var targets: Array[int] = legal_targets(cell)
			if targets.has(-1):
				return attack(cell, -1)
			if not targets.is_empty():
				return attack(cell, targets[0])
		return end_turn()
	return false

func _valid(cell: int) -> bool:
	return cell >= 0 and cell < board.size()

func _occupied(cell: int) -> bool:
	return _valid(cell) and not board[cell].is_empty()

func _owned(cell: int) -> bool:
	return _occupied(cell) and board[cell].side == turn

func _adjacent(from: int, to: int) -> bool:
	return absi(from % width - to % width) + absi(from / width - to / width) == 1

# 伏せ状態が解けた時だけ治癒を発火し、同じ札の再公開は無作用にする。
func _flip(cell: int) -> void:
	if board[cell].face:
		return
	board[cell].face = true
	if CARDS[board[cell].id].kind == "healer":
		var side: int = board[cell].side
		hp[side] = mini(MAX_HP, hp[side] + 1)
	_record("reveal", cell, -1, "%sを公開" % CARDS[board[cell].id].name)

# 盤上から捨て札へ所有権を移すゲーム進行操作のため非冪等。
func _discard(cell: int) -> void:
	discards[board[cell].side].append(board[cell].id)
	board[cell] = {}

# 山札を消費するドローは非冪等。
func _draw(side: int) -> void:
	if decks[side].is_empty() and not discards[side].is_empty():
		decks[side] = discards[side].duplicate()
		discards[side].clear()
		_shuffle(decks[side])
	if not decks[side].is_empty():
		hands[side].append(decks[side].pop_back())

# 同じシードからの対局再現を保ちつつ乱数系列を進めるため非冪等。
func _shuffle(cards: Array) -> void:
	for index: int in range(cards.size() - 1, 0, -1):
		var other: int = _rng.randi_range(0, index)
		var held: String = cards[index]
		cards[index] = cards[other]
		cards[other] = held

# 演出用の事実を操作ごとに追加するため非冪等。
func _record(kind: String, from: int, to: int, message: String, attacker: Dictionary = {}, defender: Dictionary = {}) -> void:
	log_text = message
	events.append({"kind": kind, "from": from, "to": to, "side": turn, "attacker": attacker, "defender": defender})
