extends SceneTree
## キー・ゲームパッド・マウスを実際の入力経路へ投入する統合検証。

const Demo = preload("res://scripts/dev/demo.gd")

var main: Node
var run: Node
var failures: Array[String] = []


func _initialize() -> void:
	_verify.call_deferred()


## 操作でゲーム進行を変える検証なので、同じ実行を重ねない。
func _verify() -> void:
	run = root.get_node("RunState")
	run.save_enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	_check(run.status == "title", "初期画面がタイトル")
	await _keyboard_cycle()
	await _gamepad_cycle()
	await _mouse_cycle()
	await root.get_node("Sound").shutdown()
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("integration OK: キーボード・ゲームパッドボタン/軸・マウスの実入力")
	quit(0 if failures.is_empty() else 1)


func _keyboard_cycle() -> void:
	await _key(KEY_RIGHT)
	await _key(KEY_ENTER)
	_check(main.modal_kind == "help", "キーでタイトルの手引きを開く")
	await _key(KEY_ESCAPE)
	_check(main.modal_kind.is_empty(), "タイトルの手引きを Esc で閉じる")
	await _key(KEY_ENTER)
	_check(run.status == "playing", "Enter で開始")
	if run.status != "playing":
		return
	run.start_run(Demo.DEMO_SEED)
	var before: Vector2i = run.player_pos
	var direction: Vector2i = _open_direction(false)
	await _key(Demo.STEP_KEYS[direction])
	_check(run.player_pos == before + direction, "キーで通常移動")
	before = run.player_pos
	direction = _open_direction(true)
	await _key(Demo.STEP_KEYS[direction])
	_check(run.player_pos == before + direction, "Q E Z C で斜め移動")
	var turns: int = run.turns
	await _key(KEY_I)
	_check(main.modal_kind == "inventory", "I で道具一覧")
	await _key(KEY_ENTER)
	_check(main.modal_kind == "item", "Enter で道具詳細")
	await _key(KEY_ENTER)
	_check(main.modal_kind.is_empty() and run.turns == turns + 1, "Enter で装備し一手消費")
	await _key(KEY_I)
	await _key(KEY_ESCAPE)
	_check(main.modal_kind.is_empty(), "Esc で道具から戻る")
	turns = run.turns
	await _key(KEY_ESCAPE)
	_check(main.modal_kind == "pause", "Esc で中断")
	await _key(KEY_D)
	_check(run.turns == turns, "中断中の移動はターンを進めない")
	await _key(KEY_ESCAPE)
	_check(main.modal_kind.is_empty(), "Esc で中断から復帰")
	await _finish_to_title("keyboard")


func _gamepad_cycle() -> void:
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	await _pad(JOY_BUTTON_A)
	_check(main.modal_kind == "help", "ゲームパッドでタイトルの手引きを開く")
	await _pad(JOY_BUTTON_B)
	_check(main.modal_kind.is_empty(), "タイトルの手引きを B で閉じる")
	await _pad(JOY_BUTTON_A)
	_check(run.status == "playing", "ゲームパッド A で開始")
	if run.status != "playing":
		return
	run.start_run(Demo.DEMO_SEED)
	var before: Vector2i = run.player_pos
	var direction: Vector2i = _open_direction(false)
	var buttons: Dictionary = {
		Vector2i.LEFT: JOY_BUTTON_DPAD_LEFT, Vector2i.RIGHT: JOY_BUTTON_DPAD_RIGHT,
		Vector2i.UP: JOY_BUTTON_DPAD_UP, Vector2i.DOWN: JOY_BUTTON_DPAD_DOWN,
	}
	await _pad(buttons[direction])
	_check(run.player_pos == before + direction, "十字キーで移動")
	before = run.player_pos
	direction = _open_direction(true)
	await _stick(direction)
	_check(run.player_pos == before + direction, "左スティックの二軸で斜め移動")
	var turns: int = run.turns
	await _pad(JOY_BUTTON_Y)
	_check(main.modal_kind == "inventory", "Y で道具一覧")
	await _pad(JOY_BUTTON_A)
	_check(main.modal_kind == "item", "A で道具詳細")
	await _pad(JOY_BUTTON_A)
	_check(run.turns == turns + 1 and main.modal_kind.is_empty(), "A で道具を使用")
	await _pad(JOY_BUTTON_Y)
	await _pad(JOY_BUTTON_B)
	_check(main.modal_kind.is_empty(), "B で道具から戻る")
	await _pad(JOY_BUTTON_B)
	_check(main.modal_kind == "pause", "B で中断")
	await _pad(JOY_BUTTON_A)
	_check(main.modal_kind.is_empty(), "A で探索を続ける")
	await _finish_to_title("gamepad")


