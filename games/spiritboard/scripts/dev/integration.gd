extends SceneTree
## 本番画面へ実入力を送り、表示と状態が一緒に進むことを検証する。
## 入力・フレーム進行・イベント記録は検証する操作そのものなので非冪等。
## 保存は tmp 配下だけを使い、実ユーザーの旅と図鑑には書き込まない。

const AudioStop := preload("res://scripts/dev/audio_stop.gd")
const Catalog := preload("res://scripts/card_catalog.gd")
const WAIT_SECONDS: float = 5.0

var main: Control
var session: Node
var failed: bool = false
var elapsed_frames: int = 0
var elapsed_seconds: float = 0.0
var recorded_events: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _process(delta: float) -> bool:
	elapsed_frames += 1
	elapsed_seconds += delta
	if elapsed_seconds > 120.0:
		push_error("入力検証: 120秒の終了上限を超えました")
		AudioStop.stop(root)
		quit(1)
	return false


func _run() -> void:
	if not await _setup(true):
		await _finish(false)
		return
	var success: bool = await _menus_and_events()
	if success:
		success = await _battle_inputs()
	if success:
		success = await _result_inputs()
	await _finish(success and not failed)


func _setup(persist: bool) -> bool:
	root.size = Vector2i(1280, 720)
	session = root.get_node("Session")
	session.save_path = "res://tmp/integration-run.json"
	session.collection_path = "res://tmp/integration-collection.json"
	session.save_enabled = persist
	session.discovered.clear()
	session.event.connect(_record_event)
	var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
	if packed == null or change_scene_to_packed(packed) != OK:
		return _check(false, "メインシーンをロードできる")
	await scene_changed
	main = current_scene
	await _frames(5)
	return _check(session.screen == "title", "タイトルから開始する")


func _menus_and_events() -> bool:
	await _click("help")
	_check(main.overlay == "help", "マウスで遊び方を開く")
	await _tap_key(KEY_ESCAPE)
	_check(main.overlay.is_empty(), "Escで遊び方を閉じる")
	await _tap_button(JOY_BUTTON_B)
	_check(main.overlay == "help", "パッドBで遊び方を開く")
	await _tap_button(JOY_BUTTON_A)
	_check(main.overlay.is_empty(), "パッドAで旅へ戻る")
	await _click("collection")
	_check(main.overlay == "collection", "図鑑を開く")
	await _click("next")
	_check(main.collection_page == 1, "図鑑の次の頁を開く")
	await _tap_key(KEY_ESCAPE)
	await _enter_seed()
	await _click("new")
	if not _check(session.screen == "map" and int(session.run.seed) == 222223,
			"入力した道の種で新しい旅を始める"):
		return false
	await _choose_kind("grave")
	if not _check(session.screen == "event", "墓地のイベント画面へ進む"):
		return false
	var deck_size: int = session.run.deck.size()
	await _click("event-0")
	_check(session.screen == "map" and session.run.deck.size() == deck_size + 1,
		"墓を開く実操作で霊を迎えて地図へ戻る")
	await _choose_kind("rest")
	await _click("event-0")
	if not _check(session.screen == "map" and int(session.run.depth) == 2,
			"休息を選んで次の夜路へ進む"):
		return false
	var saved_run: Dictionary = session.run.duplicate(true)
	await _click("save")
	_check(session.screen == "title" and session.has_save(), "保存してタイトルへ戻る")
	await _tap_key(KEY_DOWN)
	var focus: Control = root.gui_get_focus_owner()
	_check(focus != null and str(focus.get_meta("tag", "")) == "resume",
		"下キーで続きのボタンへフォーカスが移る")
	await _tap_button(JOY_BUTTON_A)
	return _check(session.screen == "map" and session.run == saved_run,
		"パッドAで保存した地図を復元する") and not failed


