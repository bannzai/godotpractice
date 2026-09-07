extends SceneTree
## 本番シーンに実入力を送り、操作・保存復帰を検査する。入力順を進めるため非冪等。

const SAVE_PATH: String = "res://tmp/integration-save.json"
const TEST_SEED: int = 240907
const DIRECTIONS: Array[int] = [
	JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT
]

var main: Control
var run: Node
var failures: Array[String] = []
var checks: int = 0
var finished: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	run = root.get_node("Run")
	run.save_path = SAVE_PATH
	# 再現用の初期値だけを固定する。盤面・手札・乱数は本番の開始操作で生成する。
	run.collection.clear()
	var packed: PackedScene = load("res://scenes/main.tscn")
	main = packed.instantiate()
	root.add_child(main)
	current_scene = main
	create_timer(120.0).timeout.connect(_timeout)
	await _frames(4)
	if await _title_and_route():
		if await _battle_operations():
			if await _save_and_resume():
				await _save_failure()
				if await _attack_input_cases():
					await _turn_and_result()
					await _finished_battle_resume()
	await _finish()


func _title_and_route() -> bool:
	_expect(run.stage == "title" and _focus_name() == "start", "タイトルの開始ボタンにフォーカス")
	await _tap_key(KEY_DOWN)
	_expect(_focus_name() != "start", "矢印キーでタイトルのフォーカス移動")
	if not await _navigate_to("start"):
		return false
	main.seed_input.text = str(TEST_SEED)
	await _tap_key(KEY_ENTER)
	if not _expect(run.stage == "map" and run.seed_value == TEST_SEED, "Enter で固定 seed の旅を開始"):
		return false
	_expect(_focus_name() == "route_0_0", "地図の先頭の道にフォーカス")
	await _tap_button(JOY_BUTTON_DPAD_DOWN)
	_expect(_focus_name() == "route_0_1", "十字キーで下側の道を選択")
	await _move_axis(JOY_AXIS_LEFT_Y, -1.0)
	_expect(_focus_name() == "route_0_0", "左スティックで上側の道を選択")
	await _tap_key(KEY_DOWN)
	_expect(_focus_name() == "route_0_1", "矢印キーで地図の道を選択")
	await _tap_key(KEY_UP)
	await _tap_button(JOY_BUTTON_A)
	await _idle()
	return _expect(run.stage == "battle" and run.depth == 0, "A で道を決定して戦闘へ進む")


func _battle_operations() -> bool:
	await _click_control("hand_0")
	_expect(main.selected_hand == 0, "マウスで手札を選択")
	await _tap_key(KEY_ESCAPE)
	_expect(main.selected_hand == -1 and main.overlay.is_empty(), "Esc で手札の選択を解除")
	if not await _navigate_to("hand_0"):
		return false
	await _tap_button(JOY_BUTTON_A)
	_expect(main.selected_hand == 0, "A で手札を選択")
	await _tap_button(JOY_BUTTON_B)
	_expect(main.selected_hand == -1 and main.overlay.is_empty(), "B で手札の選択を解除")
	var count: int = run.battle.hands[0].size()
	await _click_control("hand_0")
	await _click_control("cell_0_3")
	await _idle()
	var unit: Dictionary = run.battle.unit_at(Vector2i(0, 3))
	if not _expect(not unit.is_empty(), "手札クリックから自陣クリックで潜伏"):
		return false
	_expect(not unit.face and run.battle.hands[0].size() == count - 1, "潜伏した札は裏向きで手札から除かれる")
	var uid: int = unit.uid
	await _tap_key(KEY_R)
	await _idle()
	_expect(run.battle.unit_by_id(uid).face, "R で選択した伏せ札が登場")
	if not await _navigate_to("move"):
		return false
	await _tap_button(JOY_BUTTON_A)
	_expect(main.mode == "move", "パッドで移動ボタンを選んで移動先の選択へ進む")
	if not await _navigate_to("cell_0_2"):
		return false
	await _tap_button(JOY_BUTTON_A)
	await _idle()
	unit = run.battle.unit_at(Vector2i(0, 2))
	_expect(not unit.is_empty() and unit.uid == uid and unit.moved, "パッドで移動先を決定して一マス移動")
	count = run.battle.hands[0].size()
	await _tap_key(KEY_ESCAPE)
	_expect(main.detail_id.is_empty(), "直接ドラッグの前に札の詳細を解除")
	await _drag("hand_0", "cell_1_3")
	await _idle()
	unit = run.battle.unit_at(Vector2i(1, 3))
	if not _expect(not unit.is_empty(), "マウスの押下・移動・解放で手札をドラッグ配置"):
		return false
	_expect(not unit.face and run.battle.hands[0].size() == count - 1, "ドラッグ配置は手札を一枚だけ消費")
	_expect(main.detail_id == unit.card, "直接ドラッグ配置した札の詳細を表示")
	var reveal: Button = _control("reveal") as Button
	_expect(reveal != null and not reveal.disabled, "直接ドラッグ直後に登場ボタンを操作できる")
	uid = unit.uid
	await _tap_button(JOY_BUTTON_X)
	await _idle()
	_expect(run.battle.unit_by_id(uid).face, "X でドラッグ配置した札が登場")
	return true


