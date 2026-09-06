class_name BoardRun
extends Node
## ラン・図鑑・保存の正。プレイヤーの選択を消費する操作は進行のため非冪等。

const Catalog = preload("res://scripts/core/catalog.gd")
const Battle = preload("res://scripts/core/battle.gd")
const SAVE_VERSION: int = 1
const DEPTH_COUNT: int = 9
const REMOVE_PRICE: int = 20

var battle: BoardBattle = null
var stage: String = "title"
var route: Array = []
var depth: int = -1
var current_node: Dictionary = {}
var deck: Array[String] = []
var king_hp: int = 10
var gold: int = 40
var seed_value: int = 1
var won: bool = false
var generals: Array[String] = []
var collected: Array[String] = []
var collection: Array[String] = []
var reward_options: Array[String] = []
var shop_options: Array[String] = []
var save_path: String = "user://boardrogue-save.json"
var save_error: String = ""
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	var previous: Variant = _read_save()
	if valid_snapshot(previous):
		collection.assign(previous.collection)


func new_run(run_seed: int) -> void:
	seed_value = run_seed
	rng.seed = run_seed
	stage = "map"
	route = generate_route(run_seed)
	depth = -1
	current_node = {}
	deck = Catalog.STARTER.duplicate()
	king_hp = 10
	gold = 40
	won = false
	generals.clear()
	collected.clear()
	reward_options.clear()
	shop_options.clear()
	battle = null
	for card_id: String in deck:
		_discover(card_id)


func choose_node(index: int) -> bool:
	if stage != "map" or depth + 1 >= route.size():
		return false
	if index < 0 or index >= route[depth + 1].size():
		return false
	depth += 1
	current_node = route[depth][index].duplicate()
	stage = current_node.type
	reward_options.clear()
	shop_options.clear()
	if stage in ["battle", "general", "final"]:
		battle = Battle.new()
		battle.setup(deck, current_node.enemy, current_node.width, rng.randi(), king_hp)
		stage = "battle"
	elif stage == "reward":
		reward_options = _sample_cards(false)
	elif stage == "shop":
		shop_options = _sample_cards(false)
	return true


func resolve_battle() -> bool:
	if stage != "battle" or battle == null or battle.phase != "over":
		return false
	king_hp = battle.hp[0]
	if battle.winner == 1:
		won = false
		stage = "result"
	elif current_node.type == "final":
		generals.append(battle.enemy_id)
		won = true
		stage = "result"
	else:
		gold += 30 if current_node.type == "general" else 20
		if current_node.type == "general":
			generals.append(battle.enemy_id)
		reward_options = _sample_cards(current_node.type == "general")
		stage = "reward"
	return true


func take_reward(index: int) -> bool:
	if stage != "reward" or index < 0 or index >= reward_options.size():
		return false
	_gain(reward_options[index])
	reward_options.clear()
	stage = "map"
	return true


func rest() -> bool:
	if stage != "rest":
		return false
	king_hp = mini(10, king_hp + 4)
	stage = "map"
	return true


func buy_card(index: int) -> bool:
	if stage != "shop" or index < 0 or index >= shop_options.size():
		return false
	var card_id: String = shop_options[index]
	var price: int = Catalog.PRICES[Catalog.CARDS[card_id].rarity]
	if gold < price:
		return false
	gold -= price
	_gain(card_id)
	shop_options.remove_at(index)
	return true


func remove_card(index: int) -> bool:
	if stage != "shop" or index < 0 or index >= deck.size() or deck.size() <= 4:
		return false
	if gold < REMOVE_PRICE:
		return false
	gold -= REMOVE_PRICE
	deck.remove_at(index)
	return true


func leave_node() -> bool:
	if stage not in ["reward", "rest", "shop"]:
		return false
	stage = "map"
	reward_options.clear()
	shop_options.clear()
	return true


func abandon() -> bool:
	if stage in ["title", "result"]:
		return false
	won = false
	king_hp = 0
	stage = "result"
	# 戦闘外でも撤退できる。未完の戦闘は再開対象から外し、到達記録だけ結果に残す。
	battle = null
	reward_options.clear()
	shop_options.clear()
	return true


func snapshot() -> Dictionary:
	return {"version": SAVE_VERSION, "stage": stage, "route": route.duplicate(true),
		"depth": depth, "current_node": current_node.duplicate(), "deck": deck.duplicate(),
		"king_hp": king_hp, "gold": gold, "seed": str(seed_value), "won": won,
		"generals": generals.duplicate(), "collected": collected.duplicate(),
		"collection": collection.duplicate(), "reward_options": reward_options.duplicate(),
		"shop_options": shop_options.duplicate(), "rng_state": str(rng.state),
		"battle": null if battle == null else battle.snapshot()}


