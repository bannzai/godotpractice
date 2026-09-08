extends Node
## ラン・画面・図鑑の唯一の状態。選択や手番はゲームを1歩進めるので非冪等。
## 保存と読込は同じデータに対して同じ状態になり、壊れた保存は現在のランを変えない。

signal changed
signal event(detail: Dictionary)

const Catalog: Script = preload("res://scripts/card_catalog.gd")
const Board: Script = preload("res://scripts/board_state.gd")
const SAVE_VERSION: int = 1
const NODE_INFO: Dictionary = {
	"battle": {"title": "霧の辻", "description": "道を塞ぐ霊が、灯りを見つめている。",
		"art": "ghost"},
	"grave": {"title": "名もなき墓地", "description": "土の下から、あなたを呼ぶ声がする。",
		"art": "ghost"},
	"hunt": {"title": "禁じられた供物", "description": "命を捧げれば、望んだ霊が姿を現す。",
		"art": "hero"},
	"police": {"title": "夜の取り締まり", "description": "番人が墓土のついた手を見た。闇が深いほど罰は重い。",
		"art": "police"},
	"rest": {"title": "古い祠", "description": "まだ灯りの残る祠。人の心を、少しだけ取り戻せる。",
		"art": "hero"},
	"merchant": {"title": "宵の行商", "description": "「銭さえあれば、死者との縁も売りましょう」",
		"art": "merchant"},
	"elite": {"title": "黒門の守将", "description": "古い鎧が、誰もいない門を守り続ける。",
		"art": "general"},
	"boss": {"title": "夜明けの関", "description": "最後の将を退ければ、夜の外へ帰れる。",
		"art": "general"}
}
const ROUTE: Array = [
	["battle", "grave"], ["rest", "merchant"], ["battle", "hunt"],
	["grave", "police"], ["battle", "rest"], ["merchant", "grave"],
	["battle", "police"], ["rest", "merchant"], ["elite", "hunt"], ["boss", "boss"]
]

var screen: String = "title"
var run: Dictionary = {}
var board: SpiritBoard
var last_message: String = ""
var save_path: String = "user://run.json"
var collection_path: String = "user://collection.json"
var save_enabled: bool = true
var discovered: Array[String] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_load_collection()


func new_run(run_seed: int = 222223) -> void:
	rng.seed = run_seed
	run = {"seed": run_seed, "depth": 0, "nodes": generate_nodes(run_seed),
		"deck": Catalog.STARTER.duplicate(), "darkness": 0, "health": 10, "gold": 16,
		"collected": [], "result": "", "current_node": {}}
	board = null
	for card_id: String in Catalog.STARTER:
		_discover(card_id)
	screen = "map"
	last_message = "十の夜を越え、夜明けの関へ。"
	_commit()


func generate_nodes(run_seed: int) -> Array:
	var route_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	route_rng.seed = run_seed
	var nodes: Array = []
	for layer: Array in ROUTE:
		var pair: Array = []
		for kind: String in layer:
			var node: Dictionary = NODE_INFO[kind].duplicate()
			node.kind = kind
			var cards: Array[String] = Catalog.ids_for_rarity(1)
			node.card = cards[route_rng.randi_range(0, cards.size() - 1)]
			pair.append(node)
		if route_rng.randi_range(0, 1) == 1:
			pair.reverse()
		nodes.append(pair)
	return nodes


func choose_node(branch: int) -> bool:
	if screen != "map" or run.is_empty() or branch not in [0, 1] or int(run.depth) >= 10:
		return false
	run.current_node = run.nodes[int(run.depth)][branch].duplicate(true)
	var kind: String = str(run.current_node.kind)
	if kind in ["battle", "elite", "boss"]:
		_start_battle("general" if kind in ["elite", "boss"] else "ghost")
	else:
		screen = "event"
		last_message = event_description()
	_commit()
	return true


func event_title() -> String:
	return str(run.get("current_node", {}).get("title", "夜の道"))


func event_description() -> String:
	return str(run.get("current_node", {}).get("description", "どちらの道へ進もうか。"))