func _save_and_resume() -> bool:
	var before: Dictionary = run.snapshot()
	await _tap_key(KEY_ESCAPE)
	await _tap_button(JOY_BUTTON_B)
	if not _expect(main.overlay == "pause", "B で休止メニューを開く"):
		return false
	await _check_modal_focus(["continue", "save_title", "concede", "close_modal"])
	await _tap_button(JOY_BUTTON_B)
	_expect(main.overlay.is_empty() and run.snapshot() == before, "B で休止から同じ盤面へ戻る")
	await _click_control("help")
	_expect(main.overlay == "help", "遊び方を開く")
	await _check_modal_focus(["close_modal"])
	await _tap_key(KEY_ESCAPE)
	_expect(main.overlay.is_empty(), "Esc で遊び方を閉じる")
	await _tap_key(KEY_ESCAPE)
	if not await _navigate_to("save_title"):
		return false
	await _tap_button(JOY_BUTTON_A)
	if not _expect(run.stage == "title", "パッドで保存してタイトルへ戻る"):
		return false
	_expect(run.has_save(), "保存した旅を再開できる")
	if not await _navigate_to("resume"):
		return false
	await _tap_button(JOY_BUTTON_A)
	await _idle()
	return _expect(run.stage == "battle" and run.snapshot() == before, "A で保存から再開し盤面・手札・乱数が一致")


func _save_failure() -> void:
	var before: Dictionary = run.snapshot()
	var missing_dir: String = "res://tmp/存在しない保存先"
	if not _expect(not DirAccess.dir_exists_absolute(missing_dir), "保存失敗検査用の親ディレクトリは存在しない"):
		return
	await _tap_button(JOY_BUTTON_B)
	if not await _navigate_to("save_title"):
		return
	# 書き込み先だけを失敗する fixture に替え、保存と画面遷移は本番のボタン操作で実行する。
	run.save_path = missing_dir + "/save.json"
	await _tap_button(JOY_BUTTON_A)
	_expect(run.snapshot() == before, "保存失敗時は元の戦闘と旅の状態を維持")
	_expect(not run.save_error.is_empty(), "保存失敗の理由が記録される")
	_expect(_save_error_is_visible(), "保存失敗の理由をモーダルに隠れないラベルで表示")
	run.save_path = SAVE_PATH
	_expect(run.save_run() and run.save_error.is_empty(), "正常な保存先に戻すと保存とエラー解除が成功")
	if not main.overlay.is_empty():
		await _tap_button(JOY_BUTTON_B)


func _attack_input_cases() -> bool:
	var before: Dictionary = run.snapshot()
	var before_note: String = main.note
	for source: String in ["マウス", "キーボード", "ゲームパッド"]:
		await _attack_unit_case(source)
		await _attack_king_case(source)
	var restored: bool = run.restore(before)
	_expect(restored, "攻撃入力検査後に元の自然対局を復元")
	if not restored:
		return false
	main.note = before_note
	main.busy = false
	main.overlay = ""
	main._clear_selection()
	main._render()
	await _frames(3)
	return _expect(run.save_run(), "攻撃入力検査後の自然対局を保存し直す")