func _battle_inputs() -> bool:
	await _choose_kind("battle")
	if not _check(session.screen == "battle", "戦闘へ進む"):
		return false
	var hand_index: int = _strongest_hand()
	var chosen: String = str(session.board.hands[0][hand_index])
	await _click("hand-%d" % hand_index)
	await _click("cell-10")
	if not await _idle():
		return false
	if not _check(str(session.board.at(10).get("card", "")) == chosen,
			"手札と自陣のクリックで選んだ霊を配置する"):
		return false
	await _click("cell-10")
	await _tap_key(KEY_R)
	if not await _idle():
		return false
	_check(not bool(session.board.at(10).face), "Rで選択中の霊を潜伏させる")
	return await _second_turn()


func _second_turn() -> bool:
	await _tap_button(JOY_BUTTON_Y)
	if not await _idle():
		return false
	if not _check(session.screen == "battle" and session.board.turn == 0
			and session.board.turn_number == 3, "パッドYでCPUの手を経て自分の手へ戻る"):
		return false
	await _click("cell-10")
	await _tap_button(JOY_BUTTON_RIGHT_SHOULDER)
	if not await _idle():
		return false
	_check(bool(session.board.at(10).face), "パッドRBで選択中の霊を登場させる")
	return await _move_and_drag()


func _move_and_drag() -> bool:
	var moving_uid: int = int(session.board.at(10).uid)
	await _click("cell-10")
	await _click("cell-9")
	if not await _idle():
		return false
	_check(int(session.board.at(9).get("uid", -1)) == moving_uid
		and session.board.at(10).is_empty(), "隣の空きマスへ霊を移動する")
	var hand_index: int = _strongest_hand()
	var chosen: String = str(session.board.hands[0][hand_index])
	await _drag("hand-%d" % hand_index, "cell-6")
	if not await _idle():
		return false
	if not _check(str(session.board.at(6).get("card", "")) == chosen,
			"手札のドラッグで霊を配置する"):
		return false
	return await _attack_and_save()


func _attack_and_save() -> bool:
	await _tap_key(KEY_B)
	if not await _idle():
		return false
	_check(session.board.phase == "battle", "Bで戦闘の段階へ進む")
	var attack_count: int = _event_count("attack", 0)
	await _click("cell-6")
	await _click("cell-7")
	if not await _idle():
		return false
	_check(_event_count("attack", 0) == attack_count + 1,
		"隣接する敵を選ぶと正規の攻撃が実行される")
	var board_data: Dictionary = session.board.to_data()
	await _click("save")
	await _click("resume")
	return _check(session.screen == "battle" and session.board.to_data() == board_data,
		"保存して再開すると盤面・手札・手番・行動済み状態が復元される") and not failed


func _result_inputs() -> bool:
	await _click("abandon")
	_check(session.screen == "battle" and main.battle_view.confirmed_abandon,
		"断念は最初の操作では確定しない")
	await _click("abandon")
	if not _check(session.screen == "result" and str(session.run.result) == "defeat",
			"断念の確認操作で敗北結果へ進む"):
		return false
	await _tap_key(KEY_ENTER)
	return _check(session.screen == "title", "Enterで結果からタイトルへ戻る")


func _choose_kind(kind: String) -> bool:
	var row: Array = session.run.nodes[int(session.run.depth)]
	for index: int in row.size():
		if str(row[index].kind) == kind:
			return await _click("route-%d" % index)
	return _check(false, "現在の夜路に%sがある" % kind)


func _enter_seed() -> void:
	await _click("seed")
	for digit: String in "222223":
		var down: InputEventKey = InputEventKey.new()
		down.keycode = digit.unicode_at(0)
		down.physical_keycode = digit.unicode_at(0)
		down.unicode = digit.unicode_at(0)
		down.pressed = true
		_send(down)
		await _frames(1)
		var up: InputEventKey = down.duplicate()
		up.pressed = false
		_send(up)
		await _frames(1)


