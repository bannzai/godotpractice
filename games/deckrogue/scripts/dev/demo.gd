extends SceneTree
## 30 fps の録画で実入力を投入し、通常の敗北とタイトルへの復帰を確認する。
## 入力とフレームの消費は、一本のプレイ録画を作るため非冪等。

const Catalog := preload("res://scripts/card_catalog.gd")
const FRAME_LIMIT: int = 900

var main: Control
var run: Node
var frames: int = 0
var failed: bool = false
var _step: int = 0
var _next_action_frame: int = 30
var _acting: bool = false
var _finishing: bool = false
var _cards_played: int = 0
var _turns_ended: int = 0
var _reached_result: bool = false
var _completed: bool = false


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	run = root.get_node("Run")
	root.add_child(main)
	print("プレイ録画 開始: 30 fps / 900 フレーム / 30 秒")


func _process(_delta: float) -> bool:
	frames += 1
	if frames * 2 == FRAME_LIMIT:
		print("プレイ録画 途中: フレーム %d / 場面 %s / 体力 %d" % [frames, run.phase, run.hp])
	if frames >= FRAME_LIMIT - 20 and not _finishing:
		_finishing = true
		_finish.call_deferred()
	elif is_instance_valid(main) and not _finishing and not _acting and not _completed:
		if frames >= _next_action_frame and not main.busy:
			_acting = true
			_act.call_deferred()
	return false


func _act() -> void:
	match _step:
		0:
			await _click(main.first_focus, "タイトルから巡礼を開始")
			_step = 1
			_next_action_frame = frames + 22
		1:
			_check(run.phase == "map", "実クリックでタイトルから地図へ進む")
			# 再現性のため、通常の開始操作が成功した後に乱数種だけを固定する。
			run.start_run(1)
			print("録画準備: 地図で乱数種 1 を固定。体力とデッキは通常の初期値")
			_step = 2
			_next_action_frame = frames + 24
		2:
			await _click(_button("案内を読み飛ばす"), "初回チュートリアルをスキップ")
			_check(main.tutorial_step == -1, "実クリックでチュートリアルを閉じる")
			_step = 3
			_next_action_frame = frames + 18
		3:
			await _click(main.first_focus, "最初の戦闘ノードを選択")
			_step = 4
			_next_action_frame = frames + 24
		4:
			await _play_card()
			if _cards_played >= 2:
				_step = 5
			_next_action_frame = frames + 8
		5:
			if run.phase == "result":
				_reached_result = true
				_check(not run.won, "体力を変更せず、敵の行動で敗北する")
				print("録画到達: 敗北結果 / フレーム %d / ターン終了 %d 回" % [frames, _turns_ended])
				_step = 6
				_next_action_frame = frames + 45
			else:
				_check(run.phase == "battle", "ターン終了時の場面は戦闘")
				await _key(KEY_E)
				_turns_ended += 1
				_next_action_frame = frames + 55
		6:
			await _click(_button("表紙へ戻る"), "敗北結果から表紙へ戻る")
			_step = 7
			_next_action_frame = frames + 15
		7:
			_check(run.phase == "title", "結果からタイトルへ復帰")
			_completed = true
			print("録画到達: タイトルへの復帰 / フレーム %d" % frames)
	_acting = false


func _play_card() -> void:
	_check(run.phase == "battle", "カードを実クリックする前に戦闘へ到達")
	if run.phase != "battle":
		_step = 5
		return
	var chosen: int = -1
	for index: int in range(run.hand.size()):
		var card: Dictionary = Catalog.CARDS[run.hand[index]]
		if int(card.cost) > run.energy:
			continue
		if chosen < 0:
			chosen = index
		if (_cards_played == 0 and card.type == "attack") or (
			_cards_played == 1 and run.hand[index] == "guard"):
			chosen = index
			break
	if chosen < 0:
		_check(false, "録画で使用できるカードがある")
		_step = 5
		return
	var name: String = Catalog.CARDS[run.hand[chosen]].name
	var energy_before: int = run.energy
	var hand_before: int = run.hand.size()
	await _click(main.card_nodes[chosen], "カード「%s」を使用" % name)
	while main.busy and frames < FRAME_LIMIT - 20:
		await process_frame
	var consumed: bool = run.energy < energy_before and run.hand.size() == hand_before - 1
	_check(consumed, "実クリックでカードとエネルギーを消費: " + name)
	if consumed:
		_cards_played += 1


func _button(caption: String) -> Button:
	for node: Node in main.screen.find_children("*", "Button", true, false):
		if node is Button and node.text == caption:
			return node
	return null


func _click(button: Button, description: String) -> void:
	if not is_instance_valid(button) or button.disabled:
		_check(false, "クリック対象が操作可能: " + description)
		return
	var point: Vector2 = button.global_position + button.size * 0.5
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await process_frame
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	print("録画入力 %03d F: %s / 座標 %s" % [frames, description, point])
	await process_frame


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
	print("録画入力 %03d F: E でターン終了 / 体力 %d" % [frames, run.hp])
	await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		failed = true
		push_error(description)


func _finish() -> void:
	_check(_completed and _reached_result, "30 秒以内にタイトル → 地図 → 戦闘 → 敗北 → タイトル")
	_check(_cards_played >= 2 and _turns_ended > 0, "カード複数枚とターン終了を実入力")
	await root.get_node("Sound").shutdown()
	while frames < FRAME_LIMIT:
		await process_frame
	print("プレイ録画 終了: %d フレーム / %s" % [frames, "失敗" if failed else "検証 OK"])
	if not failed:
		print("demo OK")
	quit(1 if failed else 0)