func _attack_unit_case(source: String) -> void:
	await _prepare_attack_fixture(false)
	var battle: RefCounted = run.battle
	_expect(battle.can_attack(1, 2), "%s入力前に朱の剣客から夜渡りへの攻撃が合法" % source)
	if not await _activate_attack(source, "cell_1_1", "cell_1_0"):
		return
	await _idle()
	var victor: Dictionary = battle.unit_by_id(1)
	_expect(battle.unit_by_id(2).is_empty(), "%sでATK比較に勝った夜渡りを盤面から除く" % source)
	_expect(battle.discards[1] == ["veil"], "%sで倒した夜渡りを敵の捨て場へ送る" % source)
	_expect(
		not victor.is_empty() and BoardBattle.position(victor) == Vector2i(1, 0),
		"%sで勝った朱の剣客が夜渡りのマスへ進む" % source
	)
	_expect(not victor.is_empty() and victor.attacked, "%sの攻撃権を使用済みにする" % source)
	_expect(battle.hp == [10, 10], "%sの札同士の攻撃では王の体力を変えない" % source)


func _attack_king_case(source: String) -> void:
	await _prepare_attack_fixture(true)
	var battle: RefCounted = run.battle
	_expect(battle.can_attack(1), "%s入力前に朱の剣客から敵王への攻撃が合法" % source)
	if not await _activate_attack(source, "cell_1_0", "enemy_king"):
		return
	await _idle()
	var attacker: Dictionary = battle.unit_by_id(1)
	_expect(battle.hp[1] == 7, "%sで朱の剣客のATK3だけ敵王の体力を減らす" % source)
	_expect(not attacker.is_empty() and attacker.attacked, "%sの敵王攻撃を使用済みにする" % source)
	_expect(battle.discards == [[], []], "%sの敵王攻撃では札を捨て場へ送らない" % source)


func _prepare_attack_fixture(king_target: bool) -> void:
	var battle: RefCounted = run.battle
	battle.width = 3
	battle.units.assign(
		[
			{
				"uid": 1,
				"card": "blade",
				"side": 0,
				"x": 1,
				"y": 0 if king_target else 1,
				"face": true,
				"moved": false,
				"attacked": false,
				"effect_used": false,
			}
		]
	)
	if not king_target:
		battle.units.append(
			{
				"uid": 2,
				"card": "veil",
				"side": 1,
				"x": 1,
				"y": 0,
				"face": true,
				"moved": false,
				"attacked": false,
				"effect_used": false,
			}
		)
	battle.hands = [[], []]
	battle.decks = [[], []]
	battle.discards = [[], []]
	battle.hp.assign([10, 10])
	battle.turn = 0
	battle.phase = "battle"
	battle.winner = -1
	battle.turn_number = 1
	battle.enemy_id = "scout"
	battle.swapped = false
	battle.next_uid = 3
	main.busy = false
	main.overlay = ""
	main._clear_selection()
	main.note = "攻撃入力の検査"
	root.gui_release_focus()
	main._render()
	await _frames(3)
	var start: Control = _control("cell_1_2")
	if _expect(start != null, "攻撃入力検査の開始マスが存在"):
		start.grab_focus()


func _activate_attack(source: String, attacker_name: String, target_name: String) -> bool:
	match source:
		"マウス":
			return await _activate_attack_mouse(attacker_name, target_name)
		"キーボード":
			return await _activate_attack_keyboard(attacker_name, target_name)
		"ゲームパッド":
			return await _activate_attack_gamepad(attacker_name, target_name)
		_:
			return _expect(false, "未知の攻撃入力系統: " + source)


func _activate_attack_mouse(attacker_name: String, target_name: String) -> bool:
	await _click_control(attacker_name)
	if not _expect(main.selected_uid == 1, "マウスで攻撃する朱の剣客を選択"):
		return false
	await _click_control(target_name)
	return true


func _activate_attack_keyboard(attacker_name: String, target_name: String) -> bool:
	if not await _navigate_to_key(attacker_name):
		return false
	await _tap_key(KEY_ENTER)
	if not _expect(main.selected_uid == 1, "Enterで攻撃する朱の剣客を選択"):
		return false
	if not await _navigate_to_key(target_name):
		return false
	await _tap_key(KEY_ENTER)
	return true


func _activate_attack_gamepad(attacker_name: String, target_name: String) -> bool:
	if not await _navigate_to(attacker_name):
		return false
	await _tap_button(JOY_BUTTON_A)
	if not _expect(main.selected_uid == 1, "Aで攻撃する朱の剣客を選択"):
		return false
	if not await _navigate_to(target_name):
		return false
	await _tap_button(JOY_BUTTON_A)
	return true


