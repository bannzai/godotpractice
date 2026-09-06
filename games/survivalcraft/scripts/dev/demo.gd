extends SceneTree
## 28秒の通常操作。木の前への初期配置以外は実入力イベントだけで進める。

const Inputs := preload("res://scripts/dev/integration.gd")
var main: Node
var failed: bool = false


func _initialize() -> void:
	_record.call_deferred()


func _record() -> void:
	root.size = Vector2i(1280, 720)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for frame: int in range(840):
		_event_at(frame)
		await process_frame
	if int(main.model.inventory.get("wood", 0)) != 0:
		print("復活前の採集素材は喪失する仕様")
	print("demo OK" if not failed else "demo FAIL")
	quit(1 if failed else 0)


func _event_at(frame: int) -> void:
	match frame:
		40: Inputs.key(KEY_ENTER, true)
		42: Inputs.key(KEY_ENTER, false)
		65: Inputs.prepare_tree(main)
		80: Inputs.mouse(MOUSE_BUTTON_LEFT, true)
		130: Inputs.mouse(MOUSE_BUTTON_LEFT, false)
		140:
			_expect(int(main.model.inventory.get("wood", 0)) > 0, "採集で木材を得る")
		150: Inputs.key(KEY_E, true)
		152: Inputs.key(KEY_E, false)
		175: _click("木の板", true)
		177: _click("木の板", false)
		200: _expect(int(main.model.inventory.get("plank", 0)) == 4, "板をクラフト")
		220: Inputs.key(KEY_E, true)
		222: Inputs.key(KEY_E, false)
		240: Inputs.key(KEY_D, true)
		265: Inputs.key(KEY_D, false)
		275: Inputs.key(KEY_SPACE, true)
		278: Inputs.key(KEY_SPACE, false)
		320: Inputs.axis(JOY_AXIS_RIGHT_X, 0.55)
		350: Inputs.axis(JOY_AXIS_RIGHT_X, 0)
		365: Inputs.axis(JOY_AXIS_LEFT_Y, -0.65)
		390: Inputs.axis(JOY_AXIS_LEFT_Y, 0)
		415: Inputs.key(KEY_ESCAPE, true)
		417: Inputs.key(KEY_ESCAPE, false)
		470: Inputs.key(KEY_ESCAPE, true)
		472: Inputs.key(KEY_ESCAPE, false)
		500: Inputs.motion(Vector2(150, -20))
		525: Inputs.key(KEY_D, true)
		545: Inputs.key(KEY_D, false)
		600: Inputs.pad(JOY_BUTTON_START, true)
		602: Inputs.pad(JOY_BUTTON_START, false)
		635: _click("遠征を終える", true)
		637: _click("遠征を終える", false)
		665: _expect(main.model.phase == "failed", "失敗結果を表示")
		700: Inputs.pad(JOY_BUTTON_A, true)
		702: Inputs.pad(JOY_BUTTON_A, false)
		730: _expect(main.model.phase == "play", "島へ復活")
		752: Inputs.key(KEY_ESCAPE, true)
		754: Inputs.key(KEY_ESCAPE, false)
		780: _click("タイトルへ", true)
		782: _click("タイトルへ", false)
		805: _expect(main.model.phase == "title", "タイトルへ戻る")
		828: main.stop_audio()


func _click(text: String, pressed: bool) -> void:
	var button: Button = Inputs.find_button(main, text)
	_expect(button != null, "操作ボタン: " + text)
	if button != null:
		Inputs.mouse(MOUSE_BUTTON_LEFT, pressed, button.get_global_rect().get_center())


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error("demo FAIL: " + label)
