extends SceneTree
## 実際のキー・ゲームパッド・マウス入力を本番シーンへ送る。セーブは検証専用パスへ隔離する。

const SAVE_PATH: String = "res://tmp/integration-save.json"

var main: Control
var farm: Node
var failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


## 一回のプレイと保存・再開を入力で進めるため非冪等。
func _run() -> void:
	root.size = Vector2i(1280, 720)
	create_timer(40.0).timeout.connect(_timeout)
	farm = root.get_node("Farm")
	main = load("res://scenes/main.tscn").instantiate()
	main.save_path = SAVE_PATH
	root.add_child(main)
	await create_timer(0.1).timeout
	_check_bindings()
	await _keyboard_farming()
	await _menus_and_save()
	await _gamepad()
	await _outcomes()
	main.stop_audio()
	await create_timer(0.2).timeout
	main.queue_free()
	await process_frame
	if FileAccess.file_exists(SAVE_PATH):
		_check(DirAccess.remove_absolute(SAVE_PATH) == OK, "検証専用セーブを片付けられる")
	if not failed:
		print("integration OK")
	quit(1 if failed else 0)


func _check_bindings() -> void:
	for action: String in ["move_left", "move_right", "move_up", "move_down", "tool_next",
			"tool_previous", "crop_next", "use_tool", "interact", "menu", "ui_accept"]:
		var has_key: bool = false
		var has_pad: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			has_key = has_key or event is InputEventKey
			has_pad = has_pad or event is InputEventJoypadButton or event is InputEventJoypadMotion
		_check(has_key and has_pad, action + " にキーボードとパッドの割当がある")


## キーボードの道具切替と使用を実際に一度ずつ行うため非冪等。
func _keyboard_farming() -> void:
	await _tap_key(KEY_ENTER)
	_check(main.mode == "playing" and is_instance_valid(main.modal),
		"Enterでタイトルから母の手紙を開ける")
	await _tap_key(KEY_ENTER)
	_check(main.tutorial_active and main.tutorial_step == 1 and not is_instance_valid(main.modal),
		"母の手紙から段階チュートリアルを始められる")
	await _tap_key(KEY_SPACE)
	_check(farm.tiles[0].tilled and main.tutorial_step == 2 and farm.selected_tool == 2,
		"Spaceで畑を耕すと種へ自動で案内される")
	await create_timer(0.45).timeout
	await _tap_key(KEY_SPACE)
	_check(farm.tiles[0].crop == "turnip" and main.tutorial_step == 3 and farm.selected_tool == 1,
		"同じマスへ種を植えると水やりへ自動で案内される")
	await create_timer(0.45).timeout
	await _tap_key(KEY_SPACE)
	_check(farm.tiles[0].watered and not main.tutorial_active,
		"水やりまで終えると段階チュートリアルが完了する")
	await create_timer(0.45).timeout
	await _tap_key(KEY_R)
	_check(farm.selected_crop == "carrot", "Rで種の種類を切り替えられる")
	var before: Vector2 = farm.player_position
	_key(KEY_D, true)
	await create_timer(0.15).timeout
	_key(KEY_D, false)
	await process_frame
	_check(farm.player_position.x > before.x + 10, "Dで実際に移動できる")
	await _click(main.tool_buttons[3].get_global_rect().get_center())
	_check(farm.selected_tool == 3, "マウスで収穫道具を選べる")


## モーダル内の入力とセーブ・再開を実際に行うため非冪等。
func _menus_and_save() -> void:
	await _tap_key(KEY_TAB)
	_check(is_instance_valid(main.modal), "Tabで手帳を開ける")
	var before: Vector2 = farm.player_position
	var minute: float = farm.minutes
	_key(KEY_D, true)
	await create_timer(0.15).timeout
	_key(KEY_D, false)
	_check(farm.player_position == before and farm.minutes == minute, "手帳の背後で移動と時計が進まない")
	await _tap_key(KEY_LEFT)
	await _tap_key(KEY_ENTER)
	_check(is_instance_valid(main.modal), "手帳の持ちものを決定入力で開ける")
	farm.stamina = 20
	var food: int = farm.food
	await _tap_key(KEY_ENTER)
	_check(farm.food == food - 1 and farm.stamina == 50, "持ちものから弁当を食べられる")
	farm.player_position = main.world.TOWN
	main.world.refresh()
	await _tap_key(KEY_F)
	_check(main.mode == "map" and not is_instance_valid(main.modal),
		"町でFを押すと版画の村地図へ移動する")
	await _tap_key(KEY_ENTER)
	_check(is_instance_valid(main.modal), "村地図から決定入力で種屋を開ける")
	var money: int = farm.money
	var seeds: int = farm.seeds.turnip
	await _tap_key(KEY_ENTER)
	_check(farm.money == money - farm.CROPS.turnip.seed_price and farm.seeds.turnip == seeds + 1,
		"ショップの購入ボタンが所持金と種に反映される")
	await _tap_key(KEY_ESCAPE)
	await _tap_key(KEY_ESCAPE)
	_check(main.mode == "playing", "村地図をBまたはEscで閉じて農場へ戻れる")
	await _tap_key(KEY_TAB)
	await _click(Vector2(872, 236))
	_check(FileAccess.file_exists(SAVE_PATH), "手帳のボタンから検証専用パスに保存できる")
	var saved: Dictionary = farm.to_dict()
	main.return_title()
	await process_frame
	await _click(Vector2(204, 555))
	_check(main.mode == "playing", "タイトルのつづきからボタンで再開できる")
	_check(farm.day == saved.day and farm.money == saved.money and farm.tiles == saved.tiles,
		"再開後に日付・所持金・畑が保持される")