func _save_error_is_visible() -> bool:
	for child: Node in main.content.find_children("*", "Label", true, false):
		var label: Label = child as Label
		if label.text != run.save_error or not label.is_visible_in_tree():
			continue
		var close: Control = _control("close_modal")
		if close == null:
			return true
		var shield: Node = close.get_parent()
		if shield.is_ancestor_of(label):
			return true
		var layer: Node = label
		while layer.get_parent() != main.content:
			layer = layer.get_parent()
		if layer.get_index() > shield.get_index():
			return true
	return false


func _finished_battle_resume() -> void:
	if not _expect(run.stage == "map", "決着済み保存の検査を新しい旅の地図から開始"):
		return
	await _tap_button(JOY_BUTTON_A)
	await _idle()
	if not _expect(run.stage == "battle", "決着済み保存の検査用の戦闘を実入力で開始"):
		return
	# 決着演出中の終了を再現する fixture。盤面を注入せず双方を合法 AI で進め、
	# 戦闘が終わりランへ結果を反映する前の正規 snapshot を保存する。
	var actions: int = 0
	while run.battle.phase != "over" and actions < 1800:
		if not _expect(run.battle.ai_step().ok, "決着済み保存を生成する AI 操作は合法"):
			return
		actions += 1
	if not _expect(run.battle.phase == "over", "合法 AI が 1800 操作以内に決着"):
		return
	var expected_stage: String = "reward" if run.battle.winner == 0 else "result"
	if not _expect(run.save_run(), "結果反映前の決着済み戦闘を正規形式で保存"):
		return
	run.stage = "title"
	main._render()
	await _frames(3)
	if not await _navigate_to("resume"):
		return
	await _tap_button(JOY_BUTTON_A)
	await _idle()
	_expect(run.stage == expected_stage, "決着済み保存の再開時に報酬または結果へ進む")
	_expect(not main.busy, "決着済み保存の再開後に次の操作を受け付ける")
	print("決着済み保存の回帰検査: 合法 AI ", actions, " 操作 → ", expected_stage)


func _turn_and_result() -> void:
	var previous_turn: int = run.battle.turn_number
	await _tap_key(KEY_E)
	await _idle()
	_expect(run.battle.phase == "battle", "E で準備から攻撃フェーズへ進む")
	await _tap_button(JOY_BUTTON_Y)
	await _idle()
	_expect(
		run.stage == "battle" and run.battle.turn == 0
		and run.battle.turn_number == previous_turn + 2 and run.battle.phase == "standby",
		"Y で手番を終了し合法 AI の手番後に準備へ戻る"
	)
	await _tap_key(KEY_ESCAPE)
	if main.overlay.is_empty():
		await _tap_key(KEY_ESCAPE)
	if not await _navigate_to("concede"):
		return
	await _tap_button(JOY_BUTTON_A)
	if not _expect(run.stage == "result" and not run.won, "休止メニューから降参して結果画面へ進む"):
		return
	_expect(not run.has_save(), "終了した旅は続きから再開できない")
	await _tap_button(JOY_BUTTON_A)
	_expect(run.stage == "title", "結果画面から A でタイトルへ戻る")
	await _collection_navigation()
	main.seed_input.text = str(TEST_SEED)
	if not await _navigate_to("start"):
		return
	await _tap_button(JOY_BUTTON_A)
	_expect(run.stage == "map" and run.depth == -1, "タイトルから A で新しい旅を開始できる")


func _collection_navigation() -> void:
	await _click_control("book")
	_expect(main.overlay == "book", "タイトルから札の図鑑を開く")
	var scroll: ScrollContainer
	for child: Node in _control("close_modal").get_parent().get_children():
		if child is ScrollContainer:
			scroll = child
	if not _expect(scroll != null, "図鑑のスクロール領域が存在"):
		return
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	if bar.max_value > bar.page:
		for index: int in range(12):
			await _tap_button(JOY_BUTTON_DPAD_DOWN)
		_expect(scroll.scroll_vertical > 0, "パッドで図鑑の下段の札を閲覧できる")
	await _tap_button(JOY_BUTTON_B)
	_expect(main.overlay.is_empty(), "B で図鑑を閉じる")


func _check_modal_focus(allowed: Array[String]) -> void:
	var initial: String = _focus_name()
	for direction: int in DIRECTIONS:
		_control(initial).grab_focus()
		await _tap_button(direction)
		_expect(_focus_name() in allowed, "モーダル内にパッドのフォーカスが留まる: %s" % _focus_name())
	_control(initial).grab_focus()


