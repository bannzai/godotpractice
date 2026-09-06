extends SceneTree
## 実入力を画面へ渡し、操作・保存・勝敗までを検証する。通常の保存先は使わない。

var failed: bool = false
var city: Node
var main: Control


func _initialize() -> void:
	_run.call_deferred()


## シナリオ中にゲーム時間と入力を進めるため、一回の実行内では非冪等。
func _run() -> void:
	city = root.get_node("City")
	city.save_path = "res://tmp/integration-save.json"
	city.saving_enabled = false
	root.size = Vector2i(1280, 720)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	_check(city.phase == "title", "起動時タイトル")
	_check_fullscreen_mapping()
	await _key(KEY_ENTER)
	_check(city.phase == "playing", "Enter で新しい街を開始")
	if city.phase == "playing":
		await _keyboard_and_mouse()
		await _save_and_resume()
		await _gamepad()
		await _win()
		await _lose()
	await root.get_node("Sound").shutdown()
	main.queue_free()
	await process_frame
	if failed:
		quit(1)
	else:
		print("integration OK")
		quit(0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("入力検証 OK: " + label)
	else:
		failed = true
		push_error("入力検証 FAIL: " + label)


func _keyboard_and_mouse() -> void:
	await _key(KEY_SPACE)
	_check(city.speed == 0, "Space で時間停止")
	await _key(KEY_T)
	_check(city.speed == 1, "T で停止から1倍へ")
	await _key(KEY_T)
	_check(city.speed == 3, "T で1倍から3倍へ")
	await _key(KEY_T)
	_check(city.speed == 0, "T で3倍から停止へ")
	var original_tax: int = city.state.tax
	await _key(KEY_Z)
	_check(city.state.tax == original_tax - 1, "Z で税率を下げる")
	await _key(KEY_C)
	_check(city.state.tax == original_tax, "C で税率を上げる")
	var cursor: Vector2i = main.view.cursor
	await _key(KEY_RIGHT)
	_check(main.view.cursor == cursor + Vector2i.RIGHT, "方向キーでカーソル移動")
	await _key(KEY_LEFT)
	await _key(KEY_E)
	_check(main.selected_tool == 2, "E で商業へ切替")
	await _key(KEY_Q)
	_check(main.selected_tool == 1, "Q で住宅へ切替")
	await _key(KEY_ENTER)
	_check(_tile(cursor).kind == "residential", "Enter で住宅建設")
	var money: int = city.state.money
	await _key(KEY_ENTER)
	_check(city.state.money == money, "同一マスへの連続入力は二重課金しない")
	var first: Vector2 = _point(Vector2i(8, 16))
	var second: Vector2 = _point(Vector2i(9, 16))
	await _mouse_button(first, MOUSE_BUTTON_LEFT, true)
	await _motion(second, second - first, MOUSE_BUTTON_MASK_LEFT)
	await _mouse_button(second, MOUSE_BUTTON_LEFT, false)
	_check(_tile(Vector2i(8, 16)).kind == "residential", "マウス押下で建設")
	_check(_tile(Vector2i(9, 16)).kind == "residential", "マウスドラッグで連続建設")
	var zoom: float = main.view.zoom
	await _key(KEY_EQUAL)
	_check(main.view.zoom > zoom, "キーボードで拡大")
	await _key(KEY_MINUS)
	_check(is_equal_approx(main.view.zoom, zoom), "キーボードで縮小")
	await _mouse_button(_point(Vector2i(10, 16)), MOUSE_BUTTON_WHEEL_UP, true)
	await _mouse_button(_point(Vector2i(10, 16)), MOUSE_BUTTON_WHEEL_UP, false)
	_check(main.view.zoom > zoom, "ホイールで拡大")
	var pan: Vector2 = main.view.pan
	var origin: Vector2 = _point(Vector2i(10, 16))
	await _mouse_button(origin, MOUSE_BUTTON_RIGHT, true)
	await _motion(origin + Vector2(24, 18), Vector2(24, 18), MOUSE_BUTTON_MASK_RIGHT)
	await _mouse_button(origin + Vector2(24, 18), MOUSE_BUTTON_RIGHT, false)
	_check(main.view.pan.distance_to(pan) > 1.0, "右ドラッグでパン")
	await _click(Vector2(1180, 470))
	_check(city.state.tax > 9, "税率スライダーをマウスで操作")
	await _key(KEY_E)
	await _key(KEY_Q)
	await _key(KEY_O)
	_check(main.view.overlay == "power", "O で電力問題を表示")
	await _key(KEY_N)
	_check(city.state.month == 1, "N で翌月へ進行")


func _save_and_resume() -> void:
	city.saving_enabled = true
	var saved: Dictionary = city.state.duplicate(true)
	await _key(KEY_ESCAPE)
	city.saving_enabled = false
	_check(city.phase == "title", "Escape で保存してタイトル")
	_check(FileAccess.file_exists(city.save_path), "検証専用ファイルへ保存")
	_check(city.saved_city() == saved, "保存内容は現在の街と一致")
	_check_failed_save(saved)
	main.displayed_population = 9999.0
	await _click(Vector2(220, 540))
	_check(city.phase == "playing", "再開ボタンでプレイへ復帰")
	_check(city.state == saved, "再開後に資金・区画・月・税率を復元")
	_check(main.displayed_population == float(saved.population), "再開直後の人口表示を保存値に同期")
	_check(main.view.overlay == "power" and main.overlay_index == 1, "タイトルから再開しても電力表示と地図が一致")
	await _key(KEY_SPACE)
	await _key(KEY_ESCAPE)
	_check(city.phase == "title", "再開した街からタイトルへ戻る")


# 検証専用の空ディレクトリで書き込み失敗を再現し、片付けまで一巡する。
func _check_failed_save(saved: Dictionary) -> void:
	var temporary_path: String = city.save_path + ".tmp"
	_check(DirAccess.make_dir_absolute(temporary_path) == OK, "保存失敗の検証用障害を準備")
	city.saving_enabled = true
	city.state.money += 1
	_check(not city.save_city(), "一時保存先に書けない場合は失敗を返す")
	_check(city.saved_city() == saved, "保存失敗後も前回の街を保持")
	_check(DirAccess.remove_absolute(temporary_path) == OK, "保存失敗の検証用障害を解除")
	_check(city.save_city(), "障害解除後に保存を再試行できる")
	city.state = saved.duplicate(true)
	_check(city.save_city(), "次の操作へ保存状態を復元")
	city.saving_enabled = false


func _gamepad() -> void:
	await _pad(JOY_BUTTON_A)
	_check(city.phase == "playing", "パッド A で新しい街を開始")
	if city.phase != "playing":
		return
	await _pad(JOY_BUTTON_START)
	_check(city.speed == 0, "パッド Start で時間停止")
	_check(main.view.overlay == "power" and main.overlay_index == 1, "タイトルから新規開始しても問題表示と地図が一致")
	await _pad(JOY_BUTTON_BACK)
	_check(city.speed == 1, "パッド Back で停止から1倍へ")
	await _pad(JOY_BUTTON_BACK)
	_check(city.speed == 3, "パッド Back で1倍から3倍へ")
	await _pad(JOY_BUTTON_BACK)
	_check(city.speed == 0, "パッド Back で3倍から停止へ")
	var original_tax: int = city.state.tax
	await _axis(JOY_AXIS_TRIGGER_LEFT)
	_check(city.state.tax == original_tax - 1, "左トリガで税率を下げる")
	await _axis(JOY_AXIS_TRIGGER_RIGHT)
	_check(city.state.tax == original_tax, "右トリガで税率を上げる")
	await _analog_tax()
	await _pad(JOY_BUTTON_RIGHT_SHOULDER)
	_check(main.selected_tool == 2, "パッド RB で商業へ切替")
	await _pad(JOY_BUTTON_LEFT_SHOULDER)
	_check(main.selected_tool == 1, "パッド LB で住宅へ切替")
	var before: Vector2i = main.view.cursor
	await _pad(JOY_BUTTON_DPAD_DOWN)
	_check(main.view.cursor == before + Vector2i.DOWN, "パッド十字キーでカーソル移動")
	await _pad(JOY_BUTTON_A)
	_check(_tile(main.view.cursor).kind == "residential", "パッド A で住宅建設")
	var overlay: int = main.overlay_index
	await _pad(JOY_BUTTON_Y)
	_check(main.overlay_index == (overlay + 1) % 5, "パッド Y で問題表示")
	await _pad(JOY_BUTTON_X)
	_check(city.state.month == 1, "パッド X で翌月へ進行")
	await _key(KEY_ESCAPE)


func _win() -> void:
	await _key(KEY_ENTER)
	_check(city.phase == "playing", "クリアルートの街を開始")
	if city.phase != "playing":
		return
	await _key(KEY_SPACE)
	for x: int in range(8, 11):
		await _click(_point(Vector2i(x, 16)))
		_check(_tile(Vector2i(x, 16)).kind == "residential", "通常入力で住宅追加 %d,16" % x)
	city.saving_enabled = true
	for month: int in 9:
		await _key(KEY_N)
	city.saving_enabled = false
	_check(city.phase == "result", "通常プレイから結果画面へ遷移")
	_check(city.state.outcome == "clear" and city.state.population >= 600, "9月以内に人口600人クリア")
	await _key(KEY_ENTER)
	_check(city.phase == "title", "クリア結果から Enter でタイトル")
	await _resume_result("clear")


func _lose() -> void:
	await _pad(JOY_BUTTON_A)
	_check(city.phase == "playing", "敗北ルートの街を開始")
	if city.phase != "playing":
		return
	await _pad(JOY_BUTTON_START)
	# 資金だけを敗北直前へ準備し、税率と月送りは実入力で操作する。
	city.state.money = 0
	await _click(Vector2(981, 470))
	_check(city.state.tax == 0, "税率スライダーで無税を選択")
	await _pad(JOY_BUTTON_RIGHT_SHOULDER)
	await _pad(JOY_BUTTON_LEFT_SHOULDER)
	city.saving_enabled = true
	for month: int in 3:
		await _pad(JOY_BUTTON_X)
	city.saving_enabled = false
	_check(city.phase == "result" and city.state.outcome == "defeat", "3月赤字で敗北結果へ遷移")
	await _pad(JOY_BUTTON_A)
	_check(city.phase == "title", "敗北結果からパッド A でタイトル")
	await _resume_result("defeat")


func _tile(cell: Vector2i) -> Dictionary:
	return city.state.tiles[cell.y * 32 + cell.x]


func _point(cell: Vector2i) -> Vector2:
	return main.view.global_position + main.view.cell_to_screen(cell)


## 押下と解放を別フレームで注入し、実際の入力配送を通す。
func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
		await process_frame


func _pad(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventJoypadButton = InputEventJoypadButton.new()
		event.device = 0
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
		await process_frame


func _mouse_button(point: Vector2, button: MouseButton, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame
	await process_frame


func _motion(point: Vector2, relative: Vector2, mask: MouseButtonMask) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = relative
	event.button_mask = mask
	Input.parse_input_event(event)
	await process_frame
	await process_frame


func _click(point: Vector2) -> void:
	await _mouse_button(point, MOUSE_BUTTON_LEFT, true)
	await _mouse_button(point, MOUSE_BUTTON_LEFT, false)


func _check_fullscreen_mapping() -> void:
	var matching: bool = false
	for event: InputEvent in InputMap.action_get_events("fullscreen"):
		if event is InputEventKey and event.physical_keycode == KEY_F11:
			matching = true
	_check(matching, "全画面のキー設定が F11 の定数 %d に一致" % KEY_F11)
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_F11
	key.pressed = true
	_check(InputMap.event_is_action(key, "fullscreen"), "F11 の実キーイベントが全画面操作に対応")


## トリガを押して戻す。中立へ戻すフレームを挟み、次回の押下を独立して扱う。
func _axis(axis: JoyAxis, values: Array[float] = [0.0, 1.0, 0.0]) -> void:
	for value: float in values:
		var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
		event.device = 0
		event.axis = axis
		event.axis_value = value
		Input.parse_input_event(event)
		await process_frame
		await process_frame


func _analog_tax() -> void:
	var original: int = city.state.tax
	var movement: Array[float] = [0.0, 0.3, 0.6, 0.7, 0.8, 0.9, 1.0, 0.9, 0.7, 0.3, 0.0]
	await _axis(JOY_AXIS_TRIGGER_LEFT, movement)
	_check(city.state.tax == original - 1, "左トリガを徐々に押して戻しても減税は1段階")
	await _axis(JOY_AXIS_TRIGGER_LEFT, movement)
	_check(city.state.tax == original - 2, "左トリガを離して再度押すと次の1段階")
	await _axis(JOY_AXIS_TRIGGER_RIGHT, movement)
	_check(city.state.tax == original - 1, "右トリガを徐々に押して戻しても増税は1段階")
	await _axis(JOY_AXIS_TRIGGER_RIGHT, movement)
	_check(city.state.tax == original, "右トリガを離して再度押すと次の1段階")
	await _axis(JOY_AXIS_TRIGGER_LEFT, [0.0, 0.2, 0.4, 0.49, 0.3, 0.0])
	_check(city.state.tax == original, "トリガの閾値未満の揺れでは税率が変わらない")


func _resume_result(outcome: String) -> void:
	var expected: Dictionary = city.state.duplicate(true)
	var label: String = "クリア" if outcome == "clear" else "敗北"
	_check(city.saved_city() == expected, label + "の確定した月と状態を保存")
	await _click(Vector2(220, 540))
	_check(city.phase == "result" and city.state == expected, label + "保存の再開は結果へ戻り巻き戻らない")
	await _pad(JOY_BUTTON_A)
	_check(city.phase == "title", label + "結果を再開した後もパッド A でタイトルへ戻る")
	# 失敗しても以降の独立したケースを検証できるよう、結果ボタンをマウスで押す。
	if city.phase == "result":
		await _click(Vector2(600, 560))