func event_choices() -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	if screen != "event":
		return choices
	var offer: String = str(run.current_node.card)
	match str(run.current_node.kind):
		"grave":
			choices.append(_choice("grave_take", "墓を開く", "霊を1枚迎える / 闇 +12"))
			choices.append(_choice("leave", "静かに祈る", "何も持ち去らず、先へ進む"))
		"hunt":
			for card_id: String in Catalog.ids_for_rarity(1):
				choices.append(_choice("hunt_" + card_id, str(Catalog.card(card_id).name) + "を呼ぶ",
					"命を捧げ、選んだ霊を迎える / 闇 +28"))
			choices.append(_choice("leave", "手を引く", "人の心を守り、先へ進む"))
		"police":
			choices.append(_choice("escape", "逃げる", "逃走成功率 %d%% / 成功で闇 -8" % int(escape_chance() * 100.0)))
			choices.append(_choice("fight", "番人と戦う", "勝利で霊を迎える / 闇 +25"))
		"rest":
			choices.append(_choice("rest", "灯りのそばで休む", "王の命 +4 / 闇 -15"))
		"merchant":
			choices.append(_choice("buy", str(Catalog.card(offer).name) + "を買う", "銭 12 / 闇は増えない",
				int(run.gold) >= 12))
			choices.append(_choice("purify", "清めの香を焚く", "銭 8 / 闇 -20", int(run.gold) >= 8))
			choices.append(_choice("leave", "先へ進む", "何も買わず、先へ進む"))
	return choices


func escape_chance() -> float:
	return clampf(0.88 - float(run.get("darkness", 0)) * 0.006, 0.25, 0.88)


func resolve_event(action: String) -> bool:
	if screen != "event":
		return false
	var legal: bool = false
	for choice: Dictionary in event_choices():
		if str(choice.action) == action and bool(choice.enabled):
			legal = true
	if not legal:
		return false
	var offer: String = str(run.current_node.card)
	var dark_before: int = int(run.darkness)
	if action.begins_with("hunt_"):
		_gain_card(action.trim_prefix("hunt_"))
		_change_darkness(28)
	elif action == "grave_take":
		_gain_card(offer)
		_change_darkness(12)
	elif action == "rest":
		_change_darkness(-15)
		run.health = mini(max_health(), int(run.health) + 4)
		last_message = "灯りに手をかざした。王の命が戻り、影が薄くなる。"
	elif action == "buy":
		run.gold = int(run.gold) - 12
		_gain_card(offer)
	elif action == "purify":
		run.gold = int(run.gold) - 8
		_change_darkness(-20)
		last_message = "香が影をほどいてゆく。"
	elif action == "escape":
		_resolve_escape()
	elif action == "fight":
		_start_battle("police")
		_commit()
		return true
	else:
		last_message = "何も奪わず、夜道を進んだ。"
	if int(run.darkness) != dark_before:
		event.emit({"type": "darkness", "amount": int(run.darkness) - dark_before})
	if int(run.darkness) >= 100:
		_finish("darkness")
	elif int(run.health) <= 0:
		_finish("defeat")
	else:
		_complete_node()
	_commit()
	return true


func board_action(kind: String, from: int = -1, to: int = -1, face: bool = true) -> Dictionary:
	if screen != "battle" or board == null or board.turn != 0 or board.winner != -1:
		return {"ok": false, "type": "invalid", "text": "今は霊を動かせません。"}
	var result: Dictionary = {}
	match kind:
		"deploy":
			result = board.deploy(from, to, face)
		"move":
			result = board.move_unit(from, to)
		"flip":
			result = board.flip_unit(from)
		"attack":
			result = board.attack(from, to)
		"battle":
			board.phase = "battle"
			result = {"ok": true, "type": "phase", "text": "バトル。動いていない霊で攻撃できます。"}
		_:
			return {"ok": false, "type": "invalid", "text": "その操作はできません。"}
	last_message = str(result.text)
	event.emit(result)
	if bool(result.ok):
		_check_battle_result()
		_commit()
	return result


func begin_enemy_turn() -> Dictionary:
	if screen != "battle" or board == null or board.turn != 0 or board.winner != -1:
		return {"ok": false, "type": "invalid", "text": "今は手番を終えられません。"}
	var detail: Dictionary = board.end_turn()
	last_message = str(detail.text)
	event.emit(detail)
	_commit()
	return detail