func _navigate_to(target: String) -> bool:
	# 実入力で辿れるフォーカスの隣接関係を探索し、開始位置から同じ入力列を再生する。
	# 探索の枝を戻す時だけ grab_focus を使い、決定は常に本番への入力で行う。
	var initial: String = _focus_name()
	var pending: Array[String] = [initial]
	var paths: Dictionary = {initial: []}
	while not pending.is_empty() and paths.size() <= 80:
		var current: String = pending.pop_front()
		if current == target:
			_control(initial).grab_focus()
			for direction: int in paths[current]:
				await _tap_button(direction)
			return _expect(_focus_name() == target, "パッドで %s に到達" % target)
		for direction: int in DIRECTIONS:
			var origin: Control = _control(current)
			if origin == null:
				continue
			origin.grab_focus()
			await _tap_button(direction)
			var next: String = _focus_name()
			if not next.is_empty() and not paths.has(next):
				paths[next] = paths[current].duplicate()
				paths[next].append(direction)
				pending.append(next)
	return _expect(false, "パッドで到達できない UI: %s（開始 %s）" % [target, initial])


func _navigate_to_key(target: String) -> bool:
	var directions: Array[Key] = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]
	var initial: String = _focus_name()
	var pending: Array[String] = [initial]
	var paths: Dictionary = {initial: []}
	while not pending.is_empty() and paths.size() <= 80:
		var current: String = pending.pop_front()
		if current == target:
			_control(initial).grab_focus()
			for direction: Key in paths[current]:
				await _tap_key(direction)
			return _expect(_focus_name() == target, "キーボードで %s に到達" % target)
		for direction: Key in directions:
			var origin: Control = _control(current)
			if origin == null:
				continue
			origin.grab_focus()
			await _tap_key(direction)
			var next: String = _focus_name()
			if not next.is_empty() and not paths.has(next):
				paths[next] = paths[current].duplicate()
				paths[next].append(direction)
				pending.append(next)
	return _expect(false, "キーボードで到達できない UI: %s（開始 %s）" % [target, initial])


func _control(node_name: String) -> Control:
	return main.content.find_child(node_name, true, false) as Control


func _focus_name() -> String:
	var focused: Control = root.gui_get_focus_owner()
	return str(focused.name) if is_instance_valid(focused) else ""


func _tap_key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await _frames(1)


func _tap_button(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await _frames(1)


func _move_axis(axis: JoyAxis, value: float) -> void:
	for position: float in [value, 0.0]:
		var event := InputEventJoypadMotion.new()
		event.axis = axis
		event.axis_value = position
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await _frames(2)


func _click_control(node_name: String) -> void:
	var control: Control = _control(node_name)
	if not _expect(control != null, "クリック対象が存在: %s" % node_name):
		return
	var point: Vector2 = control.get_global_rect().get_center()
	await _mouse_motion(point, Vector2.ZERO)
	await _mouse_button(point, true)
	await _mouse_button(point, false)


func _drag(source_name: String, target_name: String) -> void:
	var start: Vector2 = _control(source_name).get_global_rect().get_center()
	var target: Vector2 = _control(target_name).get_global_rect().get_center()
	await _mouse_motion(start, Vector2.ZERO)
	await _mouse_button(start, true)
	var previous: Vector2 = start
	for step: int in range(1, 9):
		var point: Vector2 = start.lerp(target, step / 8.0)
		await _mouse_motion(point, point - previous, MOUSE_BUTTON_MASK_LEFT)
		previous = point
	await _mouse_button(target, false)


func _mouse_button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _frames(2)


func _mouse_motion(point: Vector2, relative: Vector2, mask: int = 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = relative
	event.button_mask = mask
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _frames(2)


func _frames(count: int) -> void:
	for index: int in range(count):
		await physics_frame
		await process_frame


func _idle() -> void:
	for index: int in range(900):
		await _frames(1)
		if not main.busy:
			await _frames(2)
			return
	_expect(false, "演出と敵手番が 900 フレーム以内に完了する")


func _expect(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures.append(message)
		print("integration FAIL: ", message)
	return condition


func _timeout() -> void:
	if not finished:
		_expect(false, "検証が 120 秒以内に完了する")
		await _finish()


func _finish() -> void:
	if finished:
		return
	finished = true
	main.stop_audio()
	await _frames(16)
	await create_timer(0.2).timeout
	if failures.is_empty():
		print("integration OK: ", checks, " 件の実入力検査")
	quit(0 if failures.is_empty() else 1)
