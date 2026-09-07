extends SceneTree
## 通常の新規決闘を実入力だけで操作する36秒の録画。盤面・乱数・ルールは書き換えない。

const Catalog = preload("res://scripts/card_catalog.gd")
const FRAMES: int = 1080

var main: Control
var utility_turn: int = -1
var seen: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


# フレーム時刻に実入力を投入して対局を進めるため非冪等。
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for frame: int in range(FRAMES):
		await RenderingServer.frame_post_draw
		if frame == 30:
			_click("deck0")
		if frame == 45:
			_click("round0")
		if frame == 60:
			_click("tutorial_skip")
		if frame > 75 and frame < FRAMES - 135 and frame % 9 == 0:
			_step()
		if main.screen == "duel":
			for event: Dictionary in main.state.events:
				if event.get("player", -1) == 0:
					seen[event.type] = true
		if frame == FRAMES - 120:
			main.auto_actions_paused = true
		if frame == FRAMES - 20:
			main.stop_audio()
	if main.screen == "title" or main.busy or not seen.has("summon") or not seen.has("attack"):
		push_error("プレイ録画: 実入力による召喚・攻撃が不足: %s" % seen)
		quit(1)
		return
	print("プレイ録画 OK: 36秒、実入力の召喚・攻撃、到達ターン %d" % main.state.turn)
	await main.audio.shutdown()
	quit(0)


func _step() -> void:
	if main.screen != "duel" or main.busy or main.state.turn_player != 0:
		return
	match main.state.phase:
		"main":
			_main_phase()
		"battle":
			_battle_phase()
		_:
			_key(KEY_N)


func _main_phase() -> void:
	for action: String in ["summon", "cast", "set"]:
		if _available(action):
			if action != "summon":
				utility_turn = main.state.turn
			_click(action)
			return
	var hand: Array = main.state.players[0].hand
	if not main.state.summoned:
		var best: int = -1
		for index: int in hand.size():
			var card: Dictionary = Catalog.card(hand[index])
			if (
				card.type == "monster"
				and (best < 0 or card.attack > Catalog.card(hand[best]).attack)
			):
				best = index
		if best >= 0:
			_select_hand(best)
			return
	if utility_turn != main.state.turn:
		for index: int in hand.size():
			var id: String = hand[index]
			if id in ["snare", "spark", "boost"] and not main.state.players[0].monsters.is_empty():
				_select_hand(index)
				return
	_key(KEY_N)


func _battle_phase() -> void:
	if main.selected_zone == "monster0":
		if main.state.players[1].monsters.is_empty():
			_click("attack")
		else:
			_click("monster1_0")
		return
	for index: int in main.state.players[0].monsters.size():
		var monster: Dictionary = main.state.players[0].monsters[index]
		if not monster.attacked and not monster.defense:
			_click("monster0_%d" % index)
			return
	_key(KEY_N)


func _select_hand(index: int) -> void:
	if main.hand_page != int(index / 7.0):
		_click("nexthand")
	else:
		var card: Button = main.content.get_node("hand%d" % index)
		card.grab_focus()
		_key(KEY_ENTER)


func _available(node_name: String) -> bool:
	var button: Button = main.content.get_node_or_null(NodePath(node_name))
	return is_instance_valid(button) and not button.disabled


func _click(node_name: String) -> void:
	if not _available(node_name):
		return
	var button: Button = main.content.get_node(NodePath(node_name))
	var point: Vector2 = button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	print("実入力 %.2f秒: %s" % [Engine.get_process_frames() / 30.0, node_name])


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