func restore(data: Variant) -> bool:
	if not valid_snapshot(data):
		return false
	var resumed: BoardBattle = null
	if data.battle != null:
		resumed = Battle.new()
		if not resumed.restore(data.battle):
			return false
	stage = data.stage
	# JSON の数値は float になるため、検証済みの経路は seed から正規の整数型で復元する。
	route = generate_route(int(data.seed))
	depth = int(data.depth)
	current_node = {} if depth == -1 else route[depth][int(data.current_node.lane)].duplicate()
	deck.assign(data.deck)
	king_hp = int(data.king_hp)
	gold = int(data.gold)
	seed_value = int(data.seed)
	won = data.won
	generals.assign(data.generals)
	collected.assign(data.collected)
	collection.assign(data.collection)
	reward_options.assign(data.reward_options)
	shop_options.assign(data.shop_options)
	rng.state = int(data.rng_state)
	battle = resumed
	return true


func save_run() -> bool:
	var data: Dictionary = snapshot()
	if not valid_snapshot(data):
		save_error = "保存できる進行状態ではありません。"
		return false
	var file: FileAccess = FileAccess.open(save_path + ".writing", FileAccess.WRITE)
	if file == null:
		save_error = "保存ファイルを開けませんでした。"
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var file_error: Error = file.get_error()
	file.close()
	if file_error != OK:
		save_error = "保存中に書き込みが失敗しました。"
		return false
	var error: Error = DirAccess.rename_absolute(save_path + ".writing", save_path)
	save_error = "" if error == OK else "保存ファイルを確定できませんでした。"
	return error == OK


func load_run() -> bool:
	var success: bool = restore(_read_save())
	save_error = "" if success else "保存が見つからないか、破損・形式違いのため再開できません。"
	return success


func has_save() -> bool:
	var data: Variant = _read_save()
	return valid_snapshot(data) and data.stage != "result"


static func generate_route(run_seed: int) -> Array:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = run_seed
	var result: Array = []
	var pairs: Array = [["battle", "battle"], ["reward", "rest"], ["battle", "shop"],
		["general", "rest"], ["reward", "battle"], ["shop", "rest"],
		["general", "battle"], ["rest", "reward"], ["final"]]
	for layer: int in range(DEPTH_COUNT):
		var choices: Array = pairs[layer].duplicate()
		if choices.size() == 2 and random.randi_range(0, 1) == 1:
			choices.reverse()
		var nodes: Array = []
		for lane: int in range(choices.size()):
			var kind: String = choices[lane]
			var enemy: String = "scout" if layer < 4 else "duelist"
			if kind in ["general", "final"]:
				enemy = kind
			nodes.append({"type": kind, "enemy": enemy, "depth": layer, "lane": lane,
				"width": 3 if layer < 4 else 5})
		result.append(nodes)
	return result


