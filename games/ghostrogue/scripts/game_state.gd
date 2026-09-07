extends Node
## 進行操作は一回の選択・戦闘ターンを消費するため非冪等。
## 画面をまたぐ状態と乱数はここに集約し、描画の速度から切り離す。

signal changed

const Catalog: Script = preload("res://scripts/catalog.gd")
const Story: Script = preload("res://scripts/story.gd")
const SAVE_VERSION: int = 2
const TUTORIAL_GRAVE: String = "grave"
const TUTORIAL_BATTLE: String = "battle"
const TUTORIAL_COMPLETE: String = "complete"
const ROUTE_KINDS: Array[Array] = [
	["grave", "story"], ["battle", "living"], ["rest", "police"],
	["story", "grave"], ["battle", "living"], ["rest", "story"],
	["police", "grave"], ["living", "story"], ["battle", "rest"],
	["story", "police"], ["rest", "living"], ["boss"],
]

var mode: String = "title"
var run_seed: int = 0
var depth: int = 0
var route: Array[Array] = []
var route_choices: Array[int] = []
var current_node: Dictionary = {}
var party: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var darkness: int = 0
var ether: int = 9
var relics: int = 2
var turn: int = 0
var battle_kind: String = ""
var journal: Array[String] = []
var collected: Array[String] = []
var discovered: Array[String] = []
var ending: String = ""
var result_text: String = ""
var last_message: String = ""
var tutorial_step: String = TUTORIAL_GRAVE
var save_path: String = "user://ghostrogue-save.json"
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _next_uid: int = 1


func _ready() -> void:
	var data: Dictionary = _read_save(save_path)
	if _valid_save(data):
		discovered.assign(data.discovered)


func new_run(seed_value: int = 0) -> void:
	run_seed = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
	run_seed = clampi(run_seed, 1, 2147483647)
	rng.seed = run_seed
	mode = "intro"
	depth = 0
	route = generate_route(run_seed)
	route_choices.clear()
	current_node.clear()
	party.clear()
	enemies.clear()
	darkness = 0
	ether = 9
	relics = 2
	turn = 0
	battle_kind = ""
	journal.clear()
	collected.clear()
	ending = ""
	result_text = ""
	tutorial_step = TUTORIAL_GRAVE
	_next_uid = 1
	for id: String in ["child", "warrior", "water"]:
		_gain_spirit(id)
	last_message = "妹の声を取り戻すため、灯を手に町へ向かう。"
	_publish()


func begin_journey() -> bool:
	if mode != "intro":
		return false
	mode = "map"
	_publish()
	return true


## チュートリアル完了後の再呼び出しでは状態を変えない。
func skip_tutorial() -> bool:
	if tutorial_step == TUTORIAL_COMPLETE:
		return true
	tutorial_step = TUTORIAL_COMPLETE
	last_message = "手帳の案内を閉じた。自分の判断で夜の町を進む。"
	_publish()
	return true


func tutorial_required_branch() -> int:
	if mode != "map" or depth < 0 or depth >= route.size():
		return -1
	var required_kind: String = ""
	if tutorial_step == TUTORIAL_GRAVE and depth == 0:
		required_kind = "grave"
	elif tutorial_step == TUTORIAL_BATTLE and depth == 1:
		required_kind = "battle"
	if required_kind.is_empty():
		return -1
	for branch: int in range(route[depth].size()):
		if String(route[depth][branch].get("kind", "")) == required_kind:
			return branch
	return -1


func enter_node(branch: int) -> bool:
	if mode != "map" or depth >= route.size() or branch < 0 or branch >= route[depth].size():
		return false
	var required_branch: int = tutorial_required_branch()
	if required_branch >= 0 and branch != required_branch:
		if tutorial_step == TUTORIAL_GRAVE:
			last_message = "最初は懐中電灯が照らす墓へ向かい、共に戦う霊を迎えよう。"
		else:
			last_message = "迎えた霊と共に、懐中電灯が照らす気配へ向かおう。"
		changed.emit()
		return false
	current_node = route[depth][branch].duplicate(true)
	route_choices.append(branch)
	mode = "event"
	last_message = String(Catalog.NODE_LABELS[current_node.kind]) + "へ足を踏み入れた。"
	if current_node.kind in ["battle", "boss"]:
		_start_battle(current_node.kind)
	_publish()
	return true


