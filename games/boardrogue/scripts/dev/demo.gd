extends SceneTree
## 実入力イベントだけで自然対局を進め、プレイヤーの敵札撃破と敵王攻撃を録画する。

const Catalog = preload("res://scripts/core/catalog.gd")
const FRAME_LIMIT: int = 900
const PLAYER_UNIT_LIMIT: int = 2

var main: Control
var run: Node
var frames: int = 0
var next_frame: int = 30
var step: int = 0
var acting: bool = false
var failed: bool = false
var completed: bool = false
var placed: int = 0
var advanced: int = 0
var player_defeated: int = 0
var player_king_damage: int = 0
var reached_battle: bool = false
var reached_result: bool = false
var finishing: bool = false


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	run = root.get_node("Run")
	run.save_path = "res://tmp/demo-save.json"
	run.stage = "title"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.seed_input.text = "31"
	print("実入力録画 開始: 30 fps / 30 秒 / 旅路の種31")


# フレームと実イベントで一本の録画を進めるため非冪等。
func _process(_delta: float) -> bool:
	frames += 1
	if frames >= FRAME_LIMIT - 26 and not finishing:
		finishing = true
		_finish.call_deferred()
	elif is_instance_valid(main) and not finishing and not acting and not completed:
		if frames >= next_frame and not main.busy:
			acting = true
			_act.call_deferred()
	return false


func _act() -> void:
	match step:
		0:
			await _click("start")
			_check(run.stage == "map", "開始操作で旅路を表示")
			step = 1
			next_frame = frames + 30
		1:
			await _click("route_0_0")
			_check(run.stage == "battle", "ノード選択で対局へ")
			reached_battle = run.stage == "battle"
			step = 2
			next_frame = frames + 12
		2:
			if run.stage == "result":
				reached_result = true
				step = 5
				next_frame = frames + 20
			elif run.stage != "battle":
				_check(false, "敵札撃破と敵王攻撃を終える前に対局を離脱しない")
				step = 5
			elif player_defeated > 0 and player_king_damage > 0:
				step = 3
				next_frame = frames + 24
			elif frames >= FRAME_LIMIT - 210:
				step = 3
				next_frame = frames + 6
			else:
				await _play_one_action()
				next_frame = frames + 6
		3:
			await _click("pause")
			step = 4
			next_frame = frames + 8
		4:
			await _click("concede")
			_check(run.stage == "result", "降参操作で結果へ")
			reached_result = run.stage == "result"
			step = 5
			next_frame = frames + 18
		5:
			await _click("result_title")
			_check(run.stage == "title", "結果からタイトルへ")
			completed = run.stage == "title"
			step = 6
	acting = false


func _play_one_action() -> void:
	var battle: RefCounted = run.battle
	if battle.turn == 0 and battle.phase == "standby":
		await _play_standby_action()
	elif battle.turn == 0:
		await _play_battle_action()


func _play_standby_action() -> void:
	var concealed: Dictionary = _concealed_player_unit()
	var deployment: Dictionary = _deployment()
	var movement: Dictionary = _movement()
	if not concealed.is_empty():
		await _click(_cell_name(concealed))
		await _key(KEY_R)
	elif deployment.get("engages", false):
		await _deploy(deployment)
	elif not movement.is_empty():
		await _click(_cell_name(movement.unit))
		await _key(KEY_M)
		await _click(_cell_name_at(movement.to))
	elif not deployment.is_empty():
		await _deploy(deployment)
	else:
		await _key(KEY_E)
		advanced += 1


func _deploy(deployment: Dictionary) -> void:
	await _click("hand_%d" % deployment.index)
	await _click(_cell_name_at(deployment.pos))
	placed += 1


func _play_battle_action() -> void:
	var battle: RefCounted = run.battle
	var duel: Dictionary = _defeating_duel()
	if not duel.is_empty():
		var target_uid: int = duel.target.uid
		await _click(_cell_name(duel.unit))
		await _click(_cell_name(duel.target))
		if battle.unit_by_id(target_uid).is_empty():
			player_defeated += 1
			print("フレーム%d: プレイヤーが敵札を撃破" % frames)
	else:
		var king_attacker: Dictionary = _king_attacker()
		if king_attacker.is_empty():
			await _key(KEY_E)
			advanced += 1
			return
		var hp_before: int = battle.hp[1]
		await _click(_cell_name(king_attacker))
		await _click("enemy_king")
		var damage: int = hp_before - battle.hp[1]
		if damage > 0:
			player_king_damage += damage
			print("フレーム%d: プレイヤーが敵王へ%dダメージ" % [frames, damage])


func _concealed_player_unit() -> Dictionary:
	for unit: Dictionary in run.battle.units:
		if unit.side == 0 and not unit.face:
			return unit
	return {}


