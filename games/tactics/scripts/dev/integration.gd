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
	_check(campaign.screen == "story", "Enterでタイトルから物語へ")
	_check(main.tutorial_active, "新しい絵巻では初陣の指南が有効")
	await key(KEY_ENTER)
	_check(campaign.screen == "play", "Enterで物語から戦場へ")
	_check(_has_text(main.sidebar, "一ノ指南"), "戦場に初回指南を表示")
	await key(KEY_RIGHT)
	await key(KEY_ENTER)
	_check(main.selected.is_empty(), "空の升は選択されない")
	_check("誰もいません" in main.notice, "空の升を選べない理由を表示")
	await key(KEY_LEFT)
	await key(KEY_ENTER)
	_check(main.selected == "hero", "Enterで主人公を選択")
	_check(main.tutorial_step == 1, "指南が移動の段階へ進む")
	await key(KEY_RIGHT)
	_check(main.cursor == Vector2i(3, 5), "右キーでカーソル移動")
	await key(KEY_ENTER)
	await idle()
	_check(campaign.unit_by_id("hero").x == 3, "実入力で青いマスへ移動")
	_check(main.tutorial_step == 2, "指南が見立ての段階へ進む")
	await key(KEY_I)
	_check(main.selected == "hero", "満HPで薬を使っても移動取消の選択を保つ")
	_check("HPが満タン" in main.notice, "薬を使えない理由を表示")
	await button(JOY_BUTTON_B)
	_check(campaign.unit_by_id("hero").x == 2, "Bで移動を取り消す")
	await button(JOY_BUTTON_A)
	_check(main.selected == "hero", "パッドAで選択")
	await axis(JOY_AXIS_LEFT_X, 1.0)
	_check(main.cursor.x == 3, "左スティックでカーソル移動")
	await key(KEY_ESCAPE)
	await click(Vector2(176, 359))
	_check(main.selected == "hero", "マウスクリックで主人公を選択")
	_check(_has_button(main.sidebar, "攻撃"), "選択後に扇の攻撃を表示")
	_check(_has_button(main.sidebar, "待機"), "選択後に扇の待機を表示")
	_check(_has_button(main.sidebar, "薬"), "選択後に扇の薬を表示")
	_check(_has_button(main.sidebar, "取消"), "選択後に扇の取消を表示")
	await click_cell(Vector2i(5, 5))
	_check(main.target.is_empty(), "射程外の敵は攻撃対象にならない")
	_check("射程外" in main.notice, "敵を選べない理由を表示")
	await click_cell(Vector2i(4, 5))
	await idle()
	await click_cell(Vector2i(5, 5))
	_check(main.target == "e1", "移動後の敵を攻撃対象に選択")
	_check(_has_text(main.sidebar, "戦の見立て"), "攻撃前に巻物の見立てを表示")
	_check(_has_button(main.sidebar, "この見立てで進む"), "巻物に確定操作を表示")
	_check(_has_button(main.sidebar, "巻物を戻す"), "巻物に取消操作を表示")
	await key(KEY_ESCAPE)
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
	_check(campaign.screen == "story", "パッドAで新規プレイの物語へ")
	await button(JOY_BUTTON_A)
	_check(campaign.screen == "play", "パッドAで物語から戦場へ")
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


func click_cell(cell: Vector2i) -> void:
	await click(Vector2(66, 117) + Vector2(cell) * 44 + Vector2(22, 22))


func _has_button(node: Node, caption: String) -> bool:
	for child: Node in node.find_children("*", "Button", true, false):
		if child.text == caption:
			return true
	return false


func _has_text(node: Node, fragment: String) -> bool:
	for child: Node in node.find_children("*", "Label", true, false):
		if fragment in child.text:
			return true
	return false


func _check(value: bool, description: String) -> void:
	if not value:
		failed = true
		push_error(description)