func event_choices() -> Array[Dictionary]:
	var kind: String = String(current_node.get("kind", "")) if mode == "event" else ""
	match kind:
		"grave":
			return [
				{"text": "墓を荒らし、霊を呼ぶ", "hint": "闇 +12 / 霊を1体獲得"},
				{"text": "花を供えて去る", "hint": "闇 −3"},
			]
		"living":
			return [
				{"text": "依代の命を断つ", "hint": "闇 +28 / %sを必ず獲得"
					% Catalog.spirit(current_node.spirit).name},
				{"text": "命を奪わず立ち去る", "hint": "闇 −5"},
			]
		"police":
			return [
				{"text": "検査に応じる", "hint": police_penalty_text()},
				{"text": "路地へ逃げる", "hint": "成功率 %d%% / 成功で闇 −8 / 失敗で罰則"
					% roundi(escape_chance() * 100)},
				{"text": "警官と戦う", "hint": "勝利で闇 +28 / 敗北で最大の罰則"},
			]
		"rest":
			return [
				{"text": "祠で夜をやり過ごす", "hint": "闇 −12 / 全員 HP +48 / 霊気 +5 / お守り +1"},
			]
		"story":
			var choices: Array[Dictionary] = []
			choices.assign(Story.EVENTS[int(current_node.story)].choices)
			return choices
	return []


func choose_event(index: int) -> bool:
	var choices: Array[Dictionary] = event_choices()
	if index < 0 or index >= choices.size():
		return false
	if tutorial_step == TUTORIAL_GRAVE and depth == 0 and current_node.get("kind") == "grave" \
			and index != 0:
		last_message = "今夜を進むには、まず墓に残る霊へ灯を差し出そう。案内は手帳から飛ばせる。"
		changed.emit()
		return false
	if relics + int(choices[index].get("relic", 0)) < 0:
		last_message = "渡せるお守りがない。別の選択を選ぼう。"
		changed.emit()
		return false
	last_message = choices[index].text
	match String(current_node.kind):
		"grave", "living":
			if index == 0:
				_gain_spirit(current_node.spirit)
				_change_darkness(12 if current_node.kind == "grave" else 28)
				last_message = "%s が灯に加わった。" % Catalog.spirit(current_node.spirit).name
				if tutorial_step == TUTORIAL_GRAVE and depth == 0 \
						and current_node.kind == "grave":
					tutorial_step = TUTORIAL_BATTLE
			else:
				_change_darkness(-3 if current_node.kind == "grave" else -5)
		"police":
			_resolve_police(index)
		"rest":
			_change_darkness(-12)
			_heal_party(48)
			ether = mini(18, ether + 5)
			relics = mini(9, relics + 1)
			last_message = "小さな灯に囲まれて、霊もあなたも息をついた。"
		"story":
			_apply_story(choices[index])
	journal.append(last_message)
	if mode == "event":
		_finish_node()
	_publish()
	return true


func swap_party(front_index: int, reserve_index: int) -> bool:
	if mode not in ["map", "event"] or front_index < 0 or front_index >= mini(3, party.size()):
		return false
	if reserve_index < 3 or reserve_index >= party.size():
		return false
	var previous: Dictionary = party[front_index]
	party[front_index] = party[reserve_index]
	party[reserve_index] = previous
	last_message = "%s を前衛に迎えた。" % Catalog.spirit(party[front_index].species).name
	_publish()
	return true


func resolve_turn(moves: Array, target_index: int = 0) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if mode != "battle":
		return events
	if not _valid_commands(moves, target_index):
		changed.emit()
		return events
	var order: Array[Dictionary] = []
	for index: int in mini(3, party.size()):
		order.append({"side": "party", "uid": party[index].uid, "move": moves[index]})
	for unit: Dictionary in enemies:
		order.append({"side": "enemy", "uid": unit.uid, "move": 1 if turn % 3 == 0 else 0})
	order.sort_custom(_faster)
	var chosen_uid: int = int(enemies[target_index].uid)
	for command: Dictionary in order:
		if mode != "battle":
			break
		_execute_command(command, chosen_uid, events)
	if mode == "battle":
		turn += 1
		ether = mini(18, ether + 2)
		last_message = "次の命令を選ぶ。毎ターン、霊気が2回復する。"
	_publish()
	return events