func step_enemy_turn() -> Dictionary:
	if screen != "battle" or board == null or board.turn != 1 or board.winner != -1:
		return {"ok": false, "type": "invalid", "text": "今は相手の手番ではありません。"}
	var detail: Dictionary = board.cpu_step()
	last_message = str(detail.text)
	event.emit(detail)
	_check_battle_result()
	_commit()
	return detail


func end_battle_turn() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var beginning: Dictionary = begin_enemy_turn()
	if not bool(beginning.ok):
		return events
	events.append(beginning)
	while screen == "battle" and board != null and board.turn == 1 and board.winner == -1:
		events.append(step_enemy_turn())
	return events


func continue_run() -> void:
	if screen == "result":
		to_title()


func abandon_run() -> void:
	if run.is_empty() or screen in ["title", "result"]:
		return
	_finish("defeat")
	_commit()


func to_title() -> void:
	screen = "title"
	changed.emit()


func max_health() -> int:
	return 8 if int(run.get("darkness", 0)) >= 80 else 10


func collection() -> Array[String]:
	return discovered.duplicate()


func has_save() -> bool:
	var data: Variant = _read_json(save_path)
	return data is Dictionary and _valid_save(data) \
		and str(data.screen) in ["map", "event", "battle"]


func save_game() -> bool:
	if not save_enabled or run.is_empty() or screen == "title":
		return false
	var data: Dictionary = {"version": SAVE_VERSION, "screen": screen, "run": run.duplicate(true),
		"rng_state": str(rng.state),
		"board": board.to_data() if board != null else {}}
	return _write_json(save_path, data)


func load_game() -> bool:
	var data: Variant = _read_json(save_path)
	if not data is Dictionary or not _valid_save(data):
		return false
	if str(data.screen) not in ["map", "event", "battle"]:
		return false
	var restored: SpiritBoard
	if str(data.screen) == "battle":
		restored = Board.new()
		if not restored.restore(data.board):
			return false
	run = data.run.duplicate(true)
	for key: String in ["seed", "depth", "darkness", "health", "gold"]:
		run[key] = int(run[key])
	board = restored
	rng.state = int(data.rng_state)
	screen = str(data.screen)
	last_message = "途切れた夜を、もう一度。"
	_load_collection()
	changed.emit()
	return true


func _choice(action: String, label: String, description: String,
		enabled: bool = true) -> Dictionary:
	return {"action": action, "label": label, "description": description, "enabled": enabled}


func _start_battle(opponent: String) -> void:
	board = Board.new()
	board.setup(run.deck, 5 if int(run.depth) >= 4 else 3,
		int(run.seed) + int(run.depth) * 131, int(run.health), int(run.darkness), opponent)
	screen = "battle"
	last_message = str(Catalog.enemy(opponent).lines.start)


func _check_battle_result() -> void:
	run.health = board.kings[0]
	if board.winner == -1:
		return
	if board.winner == 1:
		_finish("defeat")
		return
	run.gold = int(run.gold) + 8
	if board.enemy_id == "police":
		_change_darkness(25)
		event.emit({"type": "darkness", "amount": 25})
	var rarity: int = 2 if str(run.current_node.kind) in ["elite", "boss"] else 0
	var cards: Array[String] = Catalog.ids_for_rarity(rarity)
	_gain_card(cards[rng.randi_range(0, cards.size() - 1)])
	if int(run.darkness) >= 100:
		_finish("darkness")
	else:
		_complete_node()


func _complete_node() -> void:
	run.depth = int(run.depth) + 1
	if int(run.depth) >= 10:
		_finish("clear")
	else:
		screen = "map"
		board = null


func _finish(result: String) -> void:
	run.result = result
	screen = "result"
	match result:
		"clear":
			last_message = "関の向こうで鳥が鳴く。集めた霊は灯りとなり、あなたを朝へ導いた。"
		"darkness":
			last_message = "灯りを求めたはずだった。振り返ると、影だけがあなたの名を覚えていた。"
		_:
			last_message = "王の灯りが消えた。夜道には、まだあなたを待つ声がある。"


func _gain_card(card_id: String) -> void:
	run.deck.append(card_id)
	run.collected.append(card_id)
	_discover(card_id)
	last_message = "%sを迎えた。" % Catalog.card(card_id).name
	event.emit({"type": "gain", "card": card_id})