func _mouse_cycle() -> void:
	await _click("深層へ潜る")
	_check(run.status == "playing", "マウスで開始")
	if run.status != "playing":
		return
	var herbs: int = run.inventory.count("herb")
	var turns: int = run.turns
	await _click("道具  I")
	_check(main.modal_kind == "inventory", "マウスで道具一覧")
	await _click("灯り草")
	_check(main.modal_kind == "item", "マウスで消費アイテム選択")
	await _click("道具一覧へ")
	_check(main.modal_kind == "inventory", "マウスで詳細から一覧へ")
	await _click("灯り草")
	await _click("使う / 装備")
	_check(run.inventory.count("herb") == herbs - 1, "マウスで灯り草を消費")
	_check(run.turns == turns + 1, "道具使用は一手だけ消費")
	await _click("道具  I")
	await _click("戻る")
	_check(main.modal_kind.is_empty(), "マウスで一覧から戻る")
	await _finish_to_title("mouse")


func _finish_to_title(device: String) -> void:
	if device == "gamepad":
		await _pad(JOY_BUTTON_B)
		await _pad(JOY_BUTTON_DPAD_RIGHT)
		await _pad(JOY_BUTTON_A)
	elif device == "keyboard":
		await _key(KEY_ESCAPE)
		await _key(KEY_RIGHT)
		await _key(KEY_ENTER)
	else:
		await _key(KEY_ESCAPE)
		await _click("旅を諦める")
	_check(run.status == "dead", "中断から結果へ")
	for attempt: int in range(30):
		if main.current_screen == run.status:
			break
		await create_timer(0.05).timeout
	_check(main.current_screen == "dead", "死亡演出後に結果画面が表示される")
	if main.current_screen != "dead":
		return
	if device == "gamepad":
		await _pad(JOY_BUTTON_DPAD_RIGHT)
		await _pad(JOY_BUTTON_A)
	elif device == "keyboard":
		await _key(KEY_RIGHT)
		await _key(KEY_ENTER)
	else:
		await _click("タイトルへ")
	_check(run.status == "title", "結果からタイトルへ")


func _open_direction(diagonal: bool) -> Vector2i:
	for direction: Vector2i in Demo.STEP_KEYS:
		if (direction.x != 0 and direction.y != 0) != diagonal:
			continue
		if run.dungeon.can_step(run.player_pos, run.player_pos + direction):
			return direction
	_check(false, "検証に使う移動先が存在する")
	return Vector2i.RIGHT


## 押下・解放の間にフレームを進め、実際の GUI と入力判定を通す。
func _key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	await _press(event)


func _pad(button: JoyButton) -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	await _press(event)


func _press(event: InputEvent) -> void:
	event.set("pressed", true)
	Input.parse_input_event(event)
	await process_frame
	var release: InputEvent = event.duplicate()
	release.set("pressed", false)
	Input.parse_input_event(release)
	await create_timer(0.25).timeout


func _stick(direction: Vector2i) -> void:
	for axis: JoyAxis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
		event.axis = axis
		event.axis_value = direction.x if axis == JOY_AXIS_LEFT_X else direction.y
		Input.parse_input_event(event)
	await process_frame
	await process_frame
	for axis: JoyAxis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var release: InputEventJoypadMotion = InputEventJoypadMotion.new()
		release.axis = axis
		release.axis_value = 0.0
		Input.parse_input_event(release)
	await create_timer(0.25).timeout


func _click(caption: String) -> void:
	var button: Button = Demo.find_button(main, caption)
	if button == null:
		_check(false, "ボタンが見つかる: " + caption)
		return
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = root.get_final_transform() * button.get_global_rect().get_center()
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	await _press(event)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