func escape_chance() -> float:
	var speed_sum: int = 0
	for unit: Dictionary in party.slice(0, 3):
		speed_sum += int(Catalog.spirit(unit.species).speed)
	var average: float = float(speed_sum) / float(maxi(1, mini(3, party.size())))
	return clampf(0.76 + (average - 12.0) * 0.018 - float(darkness) * 0.006, 0.12, 0.92)


func police_penalty_text() -> String:
	if darkness >= 80:
		return "最大罰則: 霊2体・霊気すべて・お守りすべてを没収"
	if darkness >= 60:
		return "霊1体・霊気4・お守りすべてを没収"
	if darkness >= 30:
		return "霊1体・霊気3・お守り1を没収"
	return "霊気2・お守り1を没収"


func darkness_stage() -> int:
	if darkness >= 80:
		return 3
	if darkness >= 60:
		return 2
	return 1 if darkness >= 30 else 0


func to_title() -> void:
	if mode != "title":
		save_game()
	mode = "title"
	changed.emit()


func has_save(path: String = "") -> bool:
	var data: Dictionary = _read_save(save_path if path.is_empty() else path)
	return _valid_save(data) and data.mode != "result"


func save_game(path: String = "") -> bool:
	var destination: String = save_path if path.is_empty() else path
	if mode == "title" or destination.is_empty():
		return false
	var file: FileAccess = FileAccess.open(destination + ".writing", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(_save_data()))
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		return false
	return DirAccess.rename_absolute(destination + ".writing", destination) == OK


func load_game(path: String = "") -> bool:
	var data: Dictionary = _read_save(save_path if path.is_empty() else path)
	if not _valid_save(data) or data.mode == "result":
		return false
	mode = data.mode
	run_seed = int(data.run_seed)
	depth = int(data.depth)
	route = generate_route(run_seed)
	route_choices.clear()
	for choice: Variant in data.route_choices:
		route_choices.append(int(choice))
	current_node = route[depth][route_choices.back()].duplicate(true) \
		if mode in ["event", "battle"] else {}
	party.clear()
	for unit: Dictionary in data.party:
		party.append({"uid": int(unit.uid), "species": unit.species, "hp": int(unit.hp)})
	enemies.clear()
	for unit: Dictionary in data.enemies:
		enemies.append({"uid": int(unit.uid), "species": unit.species, "hp": int(unit.hp)})
	darkness = int(data.darkness)
	ether = int(data.ether)
	relics = int(data.relics)
	turn = int(data.turn)
	battle_kind = data.battle_kind
	journal.assign(data.journal)
	collected.assign(data.collected)
	discovered.assign(data.discovered)
	tutorial_step = String(data.get("tutorial_step", TUTORIAL_COMPLETE))
	ending = data.ending
	result_text = ""
	last_message = data.last_message
	_next_uid = int(data.next_uid)
	rng.seed = run_seed
	# JSON の数値では64bit状態の精度を失うため、乱数状態は十進文字列で保存する。
	rng.state = String(data.rng_state).to_int()
	changed.emit()
	return true


static func generate_route(seed_value: int) -> Array[Array]:
	var map_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	map_rng.seed = seed_value
	var generated: Array[Array] = []
	var story_offset: int = map_rng.randi_range(0, Story.EVENTS.size() - 1)
	var story_number: int = 0
	for kinds: Array in ROUTE_KINDS:
		var row: Array = []
		for kind: String in kinds:
			var spirit_id: String = ""
			if kind == "grave":
				spirit_id = Catalog.SPIRITS.keys()[map_rng.randi_range(0, 7)]
			elif kind == "living":
				spirit_id = Catalog.SPIRITS.keys()[map_rng.randi_range(8, 11)]
			elif kind == "battle":
				spirit_id = Catalog.SPIRITS.keys()[map_rng.randi_range(0, 7)]
			var story_index: int = (story_offset + story_number) % Story.EVENTS.size()
			row.append({"kind": kind, "spirit": spirit_id, "story": story_index})
			if kind == "story":
				story_number += 1
		if row.size() == 2 and map_rng.randi_range(0, 1) == 1:
			row.reverse()
		generated.append(row)
	return generated