func _discover(card_id: String) -> void:
	if card_id not in discovered:
		discovered.append(card_id)
	if save_enabled:
		_write_json(collection_path, {"version": SAVE_VERSION, "cards": discovered})


func _change_darkness(amount: int) -> void:
	run.darkness = clampi(int(run.darkness) + amount, 0, 100)
	run.health = mini(int(run.health), max_health())


func _resolve_escape() -> void:
	if rng.randf() < escape_chance():
		_change_darkness(-8)
		last_message = "番人の灯りが遠ざかった。闇 -8。"
		return
	var penalty: int = 1 + int(run.darkness) / 25
	run.health = maxi(0, int(run.health) - penalty)
	var confiscated: String = ""
	if int(run.darkness) >= 30 and run.deck.size() > 4:
		confiscated = str(run.deck.pop_back())
	last_message = "逃走失敗。王の命 -%d。%s" % [penalty,
		"" if confiscated.is_empty() else "%sを没収された。" % Catalog.card(confiscated).name]


func _commit() -> void:
	if save_enabled:
		save_game()
	changed.emit()


func _write_json(path: String, data: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	return file.get_error() == OK


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _load_collection() -> void:
	var data: Variant = _read_json(collection_path)
	if not data is Dictionary or not _is_integer(data.get("version")):
		return
	if int(data.version) != SAVE_VERSION:
		return
	if not data.get("cards") is Array:
		return
	var restored: Array[String] = []
	for card_id: Variant in data.cards:
		if not card_id is String or card_id not in Catalog.CARDS:
			return
		if card_id not in restored:
			restored.append(card_id)
	discovered = restored


func _valid_save(data: Dictionary) -> bool:
	if not _is_integer(data.get("version")):
		return false
	if int(data.version) != SAVE_VERSION or not data.get("run") is Dictionary \
			or not data.get("rng_state") is String or not data.get("board") is Dictionary:
		return false
	if str(data.get("screen", "")) not in ["map", "event", "battle", "result"] \
			or not data.rng_state.is_valid_int():
		return false
	if not _valid_run(data.run) or not _valid_screen(data):
		return false
	if str(data.screen) == "battle":
		var restored: SpiritBoard = Board.new()
		return restored.restore(data.board) and restored.winner == -1 \
			and restored.kings[0] == int(data.run.health) \
			and restored.darkness == int(data.run.darkness)
	return true


func _valid_run(saved: Dictionary) -> bool:
	for key: String in ["seed", "depth", "nodes", "deck", "darkness", "health", "gold",
			"collected", "result", "current_node"]:
		if not saved.has(key):
			return false
	for key: String in ["seed", "depth", "darkness", "health", "gold"]:
		if not _is_integer(saved[key]):
			return false
	if int(saved.depth) < 0 or int(saved.depth) > 10 or int(saved.darkness) not in range(101) \
			or int(saved.health) not in range(11) or int(saved.gold) < 0:
		return false
	for cards_key: String in ["deck", "collected"]:
		if not _valid_cards(saved[cards_key]):
			return false
	return saved.deck.size() >= 4 and saved.current_node is Dictionary \
		and saved.nodes is Array and saved.nodes == generate_nodes(int(saved.seed))


func _valid_cards(cards: Variant) -> bool:
	if not cards is Array or cards.size() > 100:
		return false
	for card_id: Variant in cards:
		if not card_id is String or card_id not in Catalog.CARDS:
			return false
	return true


func _valid_screen(data: Dictionary) -> bool:
	var saved: Dictionary = data.run
	if str(data.screen) != "result" and (int(saved.depth) >= 10 or int(saved.health) <= 0 \
			or int(saved.darkness) >= 100 or str(saved.result) != ""):
		return false
	if str(data.screen) in ["event", "battle"]:
		if saved.current_node not in saved.nodes[int(saved.depth)]:
			return false
		var kind: String = str(saved.current_node.kind)
		if str(data.screen) == "event" and kind in ["battle", "elite", "boss"]:
			return false
		if str(data.screen) == "battle" and kind not in ["battle", "elite", "boss", "police"]:
			return false
	return true


func _is_integer(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))