func _deployment() -> Dictionary:
	var battle: RefCounted = run.battle
	var own_count: int = 0
	for unit: Dictionary in battle.units:
		own_count += int(unit.side == 0)
	if own_count >= PLAYER_UNIT_LIMIT or battle.hands[0].is_empty():
		return {}
	var hand_index: int = 0
	for index: int in range(1, mini(8, battle.hands[0].size())):
		var power: int = Catalog.CARDS[battle.hands[0][index]].atk
		var selected_power: int = Catalog.CARDS[battle.hands[0][hand_index]].atk
		if (own_count == 0 and power < selected_power) or (own_count > 0 and power > selected_power):
			hand_index = index
	if own_count > 0:
		var card: Dictionary = Catalog.CARDS[battle.hands[0][hand_index]]
		for target: Dictionary in battle.units:
			if target.side != 1 or target.y != 1:
				continue
			var position := Vector2i(int(target.x), 2)
			if not battle.unit_at(position).is_empty():
				continue
			var offense: int = card.atk + int(card.effect == "duelist" and target.face)
			if offense >= battle.attack_power(target, false):
				return {"index": hand_index, "pos": position, "engages": true}
	var center: int = battle.width / 2
	var columns: Array[int] = [center]
	for offset: int in range(1, battle.width):
		if center - offset >= 0:
			columns.append(center - offset)
		if center + offset < battle.width:
			columns.append(center + offset)
	for y: int in [2, 3]:
		for x: int in columns:
			var pos := Vector2i(x, y)
			if battle.unit_at(pos).is_empty():
				return {"index": hand_index, "pos": pos, "engages": false}
	return {}


func _movement() -> Dictionary:
	var battle: RefCounted = run.battle
	var king: Vector2i = battle.king_position(1)
	var best: Dictionary = {}
	var best_distance: int = 1000
	for unit: Dictionary in battle.units:
		if unit.side != 0 or not unit.face or unit.moved or _has_target(unit):
			continue
		var origin := Vector2i(int(unit.x), int(unit.y))
		for direction: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
			var destination: Vector2i = origin + direction
			if not battle.in_board(destination) or not battle.unit_at(destination).is_empty():
				continue
			var distance: int = BoardBattle.distance(destination, king)
			if distance < BoardBattle.distance(origin, king) and distance < best_distance:
				best = {"unit": unit, "to": destination}
				best_distance = distance
	return best


func _has_target(unit: Dictionary) -> bool:
	var battle: RefCounted = run.battle
	if battle.can_attack(unit.uid, -1, false):
		return true
	for target: Dictionary in battle.units:
		if target.side == 1 and battle.can_attack(unit.uid, target.uid, false):
			return true
	return false


func _defeating_duel() -> Dictionary:
	var battle: RefCounted = run.battle
	var best: Dictionary = {}
	var best_score: int = -1000
	for unit: Dictionary in battle.units:
		if unit.side != 0:
			continue
		for target: Dictionary in battle.units:
			if target.side != 1 or not battle.can_attack(unit.uid, target.uid):
				continue
			if not target.face and Catalog.CARDS[target.card].effect == "revenge":
				continue
			var offense: int = battle.attack_power(unit, true, target.face)
			var defense: int = battle.attack_power(target, false)
			if offense < defense:
				continue
			var score: int = offense - defense
			if Catalog.CARDS[target.card].effect != "anchor":
				score += 10
			if target.x == battle.width / 2:
				score += 4
			if target.y == 0:
				score += 2
			if score > best_score:
				best = {"unit": unit, "target": target}
				best_score = score
	return best


func _king_attacker() -> Dictionary:
	if player_king_damage > 0:
		return {}
	var battle: RefCounted = run.battle
	var best: Dictionary = {}
	var best_power: int = 0
	for unit: Dictionary in battle.units:
		if unit.side != 0 or not battle.can_attack(unit.uid):
			continue
		var power: int = battle.attack_power(unit, true)
		if Catalog.CARDS[unit.card].effect == "siege":
			power += 1
		if power > best_power:
			best = unit
			best_power = power
	return best


func _cell_name(unit: Dictionary) -> String:
	return _cell_name_at(Vector2i(int(unit.x), int(unit.y)))


func _cell_name_at(pos: Vector2i) -> String:
	return "cell_%d_%d" % [pos.x, pos.y]


func _finish() -> void:
	main.stop_audio()
	_check(reached_battle and reached_result and completed, "タイトル・対局・結果・タイトルを通過")
	_check(placed > 0 and advanced > 0, "実配置・登場・移動・手番進行を記録")
	_check(player_defeated > 0, "プレイヤーの実入力で敵札を倒す場面を記録")
	_check(player_king_damage > 0, "プレイヤーの実入力で敵王を攻撃する場面を記録")
	while frames < FRAME_LIMIT:
		await process_frame
	print("demo OK" if not failed else "demo FAIL")
	quit(1 if failed else 0)


func _click(name: String) -> void:
	var button: Control = main.content.find_child(name, true, false)
	if not _check(is_instance_valid(button), "操作対象: " + name):
		return
	var point: Vector2 = button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await process_frame
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	print("フレーム%d: クリック %s / %s" % [frames, name, run.stage])


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _check(condition: bool, description: String) -> bool:
	if not condition:
		failed = true
		push_error(description)
	return condition