func _gain_spirit(id: String) -> void:
	party.append(Catalog.create_spirit(id, _next_uid))
	_next_uid += 1
	collected.append(id)
	if id not in discovered:
		discovered.append(id)


func _change_darkness(amount: int) -> void:
	darkness = clampi(darkness + amount, 0, 100)
	if darkness >= 100:
		_end_run("darkness")


func _heal_party(amount: int) -> void:
	for unit: Dictionary in party:
		unit.hp = mini(int(Catalog.spirit(unit.species).hp), int(unit.hp) + amount)


func _apply_story(choice: Dictionary) -> void:
	_change_darkness(int(choice.dark))
	ether = clampi(ether + int(choice.get("ether", 0)), 0, 18)
	relics = clampi(relics + int(choice.get("relic", 0)), 0, 9)
	_heal_party(int(choice.get("heal", 0)))
	last_message = "%s — %s" % [Story.EVENTS[int(current_node.story)].title, choice.text]


func _resolve_police(index: int) -> void:
	if index == 2:
		_start_battle("police")
	elif index == 1 and rng.randf() < escape_chance():
		_change_darkness(-8)
		last_message = "足音が遠ざかった。路地を抜け、追跡を振り切った。"
	else:
		_apply_penalty(false)
		last_message = "検査を受けた。" if index == 0 else "逃走に失敗した。"
		last_message += " " + police_penalty_text()


func _apply_penalty(maximum: bool) -> void:
	var severity: int = 80 if maximum else darkness
	var lost_count: int = 2 if severity >= 80 else (1 if severity >= 30 else 0)
	for _index: int in mini(lost_count, party.size()):
		party.pop_front()
	var ether_loss: int = 4 if severity >= 60 else (3 if severity >= 30 else 2)
	ether = 0 if severity >= 80 else maxi(0, ether - ether_loss)
	relics = 0 if severity >= 60 else maxi(0, relics - 1)
	if party.is_empty():
		_end_run("arrest")


func _start_battle(kind: String) -> void:
	mode = "battle"
	battle_kind = kind
	turn = 1
	enemies.clear()
	if kind == "boss":
		enemies.append(Catalog.create_spirit("boss", -1))
	elif kind == "police":
		enemies.append(Catalog.create_spirit("police", -1))
		if darkness >= 60:
			enemies.append(Catalog.create_spirit("police", -2))
	else:
		enemies.append(Catalog.create_spirit(current_node.spirit, -1))
		if depth >= 4:
			var other: String = Catalog.SPIRITS.keys()[rng.randi_range(0, 7)]
			enemies.append(Catalog.create_spirit(other, -2))
	last_message = "霊に命令を。速い者から動く。怨 → 哀 → 怒 → 怨 の順で相性有利。"


func _valid_commands(moves: Array, target_index: int) -> bool:
	if moves.size() < mini(3, party.size()) or target_index < 0 or target_index >= enemies.size():
		last_message = "前衛の技と攻撃先を選ぼう。"
		return false
	var cost: int = 0
	for index: int in mini(3, party.size()):
		if not Catalog.integer_between(moves[index], 0, 1):
			last_message = "使えない技が選択されている。"
			return false
		cost += int(Catalog.MOVES[Catalog.spirit(party[index].species).moves[moves[index]]].cost)
	if cost > ether:
		last_message = "霊気が足りない。通常技を組み合わせよう。"
		return false
	return true


func _faster(left: Dictionary, right: Dictionary) -> bool:
	var first: Dictionary = _find_unit(left.side, int(left.uid))
	var second: Dictionary = _find_unit(right.side, int(right.uid))
	var first_speed: int = int(Catalog.spirit(first.species).speed)
	var second_speed: int = int(Catalog.spirit(second.species).speed)
	if first_speed == second_speed:
		if left.side != right.side:
			return left.side == "party"
		return int(left.uid) < int(right.uid)
	return first_speed > second_speed


func _find_unit(side: String, uid: int) -> Dictionary:
	for unit: Dictionary in (party if side == "party" else enemies):
		if int(unit.uid) == uid:
			return unit
	return {}


