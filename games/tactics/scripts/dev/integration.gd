extends SceneTree
## 本番シーンへ実入力を送り、タイトル・操作・自然敗北・再開を検証する。
## 時間経過と入力は一度のプレイを再現するため非冪等。

var main: Control
var campaign: Node
var failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	Engine.time_scale = 15.0
	campaign = root.get_node("Campaign")
	campaign.save_path = "user://tactics-integration-test.json"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await key(KEY_ENTER)
	_check(campaign.screen == "play", "Enterでタイトルから戦場へ")
	await key(KEY_ENTER)
	_check(main.selected == "hero", "Enterで主人公を選択")
	await key(KEY_RIGHT)
	_check(main.cursor == Vector2i(3, 5), "右キーでカーソル移動")
	await key(KEY_ENTER)
	await idle()
	_check(campaign.unit_by_id("hero").x == 3, "実入力で青いマスへ移動")
	await key(KEY_I)
	_check(main.selected == "hero", "満HPで薬を使っても移動取消の選択を保つ")
	await button(JOY_BUTTON_B)
	_check(campaign.unit_by_id("hero").x == 2, "Bで移動を取り消す")
	await button(JOY_BUTTON_A)
	_check(main.selected == "hero", "パッドAで選択")
	await axis(JOY_AXIS_LEFT_X, 1.0)
	_check(main.cursor.x == 3, "左スティックでカーソル移動")
	await key(KEY_ESCAPE)
	await click(Vector2(176, 359))
	_check(main.selected == "hero", "マウスクリックで主人公を選択")
	await key(KEY_ESCAPE)
	await button(JOY_BUTTON_START)
	_check(campaign.screen == "title", "Startで保存しタイトルへ")
	await click(Vector2(184, 498))
	_check(campaign.screen == "play", "マウスクリックで記録から再開")
	for turn: int in range(30):
		if campaign.screen == "result":
			break
		await key(KEY_E)
		await idle()
	_check(campaign.outcome == "defeat" and campaign.screen == "result", "通常の敵攻撃で主人公が倒れ敗北")
	await click(Vector2(600, 500))
	_check(campaign.screen == "title", "結果からマウスでタイトル復帰")
	await button(JOY_BUTTON_A)
	_check(campaign.screen == "play", "パッドAで新規プレイ")
	for unit: Dictionary in campaign.units:
		if unit.team == "player":
			unit.hp = 0
	campaign.outcome = "defeat"
	_check(campaign.save_game(), "全味方死亡の敗北を検証専用user://へ保存")
	main.show_title()
	await click(Vector2(184, 498))
	_check(campaign.screen == "result", "全味方死亡の保存から例外なく敗北結果へ再開")
	main.stop_audio()
	await create_timer(0.2, true, false, true).timeout
	Engine.time_scale = 1.0
	if not failed:
		print("integration OK")
	quit(1 if failed else 0)


func idle() -> void:
	for frame: int in range(1800):
		await process_frame
		if not main.busy:
			return
	_check(false, "演出が規定時間内に完了")


func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func button(code: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func axis(code: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = code
	event.axis_value = value
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.axis_value = 0
	Input.parse_input_event(event)
	await process_frame


func click(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	Input.parse_input_event(motion)
	await process_frame
	var event := InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _check(value: bool, description: String) -> void:
	if not value:
		failed = true
		push_error(description)