## 実ゲームパッドイベントを送り、キー入力だけでは検出できない配送の不具合を確認する。
func _gamepad() -> void:
	main.return_title()
	await process_frame
	await _tap_pad(JOY_BUTTON_A)
	_check(main.mode == "playing" and is_instance_valid(main.modal),
		"パッドAで新しい農場と母の手紙を開ける")
	await _tap_pad(JOY_BUTTON_A)
	_check(main.tutorial_step == 1 and not is_instance_valid(main.modal),
		"パッドAで段階チュートリアルを開始できる")
	await _tap_pad(JOY_BUTTON_RIGHT_SHOULDER)
	_check(farm.selected_tool == 1, "RBで次の道具を選べる")
	await _tap_pad(JOY_BUTTON_LEFT_SHOULDER)
	_check(farm.selected_tool == 0, "LBで前の道具を選べる")
	await _tap_pad(JOY_BUTTON_X)
	_check(farm.tiles[0].tilled, "パッドXで耕せる")
	await create_timer(0.45).timeout
	await _tap_pad(JOY_BUTTON_Y)
	_check(farm.selected_crop == "carrot", "パッドYで種を切り替えられる")
	var before: Vector2 = farm.player_position
	_axis(JOY_AXIS_LEFT_X, 0.8)
	_axis(JOY_AXIS_LEFT_Y, 0.8)
	await create_timer(0.2).timeout
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	await process_frame
	var movement: Vector2 = farm.player_position - before
	_check(movement.x > 8 and movement.y > 8 and movement.length() < 48,
		"左スティックで斜めに歩き、斜め移動が速くならない")
	await _tap_pad(JOY_BUTTON_START)
	_check(is_instance_valid(main.modal), "Startで手帳を開ける")
	await _tap_pad(JOY_BUTTON_B)
	_check(not is_instance_valid(main.modal), "Bで手帳を閉じられる")


## 翌朝の精算から結果・再挑戦への実入力を検証するため非冪等。
func _outcomes() -> void:
	main.close_modal()
	farm.money = 840
	farm.shipping.turnip = 1
	farm.player_position = main.world.BED
	main.world.refresh()
	await _tap_pad(JOY_BUTTON_A)
	_check(is_instance_valid(main.modal), "パッドAで寝床の確認を開ける")
	await _tap_pad(JOY_BUTTON_A)
	await create_timer(0.8).timeout
	_check(main.mode == "result" and farm.phase == "win" and farm.money == 900,
		"就寝と出荷精算で目標達成画面へ進む")
	await _tap_pad(JOY_BUTTON_A)
	_check(main.mode == "title", "結果画面からパッドAでタイトルへ戻れる")
	await _tap_key(KEY_ENTER)
	_check(main.mode == "playing" and farm.day == 1 and farm.money == 120
		and is_instance_valid(main.modal), "再挑戦では初日の農場と母の手紙に戻る")
	await _tap_key(KEY_ESCAPE)
	farm.day = 20
	farm.player_position = main.world.BED
	main.world.refresh()
	await _tap_key(KEY_F)
	await _tap_key(KEY_ENTER)
	await create_timer(0.8).timeout
	_check(main.mode == "result" and farm.phase == "loss", "20日目の就寝で未達成の結果画面へ進む")


## キーの押下と解放は一度の実入力なので非冪等。
func _tap_key(code: Key) -> void:
	_key(code, true)
	await process_frame
	_key(code, false)
	await create_timer(0.08).timeout


## キーイベントを実入力として配送するため非冪等。
func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


## パッドの押下と解放は一度の実入力なので非冪等。
func _tap_pad(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
	await create_timer(0.08).timeout


## スティック位置は操作中に変化するため非冪等。
func _axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()


## 実際のGUIへポインター移動とクリックを送るため非冪等。
func _click(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
	await create_timer(0.1).timeout


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("integration: " + message)


func _timeout() -> void:
	push_error("integration: 制限時間内に終了できなかった")
	main.stop_audio()
	quit(1)