func _execute_command(command: Dictionary, chosen_uid: int, events: Array[Dictionary]) -> void:
	var actor: Dictionary = _find_unit(command.side, int(command.uid))
	if actor.is_empty():
		return
	var target_side: String = "enemy" if command.side == "party" else "party"
	var target: Dictionary = _find_unit(target_side, chosen_uid) if target_side == "enemy" else {}
	if target.is_empty():
		target = enemies[0] if target_side == "enemy" \
			else party[rng.randi_range(0, mini(3, party.size()) - 1)]
	var move_index: int = int(command.move)
	if command.side == "party" and darkness >= 60 and rng.randf() < 0.25:
		move_index = 0
		target = enemies[rng.randi_range(0, enemies.size() - 1)]
		events.append({"kind": "wild", "actor_side": "party", "actor_uid": actor.uid,
			"text": "%s が命令を無視して暴走した！" % Catalog.spirit(actor.species).name})
	var move_id: String = Catalog.spirit(actor.species).moves[move_index]
	if command.side == "party":
		ether -= int(Catalog.MOVES[move_id].cost)
	var damage: int = Catalog.damage(actor, target, move_index,
		darkness if command.side == "party" else 0)
	target.hp = maxi(0, int(target.hp) - damage)
	events.append({"kind": "attack", "actor_side": command.side, "actor_uid": actor.uid,
		"target_side": target_side, "target_uid": target.uid, "damage": damage,
		"hp": target.hp, "move": move_id,
		"text": "%s の %s。%s に %d。" % [Catalog.spirit(actor.species).name,
			Catalog.MOVES[move_id].name, Catalog.spirit(target.species).name, damage]})
	if int(target.hp) == 0:
		events.append({"kind": "lost", "target_side": target_side, "target_uid": target.uid,
			"text": "%s は霧となって消えた。" % Catalog.spirit(target.species).name})
		if target_side == "party":
			var promoted: Dictionary = party[3].duplicate(true) if party.size() > 3 else {}
			party.erase(target)
			if not promoted.is_empty():
				events.append({"kind": "promoted", "unit": promoted,
					"text": "%s が灯を継ぎ、前衛へ進んだ。" % Catalog.spirit(promoted.species).name})
		else:
			enemies.erase(target)
	_check_battle_end(events)


func _check_battle_end(events: Array[Dictionary]) -> void:
	if party.is_empty():
		if battle_kind == "police":
			_apply_penalty(true)
		else:
			_end_run("lost")
	elif enemies.is_empty():
		if battle_kind == "boss":
			depth = route.size()
			_end_run("saved" if darkness < 60 else "scarred")
		elif battle_kind == "police":
			_change_darkness(28)
			last_message = "巡回隊は倒れた。取り返しのつかない沈黙が残る。闇 +28。"
			if mode != "result":
				_finish_node()
		else:
			var completes_tutorial: bool = tutorial_step == TUTORIAL_BATTLE and depth == 1 \
				and battle_kind == "battle"
			ether = mini(18, ether + 3)
			relics = mini(9, relics + 1)
			last_message = "漂う霊を鎮めた。霊気 +3、お守り +1。"
			_finish_node()
			if completes_tutorial:
				tutorial_step = TUTORIAL_COMPLETE
				last_message = "霊を迎え、共に戦う術を覚えた。ここから先は手帳と灯を頼りに進もう。"
	if mode != "battle":
		events.append({"kind": "message", "text": last_message})


func _finish_node() -> void:
	depth += 1
	mode = "map"
	enemies.clear()
	battle_kind = ""
	turn = 0


func _end_run(id: String) -> void:
	mode = "result"
	ending = id
	result_text = Story.ENDINGS[id].text
	last_message = Story.ENDINGS[id].title


func _publish() -> void:
	if not save_path.is_empty() and not save_game():
		last_message += "（保存できませんでした）"
	changed.emit()


func _save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION, "mode": mode, "run_seed": run_seed, "depth": depth,
		"route_choices": route_choices, "party": party, "enemies": enemies,
		"darkness": darkness, "ether": ether, "relics": relics, "turn": turn,
		"battle_kind": battle_kind, "journal": journal, "collected": collected,
		"discovered": discovered, "ending": ending, "last_message": last_message,
		"next_uid": _next_uid, "rng_state": str(rng.state), "tutorial_step": tutorial_step,
	}


