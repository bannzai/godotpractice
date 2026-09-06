extends SceneTree
## 26秒の録画用モンタージュ。部屋・装備・敵HPは短縮用の前提を置く。
## 操作は本番入力を使う。通常進行の完走は playthrough.gd が検査する。

const TOTAL_FRAMES: int = 780
var main: Node
var state: Node
var world: Node
var failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	state = main.state
	world = main.world
	print("デモ: 26秒・実入力。部屋/装備/ボスHPは録画前提、通常完走は別検証。")
	for frame: int in range(TOTAL_FRAMES):
		_event(frame)
		await process_frame
		if frame >= TOTAL_FRAMES - 12:
			main.stop_audio()
	main.queue_free()
	await process_frame
	await process_frame
	if not failed:
		print("demo OK")
	quit(1 if failed else 0)


# フレームごとの入力を一回ずつ発火するため非冪等。
func _event(frame: int) -> void:
	match frame:
		40: _key(KEY_ENTER, true)
		42: _key(KEY_ENTER, false)
		65:
			_check(state.mode == "play", "開始入力")
			_key(KEY_D, true)
		95:
			_key(KEY_D, false)
			_key(KEY_W, true)
		112:
			_key(KEY_W, false)
			_key(KEY_E, true)
		114: _key(KEY_E, false)
		145: _key(KEY_ESCAPE, true)
		147: _key(KEY_ESCAPE, false)
		165:
			state.mode = "play"
			world.enter_room(2, Vector2(740, 390), false)
			world.facing = Vector2.RIGHT
		180, 202: _key(KEY_J, true)
		182, 204: _key(KEY_J, false)
		215: _key(KEY_D, true)
		240:
			_key(KEY_D, false)
			state.open_chest("demo-wind", "boomerang")
			state.open_chest("demo-powder", "bombs")
			state.tool = "boomerang"
			world.enter_room(7, Vector2(580, 384), false)
			world.facing = Vector2.RIGHT
		265: _key(KEY_K, true)
		267: _key(KEY_K, false)
		300:
			_check(state.has_flag("wind-bridge"), "風の輪で橋を開く")
			_key(KEY_D, true)
		340: _key(KEY_D, false)
		350: _key(KEY_TAB, true)
		352: _key(KEY_TAB, false)
		375: _mouse(Vector2(650, 370), true)
		377: _mouse(Vector2(650, 370), false)
		395:
			_check(state.mode == "play" and state.tool == "bomb", "持ち物で爆弾を装備")
			world.enter_room(8, Vector2(885, 384), false)
			world.facing = Vector2.RIGHT
		415: _key(KEY_K, true)
		417: _key(KEY_K, false)
		460:
			_check(state.has_flag("broken-wall"), "爆弾で壁を開く")
			world.enter_room(9, Vector2(430, 384), false)
		480: _key(KEY_D, true)
		510:
			_key(KEY_D, false)
			_check(state.has_flag("weight"), "押せる石で床の灯を起動")
		535:
			world.enter_room(11, Vector2(800, 384), false)
			world.enemies[0].hp = 2
			world.facing = Vector2.RIGHT
		550, 570: _key(KEY_J, true)
		552, 572: _key(KEY_J, false)
		600:
			_check(state.has_flag("boss"), "剣でボスを撃破")
			_key(KEY_D, true)
		612:
			_key(KEY_D, false)
			_key(KEY_E, true)
		614: _key(KEY_E, false)
		630: _check(state.mode == "ending", "宝を取得して結末")
		700: _mouse(Vector2(620, 560), true)
		702: _mouse(Vector2(620, 560), false)
		725: _check(state.mode == "title", "タイトルへ戻る")


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _mouse(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)


func _check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error("demo FAIL: " + label)