func _strongest_hand() -> int:
	var best: int = 0
	var power: int = -1
	var hand: Array = session.board.hands[0]
	for index: int in hand.size():
		var candidate: int = int(Catalog.card(str(hand[index])).atk)
		if candidate > power:
			power = candidate
			best = index
	return best


func _find_tag(tag: String, parent: Node = null) -> Control:
	if parent == null:
		parent = main
	if parent is Control and str(parent.get_meta("tag", "")) == tag:
		return parent
	for child: Node in parent.get_children():
		var found: Control = _find_tag(tag, child)
		if found != null:
			return found
	return null


func _click(tag: String) -> bool:
	var control: Control = _find_tag(tag)
	if not _check(control != null and control.is_visible_in_tree(), tag + "が表示されている"):
		return false
	if control is Button and not _check(not control.disabled, tag + "を操作できる"):
		return false
	var point: Vector2 = control.get_global_rect().get_center()
	_move_mouse(point)
	await _frames(1)
	_mouse_button(point, true)
	await _frames(1)
	_mouse_button(point, false)
	await _frames(3)
	return true


func _drag(from: String, to: String) -> bool:
	var source: Control = _find_tag(from)
	var target: Control = _find_tag(to)
	if not _check(source != null and target != null, "ドラッグの始点と終点がある"):
		return false
	var start: Vector2 = source.get_global_rect().get_center()
	var end: Vector2 = target.get_global_rect().get_center()
	_move_mouse(start)
	await _frames(1)
	_mouse_button(start, true)
	await _frames(2)
	for step: int in range(1, 9):
		_move_mouse(start.lerp(end, step / 8.0), true)
		await _frames(1)
	_mouse_button(end, false)
	await _frames(3)
	return true


func _tap_key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var input: InputEventKey = InputEventKey.new()
		input.keycode = key
		input.physical_keycode = key
		input.pressed = pressed
		_send(input)
		await _frames(2)
	await _frames(2)


func _tap_button(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var input: InputEventJoypadButton = InputEventJoypadButton.new()
		input.device = 0
		input.button_index = button
		input.pressed = pressed
		_send(input)
		await _frames(2)
	await _frames(2)


func _move_mouse(point: Vector2, dragging: bool = false) -> void:
	var input: InputEventMouseMotion = InputEventMouseMotion.new()
	input.position = point
	input.global_position = point
	input.relative = point - root.get_mouse_position()
	input.button_mask = MOUSE_BUTTON_MASK_LEFT if dragging else 0
	_send(input)


func _mouse_button(point: Vector2, pressed: bool) -> void:
	var input: InputEventMouseButton = InputEventMouseButton.new()
	input.position = point
	input.global_position = point
	input.button_index = MOUSE_BUTTON_LEFT
	input.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	input.pressed = pressed
	_send(input)


func _send(input: InputEvent) -> void:
	Input.parse_input_event(input)
	Input.flush_buffered_events()


func _frames(count: int) -> void:
	for _frame: int in count:
		await process_frame


func _idle() -> bool:
	var deadline: float = elapsed_seconds + WAIT_SECONDS
	await _frames(2)
	while is_instance_valid(main.battle_view) and main.battle_view.busy:
		if elapsed_seconds > deadline:
			return _check(false, "戦闘の演出が5秒以内に完了する")
		await process_frame
	await _frames(3)
	return true


func _record_event(detail: Dictionary) -> void:
	if bool(detail.get("ok", false)):
		recorded_events.append(detail.duplicate(true))


func _event_count(kind: String, side: int) -> int:
	var count: int = 0
	for detail: Dictionary in recorded_events:
		if str(detail.get("type", "")) == kind and int(detail.get("side", -1)) == side:
			count += 1
	return count


func _check(condition: bool, label: String) -> bool:
	if not condition:
		failed = true
		push_error("入力検証: " + label)
	return condition


func _finish(success: bool) -> void:
	AudioStop.stop(root)
	await create_timer(0.2).timeout
	if success:
		print("integration OK")
	quit(0 if success else 1)