static func _read_save(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var parser: JSON = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		return {}
	return parser.data


static func _valid_save(data: Dictionary) -> bool:
	if not Catalog.integer_between(data.get("version"), 1, SAVE_VERSION):
		return false
	var version: int = int(data.version)
	var keys: Array[String] = ["version", "mode", "run_seed", "depth", "route_choices",
		"party", "enemies", "darkness", "ether", "relics", "turn", "battle_kind", "journal",
		"collected", "discovered", "ending", "last_message", "next_uid", "rng_state"]
	if version == SAVE_VERSION:
		keys.append("tutorial_step")
	if data.size() != keys.size() or not data.has_all(keys):
		return false
	if data.mode not in ["intro", "map", "event", "battle", "result"]:
		return false
	if version == SAVE_VERSION and (not data.tutorial_step is String \
			or data.tutorial_step not in [TUTORIAL_GRAVE, TUTORIAL_BATTLE, TUTORIAL_COMPLETE]):
		return false
	for entry: Array in [["run_seed", 1, 2147483647], ["depth", 0, 12], ["darkness", 0, 100],
		["ether", 0, 18], ["relics", 0, 9], ["turn", 0, 10000], ["next_uid", 1, 1000]]:
		if not Catalog.integer_between(data[entry[0]], entry[1], entry[2]):
			return false
	for key: String in ["battle_kind", "ending", "last_message", "rng_state"]:
		if not data[key] is String:
			return false
	if not data.rng_state.is_valid_int() or str(data.rng_state.to_int()) != data.rng_state:
		return false
	for key: String in ["party", "enemies", "collected", "discovered", "journal", "route_choices"]:
		if not data[key] is Array:
			return false
	if not _valid_collections(data) or not _valid_saved_route(data):
		return false
	if data.mode == "battle":
		return data.battle_kind in ["battle", "police", "boss"] and data.turn >= 1 \
			and not data.enemies.is_empty()
	return true


static func _valid_collections(data: Dictionary) -> bool:
	var known_uids: Dictionary = {}
	if data.party.size() > 30 or data.enemies.size() > 2:
		return false
	for unit: Variant in data.party:
		if not Catalog.valid_spirit(unit) or unit.uid <= 0 or unit.uid >= data.next_uid:
			return false
		if known_uids.has(unit.uid):
			return false
		known_uids[unit.uid] = true
	for unit: Variant in data.enemies:
		if not Catalog.valid_spirit(unit, true) or unit.uid >= 0 or known_uids.has(unit.uid):
			return false
		known_uids[unit.uid] = true
	for key: String in ["collected", "discovered"]:
		if data[key].size() > 40:
			return false
		for id: Variant in data[key]:
			if not id is String or not Catalog.SPIRITS.has(id):
				return false
	if data.collected.size() != int(data.next_uid) - 1:
		return false
	for id: String in data.collected:
		if id not in data.discovered:
			return false
	for line: Variant in data.journal:
		if not line is String:
			return false
	for unit: Dictionary in data.party:
		if unit.species not in data.collected or unit.species not in data.discovered:
			return false
	return true


static func _valid_saved_route(data: Dictionary) -> bool:
	var choices: Array = data.route_choices
	var active: bool = data.mode in ["event", "battle"]
	if choices.size() != int(data.depth) + (1 if active else 0) and data.mode != "result":
		return false
	if choices.size() > 12 or (data.depth >= 12 and data.mode != "result"):
		return false
	if data.mode == "intro" and data.depth != 0:
		return false
	if data.mode != "result" and (data.party.is_empty() or data.darkness >= 100):
		return false
	if data.mode == "result" and not Story.ENDINGS.has(data.ending):
		return false
	var generated: Array[Array] = generate_route(int(data.run_seed))
	for index: int in choices.size():
		if not Catalog.integer_between(choices[index], 0, generated[index].size() - 1):
			return false
	if active:
		var kind: String = generated[int(data.depth)][int(choices.back())].kind
		if data.mode == "event" and kind not in ["grave", "living", "police", "rest", "story"]:
			return false
		if data.mode == "battle" and (kind not in ["battle", "police", "boss"]
			or data.battle_kind != kind):
			return false
	return true