static func valid_snapshot(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	for key: String in ["version", "stage", "route", "depth", "current_node", "deck", "king_hp",
			"gold", "seed", "won", "generals", "collected", "collection", "reward_options",
			"shop_options", "rng_state", "battle"]:
		if not data.has(key):
			return false
	if not _integer_range(data.version, SAVE_VERSION, SAVE_VERSION):
		return false
	if data.stage not in ["map", "battle", "reward", "rest", "shop", "result"]:
		return false
	if not data.seed is String or not data.seed.is_valid_int():
		return false
	if not data.rng_state is String or not data.rng_state.is_valid_int() or not data.won is bool:
		return false
	if not _integer_range(data.depth, -1, DEPTH_COUNT - 1):
		return false
	if not _integer_range(data.king_hp, 0, 10) or not _integer_range(data.gold, 0, 10000):
		return false
	if not Catalog.valid_cards(data.deck, 4, 40) or not Catalog.valid_cards(data.collected, 0, 40):
		return false
	if not Catalog.valid_cards(data.collection, 0, Catalog.CARDS.size()):
		return false
	var seen: Array = []
	for card_id: String in data.collection:
		if card_id in seen:
			return false
		seen.append(card_id)
	for card_id: String in data.deck + data.collected:
		if card_id not in data.collection:
			return false
	if not Catalog.valid_cards(data.reward_options, 0, 3):
		return false
	if not Catalog.valid_cards(data.shop_options, 0, 3):
		return false
	if not data.generals is Array or data.generals.size() > 3:
		return false
	for general: Variant in data.generals:
		if general not in ["general", "final"]:
			return false
	if not _valid_route(data.route, int(data.seed)) or not data.current_node is Dictionary:
		return false
	if int(data.depth) == -1:
		if data.stage not in ["map", "result"]:
			return false
		if not data.current_node.is_empty() or data.battle != null:
			return false
	elif not _valid_current_node(data.current_node, int(data.depth), int(data.seed)):
		return false
	return _valid_progress(data)


static func _integer_range(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and value >= low and value <= high and value == int(value)


static func _valid_route(saved: Variant, run_seed: int) -> bool:
	var expected: Array = generate_route(run_seed)
	if not saved is Array or saved.size() != expected.size():
		return false
	for layer: int in range(expected.size()):
		if not saved[layer] is Array or saved[layer].size() != expected[layer].size():
			return false
		for lane: int in range(expected[layer].size()):
			if not _same_node(saved[layer][lane], expected[layer][lane]):
				return false
	return true


static func _valid_current_node(saved: Dictionary, layer: int, run_seed: int) -> bool:
	var expected: Array = generate_route(run_seed)
	if not _integer_range(saved.get("lane"), 0, expected[layer].size() - 1):
		return false
	return _same_node(saved, expected[layer][int(saved.lane)])


static func _same_node(saved: Variant, expected: Dictionary) -> bool:
	if not saved is Dictionary or saved.size() != expected.size():
		return false
	for key: String in expected:
		if not saved.has(key):
			return false
		if expected[key] is int:
			if not _integer_range(saved[key], expected[key], expected[key]):
				return false
		elif not saved[key] is String or saved[key] != expected[key]:
			return false
	return true


static func _valid_progress(data: Dictionary) -> bool:
	if data.battle != null and not Battle.valid_snapshot(data.battle):
		return false
	if data.battle != null:
		var enemy_deck: Array = Catalog.ENEMIES[data.battle.enemy_id].deck
		if not _same_deck_in_battle(data.battle, 1, enemy_deck):
			return false
	if data.stage == "battle":
		if data.battle == null or data.current_node.type not in ["battle", "general", "final"]:
			return false
		if data.battle.enemy_id != data.current_node.enemy:
			return false
		if data.battle.width != data.current_node.width:
			return false
		if not _same_deck_in_battle(data.battle, 0, data.deck):
			return false
	if data.stage == "result":
		if data.battle == null:
			return not data.won and data.king_hp == 0
		if data.battle.phase != "over" or data.king_hp != data.battle.hp[0]:
			return false
		if data.won != (data.battle.winner == 0 and int(data.depth) == DEPTH_COUNT - 1):
			return false
	elif data.won or data.king_hp == 0:
		return false
	if data.stage == "map" and int(data.depth) == DEPTH_COUNT - 1:
		return false
	if data.stage == "reward" and data.reward_options.is_empty():
		return false
	if data.stage == "reward":
		if data.current_node.type not in ["reward", "battle", "general"]:
			return false
		if data.current_node.type in ["battle", "general"]:
			if data.battle == null or data.battle.winner != 0:
				return false
	if data.stage in ["rest", "shop"] and data.current_node.get("type", "") != data.stage:
		return false
	return true


static func _same_deck_in_battle(saved: Dictionary, side: int, expected: Array) -> bool:
	var count: Dictionary = {}
	for card_id: String in expected:
		count[card_id] = int(count.get(card_id, 0)) + 1
	for pile: Array in [saved.hands[side], saved.decks[side], saved.discards[side]]:
		for card_id: String in pile:
			count[card_id] = int(count.get(card_id, 0)) - 1
	for unit: Dictionary in saved.units:
		if unit.side == side:
			count[unit.card] = int(count.get(unit.card, 0)) - 1
	for value: int in count.values():
		if value != 0:
			return false
	return true


func _sample_cards(rare: bool) -> Array[String]:
	var pool: Array[String] = []
	for card_id: String in Catalog.CARDS:
		if not rare or Catalog.CARDS[card_id].rarity == 2:
			pool.append(card_id)
	var selected: Array[String] = []
	while selected.size() < 3 and not pool.is_empty():
		var index: int = rng.randi_range(0, pool.size() - 1)
		selected.append(pool[index])
		pool.remove_at(index)
	return selected


func _gain(card_id: String) -> void:
	deck.append(card_id)
	collected.append(card_id)
	_discover(card_id)


func _discover(card_id: String) -> void:
	if card_id not in collection:
		collection.append(card_id)


func _read_save() -> Variant:
	if not FileAccess.file_exists(save_path):
		return null
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null or file.get_length() > 500000:
		return null
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return null
	return parser.data
